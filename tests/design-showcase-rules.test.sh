#!/usr/bin/env bash
# 设计规范展示页规则校验：模板 design-showcase.js、子代理定义的展示页一节、/prototype 规程的对话约束
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WF="$ROOT/plugins/bb-spec-workflow"
JS="$WF/templates/design-showcase.js"
AGENT="$WF/agents/prototype-designer.md"
PROTO="$WF/skills/prototype/SKILL.md"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

has_in() {
  local label="$1" file="$2"; shift 2
  local t
  for t in "$@"; do
    if grep -qF -- "$t" "$file" 2>/dev/null; then pass; else fail "${label} 缺少：${t}"; fi
  done
}

lacks_in() {
  local label="$1" file="$2"; shift 2
  local t
  for t in "$@"; do
    if grep -qF -- "$t" "$file" 2>/dev/null; then fail "${label} 不应含：${t}"; else pass; fi
  done
}

echo "[模板 design-showcase.js]"
has_in 模板 "$JS" 'dsContrast' 'dsTag' 'dsPair' 'dsWhy' 'DS_CSS' 'DS_TERMINAL_CSS' \
  '#D97706' '#6366F1' '#FDE68A' '#422006' '#BBF7D0' '#052E16' '#C7D2FE' '#1E1B4B' \
  '现状 · 不达标' '建议 · 本页按这个画' '改之前' '改之后'

if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: 本机没有 node，模板的语法和对比度检查无法运行"
  exit 1
fi
if node --check "$JS" 2>/dev/null; then pass; else fail "node --check 应通过：${JS#"$ROOT"/}"; fi

contrast() {
  node -e '
    const src = require("fs").readFileSync(process.argv[1], "utf8");
    const f = new Function("a", "b", src + "; return dsContrast(a, b);");
    try { process.stdout.write("OK:" + String(f(process.argv[2], process.argv[3]))); }
    catch (e) { process.stdout.write("ERR:" + e.message); }
  ' "$JS" "$1" "$2" 2>/dev/null || true
}

expect_value() {
  local a="$1" b="$2" want="$3" got
  got="$(contrast "$a" "$b")"
  if [[ "$got" == "OK:${want}" ]]; then pass; else fail "dsContrast('${a}', '${b}') 应得 ${want}，实际：${got:-无输出}"; fi
}

expect_throw() {
  local a="$1" b="$2" bad="$3" got
  got="$(contrast "$a" "$b")"
  if [[ "$got" != ERR:* ]]; then fail "dsContrast('${a}', '${b}') 应抛错，实际：${got:-无输出}"; return; fi
  if [[ "$got" == *'#RRGGBB'* ]]; then pass; else fail "dsContrast('${a}', '${b}') 的错误信息应含 #RRGGBB：${got}"; fi
  if [[ -n "$bad" ]]; then
    if [[ "$got" == *"$bad"* ]]; then pass; else fail "dsContrast('${a}', '${b}') 的错误信息应含收到的值 ${bad}：${got}"; fi
  fi
}

expect_value '#94A3B8' '#FFFFFF' 2.6
expect_value '#475569' '#FFFFFF' 7.6
expect_value '#FFFFFF' '#000000' 21.0
expect_value '#ffffff' '#000000' 21.0
expect_throw '#fff' '#000000' '#fff'
expect_throw 'rgb(255,255,255)' '#000000' 'rgb(255,255,255)'
expect_throw '#ffffff80' '#000000' '#ffffff80'
expect_throw '' '#000000' ''
expect_throw '#FFFFFF' '#000' '#000'

echo "[子代理定义：展示页一节的位置]"
sec_line() { grep -nxF -- "$1" "$AGENT" 2>/dev/null | head -n1 | cut -d: -f1 || true; }
L_DESIGN="$(sec_line '## 设计规范（DESIGN.md）')"
L_SHOW="$(sec_line '## 设计规范展示页')"
L_EVID="$(sec_line '## 取证顺序')"
if [[ -n "$L_DESIGN" && -n "$L_SHOW" && -n "$L_EVID" && "$L_DESIGN" -lt "$L_SHOW" && "$L_SHOW" -lt "$L_EVID" ]]; then
  pass
