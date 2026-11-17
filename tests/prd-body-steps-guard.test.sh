#!/usr/bin/env bash
# 守护 skill-size 测试：prd 步骤 0 到 5 搬出正文时必须被拦住，references 文件数不受限
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

H2='### 步骤 2：质疑（对用户可见）'
H3='### 步骤 3：澄清与发散'
H4='### 步骤 4：收敛与拆解'
K1='用一句话复述**要解决的问题**'

new_copy() {
  local dst="$TMP/$1" s
  mkdir -p "$dst/tests" "$dst/plugins/bb-spec-workflow/skills"
  cp "$ROOT/tests/skill-size.test.sh" "$dst/tests/"
  for s in git-push prd revise; do
    cp -R "$ROOT/plugins/bb-spec-workflow/skills/$s" "$dst/plugins/bb-spec-workflow/skills/"
  done
  echo "$dst"
}

run_size() {
  local dst="$1" rc=0
  bash "$dst/tests/skill-size.test.sh" >"$dst/out.txt" 2>&1 || rc=$?
  return "$rc"
}

echo "[场景 1：不改动]"
d="$(new_copy s1)"
if run_size "$d"; then pass; else fail "不改动应退出 0"; fi
if grep -qF '文件数不超过' "$d/out.txt"; then fail "输出不应含 文件数不超过"; else pass; fi

echo "[场景 2：references 多一个文件]"
d="$(new_copy s2)"
prd="$d/plugins/bb-spec-workflow/skills/prd"
{ echo '> 用在 /prd 步骤 7：测试用'; python3 -c 'print("填充" * 400)'; } >"$prd/references/extra.md"
python3 - "$prd/SKILL.md" <<'PY'
import sys
p = sys.argv[1]
lines = open(p, encoding="utf-8").read().split("\n")
i = next(k for k, l in enumerate(lines) if l.startswith("### 步骤 8"))
lines[i:i] = ["走到这一步先读 `references/extra.md`（相对本 skill 目录）。", ""]
open(p, "w", encoding="utf-8").write("\n".join(lines))
PY
if run_size "$d"; then pass; else fail "多一个 references 文件应退出 0"; fi

echo "[场景 3：步骤 2 正文换成先读提示]"
d="$(new_copy s3)"
python3 - "$d/plugins/bb-spec-workflow/skills/prd/SKILL.md" "$H2" "$H3" <<'PY'
import sys
p, h2, h3 = sys.argv[1:4]
lines = open(p, encoding="utf-8").read().split("\n")
a = next(k for k, l in enumerate(lines) if l.startswith(h2))
b = next(k for k, l in enumerate(lines) if l.startswith(h3))
lines[a + 1:b] = ["走到这一步先读 `references/repo-layout.md`（相对本 skill 目录）。", ""]
open(p, "w", encoding="utf-8").write("\n".join(lines))
PY
if run_size "$d"; then fail "步骤 2 被搬空应退出非 0"; else pass; fi
if grep -qF "「${H2}」一节缺少：有没有更便宜的替代" "$d/out.txt"; then pass; else fail "输出应含 步骤 2 缺少：有没有更便宜的替代"; fi
if grep -qF "「${H2}」一节不应出现：走到这一步先读" "$d/out.txt"; then pass; else fail "输出应含 步骤 2 不应出现：走到这一步先读"; fi

echo "[场景 4：步骤 1 的关键句挪到步骤 3]"
d="$(new_copy s4)"
python3 - "$d/plugins/bb-spec-workflow/skills/prd/SKILL.md" "$K1" "$H4" <<'PY'
import sys
p, key, h4 = sys.argv[1:4]
lines = open(p, encoding="utf-8").read().split("\n")
k = next(i for i, l in enumerate(lines) if key in l)
moved = lines.pop(k)
b = next(i for i, l in enumerate(lines) if l.startswith(h4))
lines.insert(b, moved)
open(p, "w", encoding="utf-8").write("\n".join(lines))
PY
if run_size "$d"; then fail "步骤 1 缺关键句应退出非 0"; else pass; fi
if grep -qF "「### 步骤 1：意图定性」一节缺少：${K1}" "$d/out.txt"; then pass; else fail "输出应含 步骤 1 缺少：${K1}"; fi

