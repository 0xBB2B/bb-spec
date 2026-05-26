#!/usr/bin/env bash
# 结构性校验：agent / skill / hook 格式完整性 + 安全基线 + 路径泄露检测
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# ─── 辅助：提取 frontmatter 字段值 ───
# 用法：fm_value "file" "key"  → 输出该 key 的值（首次匹配）
fm_value() {
  local file="$1" key="$2"
  sed -n '/^---$/,/^---$/p' "$file" | grep -m1 "^${key}:" | sed "s/^${key}:[[:space:]]*//"
}

# 检查 frontmatter 是否包含指定 key
fm_has() {
  local file="$1" key="$2"
  sed -n '/^---$/,/^---$/p' "$file" | grep -q "^${key}:"
}

echo "=== Agent 校验 ==="

for f in "$ROOT"/agents/*.md; do
  name_from_file="$(basename "$f" .md)"
  echo "[$name_from_file]"

  # 1) frontmatter 存在
  if ! head -1 "$f" | grep -q '^---$'; then
    fail "缺少 frontmatter"
    continue
  fi

  # 2) 必填字段
  for key in name description agent-type inputs; do
    if fm_has "$f" "$key"; then
      pass
    else
      fail "缺少必填字段: $key"
    fi
  done

  # 3) name 与文件名一致
  fm_name="$(fm_value "$f" "name")"
  if [[ "$fm_name" == "$name_from_file" ]]; then
    pass
  else
    fail "name='$fm_name' 与文件名 '$name_from_file' 不一致"
  fi

  # 4) agent-type 合法
  agent_type="$(fm_value "$f" "agent-type")"
  case "$agent_type" in
    general-purpose|codex:codex-rescue) pass ;;
    *) fail "agent-type='$agent_type' 不在允许列表" ;;
  esac

  # 5) 安全基线段落存在
  if grep -q '^## 安全基线' "$f"; then
    pass
  else
    fail "缺少 '## 安全基线' 段落"
  fi
done

echo ""
echo "=== Skill 校验 ==="

for d in "$ROOT"/skills/*/; do
  skill_name="$(basename "$d")"
  echo "[$skill_name]"

  skill_file="$d/SKILL.md"

  # 1) SKILL.md 存在
  if [[ ! -f "$skill_file" ]]; then
    fail "缺少 SKILL.md"
    continue
  fi

  # 2) frontmatter 存在
  if ! head -1 "$skill_file" | grep -q '^---$'; then
    fail "SKILL.md 缺少 frontmatter"
    continue
  fi

  # 3) 必填字段
  for key in name description; do
    if fm_has "$skill_file" "$key"; then
      pass
    else
      fail "缺少必填字段: $key"
    fi
  done

  # 4) name 与目录名一致
  fm_name="$(fm_value "$skill_file" "name")"
  if [[ "$fm_name" == "$skill_name" ]]; then
    pass
  else
    fail "name='$fm_name' 与目录名 '$skill_name' 不一致"
  fi
done

echo ""
echo "=== Hooks 校验 ==="

hooks_json="$ROOT/hooks/hooks.json"

# 1) hooks.json 有效 JSON
echo "[hooks.json]"
if python3 -c "import json; json.load(open('$hooks_json'))" 2>/dev/null; then
  pass
else
  fail "hooks.json 不是有效 JSON"
fi

# 2) 引用的 hook 脚本文件存在
echo "[hook 脚本存在性]"
scripts=$(python3 -c "
import json, re
data = json.load(open('$hooks_json'))
for hook_type, matchers in data.get('hooks', {}).items():
    for m in matchers:
        for h in m.get('hooks', []):
            cmd = h.get('command', '')
            # 替换变量为实际路径
            script = re.sub(r'\\\$\{CLAUDE_PLUGIN_ROOT\}', '.', cmd)
            print(script)
" 2>/dev/null)

while IFS= read -r script; do
  [[ -z "$script" ]] && continue
  resolved="$ROOT/${script#./}"
  if [[ -f "$resolved" ]]; then
    pass
  else
    fail "hook 脚本不存在: $script"
  fi
done <<< "$scripts"

echo ""
echo "=== Plugin 校验 ==="

plugin_json="$ROOT/.claude-plugin/plugin.json"
echo "[plugin.json]"

# 1) 有效 JSON
if python3 -c "import json; json.load(open('$plugin_json'))" 2>/dev/null; then
  pass
else
  fail "plugin.json 不是有效 JSON"
fi

# 2) 必填字段
for key in name version description license; do
  if python3 -c "import json; d=json.load(open('$plugin_json')); assert '$key' in d" 2>/dev/null; then
    pass
  else
    fail "plugin.json 缺少字段: $key"
  fi
done

echo ""
echo "=== 路径泄露检测 ==="

echo "[个人路径]"
# 检测 /Users/xxx 或 /home/xxx 等绝对个人路径（排除 tests/ 本身和 .git/）
leaked=$(grep -rn '/Users/\|/home/' \
  "$ROOT/agents/" "$ROOT/skills/" "$ROOT/hooks/" \
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
