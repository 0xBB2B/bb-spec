#!/usr/bin/env bash
# 结构性校验：多 plugin 结构 + marketplace 一致性 + agent / skill / hook 格式完整性 + 安全基线 + 路径泄露检测
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGINS_DIR="$ROOT/plugins"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# ─── 辅助：提取 frontmatter 字段值（首次匹配）───
fm_value() {
  local file="$1" key="$2"
  sed -n '/^---$/,/^---$/p' "$file" | grep -m1 "^${key}:" | sed "s/^${key}:[[:space:]]*//"
}

# 检查 frontmatter 是否包含指定 key
fm_has() {
  local file="$1" key="$2"
  sed -n '/^---$/,/^---$/p' "$file" | grep -q "^${key}:"
}

# ─────────────────────────────────────────────
echo "=== Marketplace 校验 ==="
mp="$ROOT/.claude-plugin/marketplace.json"

echo "[marketplace.json]"
if python3 -c "import json; json.load(open('$mp'))" 2>/dev/null; then
  pass
else
  fail "marketplace.json 不是有效 JSON"
fi

# 每个 plugin 条目的 source 目录存在且含 plugin.json，且 name 与目录一致
echo "[plugin 条目一致性]"
entries=$(python3 -c "
import json
data = json.load(open('$mp'))
for p in data.get('plugins', []):
    print(p.get('name', '') + '\t' + p.get('source', ''))
" 2>/dev/null)

while IFS=$'\t' read -r mp_name src; do
  [[ -z "$src" ]] && continue
  pdir="$ROOT/${src#./}"
  if [[ -d "$pdir" && -f "$pdir/.claude-plugin/plugin.json" ]]; then
    pass
  else
    fail "marketplace source 无效（目录或 plugin.json 缺失）: $src"
    continue
  fi
  # marketplace 条目 name 应与子目录名一致
  if [[ "$mp_name" == "$(basename "$pdir")" ]]; then
    pass
  else
    fail "marketplace 条目 name='$mp_name' 与目录 '$(basename "$pdir")' 不一致"
  fi
done <<< "$entries"

# ─────────────────────────────────────────────
# 逐 plugin 校验
for pdir in "$PLUGINS_DIR"/*/; do
  pname="$(basename "$pdir")"
  echo ""
  echo "=== Plugin: $pname ==="

  # ── plugin.json ──
  pj="${pdir}.claude-plugin/plugin.json"
  echo "[plugin.json]"
  if python3 -c "import json; json.load(open('$pj'))" 2>/dev/null; then
    pass
  else
    fail "plugin.json 不是有效 JSON"
    continue
  fi
  for key in name version description license; do
    if python3 -c "import json,sys; d=json.load(open('$pj')); sys.exit(0 if '$key' in d else 1)" 2>/dev/null; then
      pass
    else
      fail "plugin.json 缺少字段: $key"
    fi
  done
  pj_name="$(python3 -c "import json; print(json.load(open('$pj')).get('name',''))" 2>/dev/null)"
  if [[ "$pj_name" == "$pname" ]]; then
    pass
  else
    fail "plugin.json name='$pj_name' 与目录 '$pname' 不一致"
  fi

  # ── skills ──
  if [[ -d "${pdir}skills" ]]; then
    for d in "${pdir}"skills/*/; do
      [[ -d "$d" ]] || continue
      skill_name="$(basename "$d")"
      echo "[skill: $skill_name]"
      skill_file="${d}SKILL.md"

      if [[ ! -f "$skill_file" ]]; then
        fail "缺少 SKILL.md"
        continue
      fi
      if ! head -1 "$skill_file" | grep -q '^---$'; then
        fail "SKILL.md 缺少 frontmatter"
        continue
      fi
      for key in name description; do
        if fm_has "$skill_file" "$key"; then pass; else fail "缺少必填字段: $key"; fi
      done
      fm_name="$(fm_value "$skill_file" "name")"
      if [[ "$fm_name" == "$skill_name" ]]; then
        pass
      else
        fail "name='$fm_name' 与目录名 '$skill_name' 不一致"
      fi
    done
  fi

  # ── agents ──
  if [[ -d "${pdir}agents" ]]; then
    for f in "${pdir}"agents/*.md; do
      [[ -f "$f" ]] || continue
      aname="$(basename "$f" .md)"
      echo "[agent: $aname]"

      if ! head -1 "$f" | grep -q '^---$'; then
        fail "缺少 frontmatter"
        continue
      fi
      for key in name description agent-type inputs; do
        if fm_has "$f" "$key"; then pass; else fail "缺少必填字段: $key"; fi
      done
      fm_name="$(fm_value "$f" "name")"
      if [[ "$fm_name" == "$aname" ]]; then pass; else fail "name='$fm_name' 与文件名 '$aname' 不一致"; fi
      agent_type="$(fm_value "$f" "agent-type")"
      case "$agent_type" in
        general-purpose|codex:codex-rescue) pass ;;
        *) fail "agent-type='$agent_type' 不在允许列表" ;;
      esac
      if grep -q '^## 安全基线' "$f"; then pass; else fail "缺少 '## 安全基线' 段落"; fi
    done
  fi

  # ── hooks ──
  if [[ -f "${pdir}hooks/hooks.json" ]]; then
    hj="${pdir}hooks/hooks.json"
    echo "[hooks.json]"
    if python3 -c "import json; json.load(open('$hj'))" 2>/dev/null; then
      pass
    else
      fail "hooks.json 不是有效 JSON"
    fi
    scripts=$(python3 -c "
import json, re
data = json.load(open('$hj'))
for _, matchers in data.get('hooks', {}).items():
    for m in matchers:
        for h in m.get('hooks', []):
            print(re.sub(r'\\\$\{CLAUDE_PLUGIN_ROOT\}', '.', h.get('command', '')))
" 2>/dev/null)
    while IFS= read -r script; do
      [[ -z "$script" ]] && continue
      resolved="${pdir}${script#./}"
      if [[ -f "$resolved" ]]; then
        pass
      else
        fail "hook 脚本不存在: $script"
      fi
    done <<< "$scripts"
  fi
done

# ─────────────────────────────────────────────
echo ""
echo "=== 路径泄露检测 ==="
echo "[个人路径]"
leaked=$(grep -rn '/Users/\|/home/' "$PLUGINS_DIR" \
  --include='*.md' --include='*.sh' --include='*.json' \
  2>/dev/null || true)

if [[ -z "$leaked" ]]; then
  pass
  echo "  无个人路径泄露"
else
  fail "发现个人路径泄露:"
  echo "$leaked" | head -10
fi

echo ""
echo "==============================="
echo "通过: $PASS  |  失败: $FAIL"
echo "==============================="

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
