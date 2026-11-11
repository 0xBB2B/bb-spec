#!/usr/bin/env bash
# 原型子代理定义校验：prototype-designer.md 含固定做法文本
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AGENT="$ROOT/plugins/bb-spec-workflow/agents/prototype-designer.md"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

has() {
  if grep -qF -- "$1" "$AGENT" 2>/dev/null; then pass; else fail "缺少：$1"; fi
}

lacks() {
  if grep -qF -- "$1" "$AGENT" 2>/dev/null; then fail "不应含：$1"; else pass; fi
}

hasall() {
  local t
  for t in "$@"; do has "$t"; done
}

echo "[frontmatter]"
FM="$(awk '/^---[[:space:]]*$/{n++; next} n==1{print} n>=2{exit}' "$AGENT" 2>/dev/null || true)"
for line in 'name: prototype-designer' 'model: fable' 'agent-type: general-purpose'; do
  if printf '%s\n' "$FM" | grep -xF -- "$line" >/dev/null; then pass; else fail "frontmatter 缺少：${line}"; fi
done
if printf '%s\n' "$FM" | grep -E '^[[:space:]]*inputs:' >/dev/null; then pass; else fail "frontmatter 缺少 inputs"; fi
INPUTS="$(printf '%s\n' "$FM" | awk '/^[[:space:]]*inputs:/{on=1; next} on{print}')"
for key in mode topic prototype_file caller requirement design_md_path design_draft_path templates_dir screenshots_dir resume_note; do
  if printf '%s\n' "$INPUTS" | grep -E "^[[:space:]]+- ${key}([[:space:]]|$)" >/dev/null; then pass; else fail "inputs 缺少：${key}"; fi
done

echo "[报告]"
hasall '这一轮改了什么' '依据' '假数据和假操作' '可能不准' '待用户确认的问题' \
  '没有内容的部分写"无"' '不贴 HTML' '不贴源码原文' '不贴 DESIGN.md 全文'

echo "[等答复]"
hasall '拿到主对话转来的用户答复之后才做' '新建 DESIGN.md' '修改 DESIGN.md' '不达标项' \
  '加不加进 DESIGN.md' '选哪个' '要不要把项目跑起来' '完整命令' '用不用现有的服务'

echo "[接着改]"
hasall '原型文件已存在，接着改' '只改用户提到的地方' '其他内容保持原样'

echo "[确认内容清单]"
hasall '确认内容清单' '每种状态下用户看到什么' '每个交互操作后发生什么' '各主题的差异' '不写外壳'

echo "[对比结果]"
hasall '- 一致' '- 不一致：' '- 没跑起来：' '附截图路径'

echo "[可写范围]"
hasall '.DESIGN.draft.md' '不改产品代码' '不操作 git'

echo "[搬来的做法：DESIGN.md 写法标准]"
hasall '风格定位、颜色、字体与字号、间距、「圆角、边框、阴影」、布局与断点、组件、动效、无障碍、终端界面' \
  '不适用' '按用途命名' '明暗两套' 'WCAG 2.2 AA' '4.5:1' '3:1' '24px 及以上，或 18.66px 及以上加粗' \
  '相对亮度公式' '4 的倍数' '9999px' '形容词' '按钮、输入框、表格、卡片、弹窗、提示条' \
  '写法（HTML 结构和类名）' '默认、悬停、按下、禁用、聚焦' '页面框架' '「例外」表里的项，检查时不再报'

echo "[搬来的做法：取证顺序]"
hasall '前一步够用就不往下走' '只按 DESIGN.md 画，不读源码' '只读这一部分对应的源码' \
  '整理成 DESIGN.md 的补充内容' '仍定不下来样子' '问用户要不要把项目跑起来看' '哪些部分可能不准'

echo "[搬来的做法：跑服务取底稿]"
hasall '只在用户同意后' '完整的启动命令和它的出处' '哪个文件、哪一行' '依赖没装时一并说明' '用户再次同意才执行' \
  '最终生效的样式' '去掉其中的 `<script>`、内联事件属性' '真实用户数据' '不改的部分保持原样' \
  '立即关掉为出原型启动的服务' '没有能打开网页的工具' '卡在哪一步'

echo "[搬来的做法：画什么]"
hasall '整个页面，包括顶栏、侧边栏、导航、页面标题和周围的组件' '照 DESIGN.md 的写法写' 'HTML 结构和类名' \
  '读了哪些源码文件' '底稿来自哪个地址'

echo "[搬来的做法：终端原型]"
hasall 'DESIGN.md「终端界面」' '实际运行命令看输出' 'terminalCss' '外壳默认终端配色只在项目没有命令行输出代码时使用'

echo "[外壳与模板]"
hasall 'PROTOTYPE-START' 'PROTOTYPE-END' '外壳一律不改' '框里禁止放说明或切换控件' \
  '{templates_dir}/ui-preview-shell.html' '{templates_dir}/DESIGN.md'

section() {
  awk -v h="$1" 'index($0, h) == 1 {on=1; next} /^## /{on=0} on' "$AGENT" 2>/dev/null || true
}

line_of() {
  grep -nF -- "$1" "$AGENT" 2>/dev/null | head -n1 | cut -d: -f1 || true
}

echo "[补充：等答复、改成写进报告、接着改、确认清单、可写范围]"
hasall '多套风格、多个方案选哪个' '写进报告的「待用户确认的问题」' \
  '先读已有的原型文件和 DESIGN.md' '有草稿读草稿' \
  '收到"用户已确认"后' '按页面逐页写出布局、每处文案' \
  '截图目录' '用户同意后才写 DESIGN.md'

L_RESUME="$(line_of '原型文件已存在，接着改')"
L_READ="$(line_of '先读已有的原型文件和 DESIGN.md')"
if [[ -n "$L_RESUME" && -n "$L_READ" ]] && (( L_READ - L_RESUME <= 3 && L_RESUME - L_READ <= 3 )); then
  pass
else
  fail "「原型文件已存在，接着改」和「先读已有的原型文件和 DESIGN.md」应在同一行或相邻 3 行内"
fi

if section '## 确认内容清单' | grep -F -- '收到"用户已确认"后' >/dev/null; then pass; else fail "「## 确认内容清单」一节应含：收到\"用户已确认\"后"; fi

lacks '回到调用方继续'
if section '## 出原型' | grep -F -- '缓存目录' >/dev/null; then fail "「## 出原型」一节不应含：缓存目录"; else pass; fi

echo "[两个设计规范临时文件]"
hasall '.DESIGN.md' '启动服务、运行命令或安装依赖' '会改动哪些文件' \
  '用户还没同意' '把草稿改名成 `.DESIGN.md`' '写成项目的 DESIGN.md，删掉草稿' \
  '不把它当作已同意的规范' '以它为准' '不重复报已经确认过的问题'
lacks '`revise-` 开头'
lacks '原型文件旁边的草稿存在时'
has '先复制原型文件旁边的 `.DESIGN.md`，没有就复制项目里的 DESIGN.md'
has '都按上面的规则做：先存成草稿，用户同意后再按调用方改名或写入'
lacks '接着请用户确认'

echo "[不含的写法]"
lacks 'AskUserQuestion'
lacks 'open <文件路径>'
lacks '${CLAUDE_PLUGIN_ROOT}'

echo ""
echo "通过 ${PASS}，失败 ${FAIL}"
[[ "$FAIL" -eq 0 ]]