echo "[场景 5：步骤 4 标题被改]"
d="$(new_copy s5)"
python3 - "$d/plugins/bb-spec-workflow/skills/prd/SKILL.md" "$H4" <<'PY'
import sys
p, h4 = sys.argv[1:3]
s = open(p, encoding="utf-8").read()
assert h4 in s
open(p, "w", encoding="utf-8").write(s.replace(h4, "### 步骤 4：收敛", 1))
PY
if run_size "$d"; then fail "步骤 4 标题改名应退出非 0"; else pass; fi
if grep -qF "找不到标题：${H4}" "$d/out.txt"; then pass; else fail "输出应含 找不到标题：${H4}"; fi

echo "[场景 6：步骤 1 标题行被删]"
d="$(new_copy s6)"
python3 - "$d/plugins/bb-spec-workflow/skills/prd/SKILL.md" <<'PY2'
import sys
p = sys.argv[1]
lines = open(p, encoding="utf-8").read().split("\n")
lines = [l for l in lines if not l.startswith("### 步骤 1：意图定性")]
open(p, "w", encoding="utf-8").write("\n".join(lines))
PY2
if run_size "$d"; then fail "步骤 1 标题被删应退出非 0"; else pass; fi
if grep -qF '找不到标题：### 步骤 1：意图定性' "$d/out.txt"; then pass; else fail "输出应含 找不到标题：### 步骤 1：意图定性"; fi

echo "[场景 7：步骤 2 小节里先有代码块（含 # 注释行），之后出现先读提示]"
d="$(new_copy s7)"
python3 - "$d/plugins/bb-spec-workflow/skills/prd/SKILL.md" "$H3" <<'PY3'
import sys
p, h3 = sys.argv[1:3]
lines = open(p, encoding="utf-8").read().split("\n")
b = next(k for k, l in enumerate(lines) if l.startswith(h3))
lines[b:b] = ["```bash", "# 注释", "```", "走到这一步先读 `references/repo-layout.md`（相对本 skill 目录）。", ""]
open(p, "w", encoding="utf-8").write("\n".join(lines))
PY3
if run_size "$d"; then fail "代码块之后的先读提示应让 skill-size 退出非 0"; else pass; fi
if grep -qF "「${H2}」一节不应出现：走到这一步先读" "$d/out.txt"; then pass; else fail "输出应含 步骤 2 不应出现：走到这一步先读（代码块里的 # 注释不能截断小节）"; fi

echo "[场景 8：步骤 2 小节里先有嵌套代码块（外层四个反引号，内层有 # 注释行），之后出现先读提示]"
d="$(new_copy s8)"
python3 - "$d/plugins/bb-spec-workflow/skills/prd/SKILL.md" "$H3" <<'PY4'
import sys
p, h3 = sys.argv[1:3]
lines = open(p, encoding="utf-8").read().split("\n")
b = next(k for k, l in enumerate(lines) if l.startswith(h3))
lines[b:b] = ["````markdown", "```bash", "# 注释", "```", "````", "走到这一步先读 `references/repo-layout.md`（相对本 skill 目录）。", ""]
open(p, "w", encoding="utf-8").write("\n".join(lines))
PY4
if run_size "$d"; then fail "嵌套代码块之后的先读提示应让 skill-size 退出非 0"; else pass; fi
if grep -qF "「${H2}」一节不应出现：走到这一步先读" "$d/out.txt"; then pass; else fail "输出应含 步骤 2 不应出现：走到这一步先读（嵌套代码块里的 # 注释不能截断小节）"; fi

echo ""
echo "通过 ${PASS}，失败 ${FAIL}"
[[ "$FAIL" -eq 0 ]]