else
  fail "「## 设计规范展示页」应在「## 设计规范（DESIGN.md）」之后、「## 取证顺序」之前：${L_DESIGN:-无} ${L_SHOW:-无} ${L_EVID:-无}"
fi

echo "[子代理定义：展示页内容]"
has_in 子代理定义 "$AGENT" \
  '{templates_dir}/design-showcase.js' 'dsContrast' 'dsPair' 'dsTag' '--ds-surface' \
  '用户确认展示页之后才出要设计的页面' '要新建' '要修改' '要加进 DESIGN.md' \
  '名字叫「设计规范」' '每套风格是一个方案' \
  '标题「设计规范 · <项目名>」、摘要、颜色、字体与字号、间距、「圆角、边框、阴影」、组件、动效' \
  '全部符合写法标准' '哪一项不想改直接说' '这次要改几项' \
  '用途名、色值、用在哪' '按钮文字对它的对比度' '随右上角的主题切换' \
  '名字、字号、行高、字重' '宽度等于这个值的色条' '样例方块' \
  '默认、悬停、按下、禁用、聚焦' '「默认」一列的组件是真的' '没有这个状态' '表格、弹窗、提示条另外各画一个完整样例' \
  '按这个时长动一次' \
  '按建议改好的值画' '现状 · 不达标' '建议 · 本页按这个画' '实际数值和要求的数值' '所属主题的卡片背景色' '不随右上角的主题切换变化' \
  '改回现状的值' '去掉它的对比框' '例外表' \
  '本次修改' '本次新增' '改之前' '改之后' '规范里原来没有' \
  '不随项目配色和主题变化' \
  '颜色、符号、表格、进度条' '对终端背景的对比度' 'DS_TERMINAL_CSS' \
  '不画「布局与断点」和「无障碍」两节' \
  '颜色先换算成 #RRGGBB 再传给 `dsContrast`' \
  '草稿先存到原型文件旁边' '草稿和展示页一起改' '把草稿改名成 `.DESIGN.md`' '由 `/prd` 落盘 PRD 时写入项目' \
  '写成项目的 DESIGN.md，删掉草稿' '「设计规范」一页从原型里删掉' '这次的原型确认后删掉草稿'
lacks_in 子代理定义 "$AGENT" '风格样张' '还没确认的草稿只贴在对话里' '草稿只留在对话里'

echo "[/prototype 规程：对话里不贴全文]"
has_in prototype规程 "$PROTO" '「设计规范」展示页' '不贴 DESIGN.md 或草稿全文' '告诉用户草稿的完整路径' '新建和修改都画成展示页给用户看'

echo "[审查补充：展示页各节的细节]"
has_in 子代理定义 "$AGENT" '哪一项不想改直接说，那一项按现状画并记进例外表' '这次要改几项，逐条列出' \
  '文字色、边框色、成功色、警告色、错误色写出它对所在背景的对比度' '写出字体' '用这一级的样式写一行示例文字' \
  '写名字、数值、用在哪' '写名字、时长和缓动、用在哪' 'transition-duration' '写了"不适用"的组件不画' \
  '标题写这一项的名字和它属于哪套主题' '`side` 传这一项所属主题的颜色' '摘要里去掉这一条' \
  '新增的项左格不画样例' '因不达标而修改的项' '每个符号和它的含义' '一个带表头的样例' \
  '删掉其余方案' '填写区已有 `dsContrast` 时不再复制' '这时不交确认内容清单' \
  '删掉「设计规范」一页，按草稿出这一次' '已画的页面保留'
has_in prototype规程 "$PROTO" '确认的是「设计规范」展示页' '把用户的原话当作答复'
has_in 模板 "$JS" 'color:var(--ds-text)'

echo ""
echo "通过 ${PASS}，失败 ${FAIL}"
[[ "$FAIL" -eq 0 ]]
