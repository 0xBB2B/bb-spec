#!/usr/bin/env bash
# /prototype 派子代理的规则校验：prototype 规程只派工和传话，prd/revise 的文件名和临时文件说明，exec 不变
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WF="$ROOT/plugins/bb-spec-workflow"
PROTO="$WF/skills/prototype/SKILL.md"
PLUGIN="$WF/.claude-plugin/plugin.json"
REVISE="$WF/skills/revise/SKILL.md"
PRD="$WF/skills/prd/SKILL.md"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

in_file() {
  local label="$1" file="$2" text="$3"
  if grep -qF -- "$text" "$file" 2>/dev/null; then pass; else fail "${label} 缺少：${text}"; fi
}

not_in_file() {
  local label="$1" file="$2" text="$3"
  if grep -qF -- "$text" "$file" 2>/dev/null; then fail "${label} 不应含：${text}"; else pass; fi
}

in_text() {
  local label="$1" text="$2" body="$3"
  if printf '%s\n' "$body" | grep -qF -- "$text"; then pass; else fail "${label} 缺少：${text}"; fi
}

file_section() {
  awk -v start="$2" -v stop="$3" '
    found && $0 ~ stop { exit }
    index($0, start) == 1 { found = 1 }
    found { print }
  ' "$1" 2>/dev/null || true
}

has() { local t; for t in "$@"; do in_file prototype "$PROTO" "$t"; done; }
lacks() { local t; for t in "$@"; do not_in_file prototype "$PROTO" "$t"; done; }

echo "[派谁]"
has 'bb-spec-workflow:prototype-designer' '改动再小（只换一个按钮文字、一个颜色值）也派'

echo "[主对话边界]"
has '不读项目源码' '不读、不写、不改原型文件的内容' '不写 DESIGN.md'

echo "[出原型派工说明]"
has '必须写全 6 项' '缺一项就先补齐再派' '调用方是谁' '需求结论' '用户的原话照抄' \
  'DESIGN.md 应在的完整路径' '草稿的完整路径' '${CLAUDE_PLUGIN_ROOT}/templates' \
  '旁边有哪个临时文件就写哪个的路径'

echo "[对比派工说明]"
has '必须写全 3 项' '截图目录的完整路径' '${CACHE_DIR}/ui-compare/<日期>.<主题>/'

echo "[转报告]"
has '原样给用户看' '待用户确认的问题' 'open <原型文件路径>' '提醒用户刷新页面'

echo "[传话]"
has 'SendMessage' '同一个原型子代理' '不改写原话'

echo "[发不到原来的子代理]"
has '新派一个原型子代理' '原型文件已存在，接着改'

echo "[确认后]"
has '用户已确认' '确认内容清单' '告诉用户原型文件路径'

echo "[对比]"
has '每次新派一个原型子代理' '原样交给调用方'

echo "[派不出去]"
has '把报错原文告诉用户' '不自己接手出原型'

echo "[保留的写法]"
has '| `/prototype <主题>` |' '| `<主题> --file <路径>` |' '| `--compare <路径>` |' \
  'scripts/bbspec-paths.sh' '${CACHE_DIR}/ui-preview/<YYYY-MM-DD>.<主题>.html' '明确说"可以"' '不写 PRD'

echo "[做法只在子代理定义里]"
lacks 'PROTOTYPE-START' 'WCAG' '取证顺序' 'terminalCss'

echo "[plugin.json]"
in_file plugin.json "$PLUGIN" '6 个编排 subagent'

echo "[revise 的原型文件名]"
in_file revise "$REVISE" '--file ${CACHE_DIR}/ui-preview/<YYYY-MM-DD>.revise-<主题>.html'
not_in_file revise "$REVISE" 'revise-<YYYY-MM-DD>-<主题>'

echo "[prd 的设计规范临时文件]"
S7D="$(file_section "$PRD" '**7d. DESIGN.md**' '^### |^\*\*7[a-z]\.')"
for t in '<预览页名>.DESIGN.md' '写完删掉它' '<预览页名>.DESIGN.draft.md' '不写入'; do
  in_text prd7d "$t" "$S7D"
done
S6="$(file_section "$PRD" '### 步骤 6' '^### ')"
L7A="$(grep -F -- '**7a. PRD**' "$PRD" 2>/dev/null | head -n1 || true)"
for t in '.DESIGN.draft.md' '.DESIGN.md'; do
  in_text prd步骤6 "$t" "$S6"
  in_text prd7a "$t" "$L7A"
done
QUIT="$(file_section "$PRD" '### 步骤 9' '^### ' | grep -F '| 不做了 |' || true)"
in_text prd不做了 '设计规范临时文件' "$QUIT"

echo "[exec 相对 main 没有改动]"
echo "[审查补充：DESIGN.md 位置、派不出去、确认后、打开时机、发不到时的补充]"
has 'docs_repo' '为空时取 `root`' '由用户决定怎么办' '不自己接手出原型或对比' \
  '照清单写约束和验收' '把清单当作期望行为' '原型文件第一次生成后' \
  '再写明"用户已确认"' '3 项之外附上用户的答复' \
  '用户确认的是「设计规范」展示页时，只照抄用户原话'

BASE="$(git -C "$ROOT" merge-base main HEAD 2>/dev/null || echo main)"
if git -C "$ROOT" diff --quiet "$BASE" -- plugins/bb-spec-workflow/skills/exec; then pass; else fail "plugins/bb-spec-workflow/skills/exec 相对 main 的分叉点有改动"; fi

echo ""
echo "通过 ${PASS}，失败 ${FAIL}"
[[ "$FAIL" -eq 0 ]]
