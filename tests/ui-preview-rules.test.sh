#!/usr/bin/env bash
# 界面预览规则校验：prototype 写明做法，prd/revise/exec 只调用它，以及 validate.sh 对外壳文件的检查
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS="$ROOT/plugins/bb-spec-workflow/skills"
SHELL_REL="plugins/bb-spec-workflow/templates/ui-preview-shell.html"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

has() {
  local skill="$1" text="$2"
  if grep -qF -- "$text" "$SKILLS/$skill/SKILL.md" 2>/dev/null; then pass; else fail "${skill} 缺少：${text}"; fi
}

lacks() {
  local skill="$1" text="$2"
  if grep -qF -- "$text" "$SKILLS/$skill/SKILL.md" 2>/dev/null; then fail "${skill} 不应含：${text}"; else pass; fi
}

PROTO="$SKILLS/prototype/SKILL.md"

echo "[prototype 的 frontmatter]"
FM="$(awk '/^---[[:space:]]*$/{n++; next} n==1{print} n>=2{exit}' "$PROTO" 2>/dev/null || true)"
if printf '%s\n' "$FM" | grep -qxF 'name: prototype'; then pass; else fail "prototype frontmatter 的 name 应是 prototype"; fi
if printf '%s\n' "$FM" | grep -qF 'disable-model-invocation'; then fail "prototype frontmatter 不应含 disable-model-invocation"; else pass; fi

for t in '左栏切页面和状态' '右上角按需切方案和页面主题' '中间的框只放正式页面'; do
  if printf '%s\n' "$FM" | grep -qF -- "$t"; then pass; else fail "prototype frontmatter 的 description 应含「${t}」"; fi
done
for t in '明暗主题' '底部放说明'; do
  if printf '%s\n' "$FM" | grep -qF -- "$t"; then fail "prototype frontmatter 的 description 不应含「${t}」"; else pass; fi
done

echo "[prototype 写明原型做法]"
for t in '${CLAUDE_PLUGIN_ROOT}/templates/ui-preview-shell.html' 'PROTOTYPE-START' 'PROTOTYPE-END' '外壳一律不改' \
  '框里禁止放说明或切换控件' '`css`' '照实还原' '默认页面样式' \
  '`schemes`' '不拆成多个文件' '把没选中的方案删掉' 'terminal: true' 'data-go' 'open <文件路径>' \
  '明确说"可以"' '不写 PRD' '--file' '--compare' '和原型框里的内容逐项对比' '不参与对比' \
  '假数据和假操作' 'ui-compare/' '没跑起来'; do
  has prototype "$t"
done

echo "[prototype 正文的模式、取目录和文件位置]"
for t in '| `/prototype <主题>` |' '| `<主题> --file <路径>` |' '| `--compare <路径>` |' \
  'scripts/bbspec-paths.sh' '`${CACHE_DIR}/.gitignore`' '会话临时目录' \
  '`${CACHE_DIR}/ui-preview/<YYYY-MM-DD>.<主题>.html`' '文件已存在时直接改它' \
  '不改产品代码' '写了 `css` 后默认页面样式完全不生效' \
  '外壳的左栏和框上方一行不参与对比' '不算不一致' '- 不一致：' '- 没跑起来：'; do
  has prototype "$t"
done
if awk '/^## /{sec=$0} /bbspec-paths.sh/{print sec}' "$PROTO" 2>/dev/null | grep -qF '两种模式都先做'; then pass; else fail "prototype 取缓存目录要放在各模式之前"; fi

echo "[prototype 给了文件时取缓存目录的写法和顺序]"
T_FILE='给了 `--file` 或 `--compare`、且这个文件在 `ui-preview/` 目录下的，`${CACHE_DIR}` 改取这个 `ui-preview/` 的上一级'
T_TEMP='其余情况下，项目没有 `.bb-spec/` 和 `.bb-spec.yaml` 时'
T_IGNORE='确保 `${CACHE_DIR}/.gitignore` 存在'
has prototype "$T_FILE"
has prototype "$T_TEMP"
lacks prototype '改取这个文件所在目录的上一级'
text_pos() {
  awk -v t="$2" '{ i = index($0, t); if (i > 0) { print NR * 100000 + i; exit } }' "$1" 2>/dev/null
}
P_FILE="$(text_pos "$PROTO" "$T_FILE")"
P_TEMP="$(text_pos "$PROTO" "$T_TEMP")"
P_IGNORE="$(text_pos "$PROTO" "$T_IGNORE")"
if [[ -n "$P_FILE" && -n "$P_TEMP" && -n "$P_IGNORE" && "$P_FILE" -le "$P_TEMP" && "$P_TEMP" -le "$P_IGNORE" ]]; then
  pass
else
  fail "prototype 里应依次出现：给了文件的取法、两者都没给的临时目录、.gitignore 那句"
fi

echo "[prototype 的 description 写明先读 DESIGN.md 和取证]"
for t in '先读项目根目录的 DESIGN.md' '改动所在的整个页面' '缺的只读对应源码' '源码定不下来才问用户要不要跑服务'; do
  if printf '%s\n' "$FM" | grep -qF -- "$t"; then pass; else fail "prototype frontmatter 的 description 应含「${t}」"; fi
done

echo "[prototype 的 DESIGN.md 两节在出原型之前]"
sec_line() { grep -nxF -- "$1" "$PROTO" 2>/dev/null | head -n1 | cut -d: -f1 || true; }
L_DESIGN="$(sec_line '## 设计规范（DESIGN.md）')"
L_EVID="$(sec_line '## 取证顺序')"
L_PROTO="$(sec_line '## 出原型')"
if [[ -n "$L_DESIGN" && -n "$L_EVID" && -n "$L_PROTO" && "$L_DESIGN" -lt "$L_PROTO" && "$L_EVID" -lt "$L_PROTO" ]]; then
  pass
else
  fail "prototype 的「## 设计规范（DESIGN.md）」和「## 取证顺序」都应在「## 出原型」之前"
fi

echo "[prototype 的 DESIGN.md 位置与写入]"
for t in 'docs_repo' '为空时放在输出的 `root`' '新建和修改都要用户明确同意后才写入这个位置' \
  '.DESIGN.draft.md' '${CLAUDE_PLUGIN_ROOT}/templates/DESIGN.md'; do
  has prototype "$t"
done

echo "[prototype 的 DESIGN.md 写法标准]"
for t in '风格定位、颜色、字体与字号、间距、「圆角、边框、阴影」、布局与断点、组件、动效、无障碍、终端界面' \
  '不适用' '按用途命名' '明暗两套' 'WCAG 2.2 AA' '4.5:1' '3:1' '24px 及以上，或 18.66px 及以上加粗' \
  '相对亮度公式' '4 的倍数' '9999px' '形容词' '按钮、输入框、表格、卡片、弹窗、提示条' \
  '写法（HTML 结构和类名）' '默认、悬停、按下、禁用、聚焦' '页面框架' '「例外」表里的项，检查时不再报'; do
  has prototype "$t"
done

echo "[prototype 过一遍 DESIGN.md]"
for t in '第一步先读 DESIGN.md' '如实记录现状，包括页面框架和组件的写法' '确认前不出原型' '2～3 套' \
  '方案 `html` 开头的 `<style>`' '把选中风格的样式移进 `css`' '选定前不出要设计的页面' \
  '缺项或不达标' '先改 DESIGN.md' '「例外」表记下哪一项、实际值、用户确认的日期' '逐个列出' '改用 DESIGN.md 里有的'; do
  has prototype "$t"
done

echo "[prototype 的取证顺序]"
for t in '前一步够用就不往下走' '只按 DESIGN.md 画，不读源码' '只读这一部分对应的源码' \
  '整理成 DESIGN.md 的补充内容' '仍定不下来样子' '问用户要不要把项目跑起来看' '哪些部分可能不准'; do
  has prototype "$t"
done

echo "[prototype 跑服务取底稿]"
for t in '只在用户同意后' '完整的启动命令和它的出处' '哪个文件、哪一行' '依赖没装时一并说明' '用户再次同意才执行' \
  '最终生效的样式' '去掉其中的 `<script>`、内联事件属性' '真实用户数据' '不改的部分保持原样' \
  '立即关掉为出原型启动的服务' '没有能打开网页的工具' '卡在哪一步'; do
  has prototype "$t"
done

echo "[prototype 画什么]"
for t in '整个页面，包括顶栏、侧边栏、导航、页面标题和周围的组件' '照 DESIGN.md 的写法写' 'HTML 结构和类名' \
  '读了哪些源码文件' '底稿来自哪个地址'; do
  has prototype "$t"
done

echo "[prototype 终端原型]"
for t in 'DESIGN.md「终端界面」' '实际运行命令看输出' 'terminalCss' '外壳默认终端配色只在项目没有命令行输出代码时使用'; do
  has prototype "$t"
done

echo "[prototype 出原型第 1 条先过 DESIGN.md]"
L_FIRST="$(grep -n '^1\. 按「设计规范（DESIGN.md）」先过一遍 DESIGN.md' "$PROTO" 2>/dev/null | head -n1 | cut -d: -f1 || true)"
L_PLACE="$(grep -n '^[0-9][0-9]*\. 确定文件位置' "$PROTO" 2>/dev/null | head -n1 | cut -d: -f1 || true)"
if [[ -n "$L_FIRST" && -n "$L_PLACE" && -n "$L_PROTO" && "$L_FIRST" -gt "$L_PROTO" && "$L_FIRST" -lt "$L_PLACE" ]]; then
  pass
else
  fail "「## 出原型」编号列表第 1 条应以「1. 按「设计规范（DESIGN.md）」先过一遍 DESIGN.md」开头，且排在「确定文件位置」那一条之前"
fi

echo "[prototype 不含与取证顺序矛盾的写法]"
lacks prototype '文字颜色用外壳提供的绿、黄、蓝、红'
lacks prototype '项目没有自己的设计时不写 `css`'
lacks prototype '判定能不能跑起来'

echo "[prototype 草稿写入、不想建时的退路、跑服务和对比的保护]"
for t in '被 `/prd` 调用时' '先写进和原型文件同名的草稿' '由 `/prd` 落盘 PRD 时一起写入项目' \
  '被 `/revise` 调用或单独运行时，用户同意即写入' '用户这次不想建 DESIGN.md' '按草稿出这一次原型，不写入项目' '下次出原型时再问' \
  '每套风格画一页风格样张' '按下面第 2～4 步建好原型文件' \
  '问用户之前先确认有能打开网页的工具' '没有就不问' \
  '登录凭据和 token' '换成假数据' '确认端口已不在监听' '启动失败' '2 分钟内打不开要改的页面' '页面要登录' \
  '用到了 DESIGN.md 的哪几节' \
  '运行前同样先列出完整命令和出处' '用户再次同意才执行；输出里的真实数据换成假数据' \
  '需要跑项目时，同样先列出完整命令和出处' '对比完立即关掉' '用户不同意时返回「没跑起来」'; do
  has prototype "$t"
done
P1="$(text_pos "$PROTO" '1. **DESIGN.md**：')"
P2="$(text_pos "$PROTO" '2. **源码**：')"
P3="$(text_pos "$PROTO" '3. **问用户要不要跑**：')"
if [[ -n "$P1" && -n "$P2" && -n "$P3" && "$P1" -lt "$P2" && "$P2" -lt "$P3" ]]; then pass; else fail "取证顺序应依次是 DESIGN.md、源码、问用户要不要跑：${P1:-无} ${P2:-无} ${P3:-无}"; fi
lacks prototype '把实际界面跑起来，和原型框里的内容逐项对比'
for t in '改完后的完整 DESIGN.md' '还没确认的草稿只贴在对话里' \
  '草稿只留在对话里' '不提议写入 DESIGN.md' '用户选定风格但不想建 DESIGN.md 时同第 2 条' \
  '命令行项目展示「终端界面」一节的颜色、符号、表格和进度条' '删掉其余方案和风格样张页' '按第 8、9 步打开给用户看' \
  '运行命令不需要能打开网页的工具' '依赖没装时一并说明，用户再次同意才执行' \
  '启动前先看要用的端口有没有被占用' '用现有服务时不关它' '只确认自己启动的' '用户现有的服务不关' \
  '终端界面运行命令看输出（同样先经用户同意）' '符号、表格和进度条格式'; do
  has prototype "$t"
done
lacks prototype '终端界面直接运行命令看输出'
lacks prototype '${CACHE_DIR}/DESIGN.draft.md'
for t in '`revise-` 开头' '不留草稿文件' '原型文件旁边的草稿存在时，后面再出原型以它为准' \
  '命令行项目移进各终端页的 `terminalCss`' '至少放一条' '端口被占用' \
  '也立即关掉为出原型启动的服务' '占用它的服务是从哪个目录起的' '对比完立即关掉为对比启动的服务并确认端口已不在监听'; do
  has prototype "$t"
done

echo "[prototype 全文不含已删除的填写项和旧说明区]"
for t in '`note`' '`fake`' '`openQuestions`' '底部说明' '只在原型里成立' '底部放说明' '明暗主题'; do
  lacks prototype "$t"
done
for t in 'note' 'fake' 'openQuestions'; do
  if grep -qF -- "$t" "$PROTO" 2>/dev/null; then fail "prototype 不应含 ${t}"; else pass; fi
done

echo "[prototype 打开原型时在对话里讲]"
OPEN_STEP="$(awk '/用 `open <文件路径>`/{on=1} on&&/^9\. /{exit} on' "$PROTO")"
for t in '同一条回复' '用到了 DESIGN.md 的哪几节' '读了哪些源码文件' '底稿来自哪个地址' \
  '假数据和假操作' '可能不准' '没有能打开网页的工具' '端口被占用' '服务没跑起来' '还没确认的问题'; do
  if grep -qF -- "$t" <<<"$OPEN_STEP"; then pass; else fail "打开原型那一步缺「${t}」"; fi
done

echo "[prototype 规范外样式在对话里逐个列出]"
for t in '颜色、字号、间距、圆角、阴影或组件样式' '逐个列出' '问用户' '写进 DESIGN.md' '改用 DESIGN.md 里有的' '规范外样式和源码补充在对话里说明'; do
  has prototype "$t"
done

echo "[prototype 多方案在对话里讲取舍]"
for t in '取舍' '选哪个' '`id`' '`label`' '`desc`'; do
  has prototype "$t"
done

echo "[prototype 主题按 DESIGN.md 颜色一节声明]"
for t in '`themes`' '`data-theme="<id>"`' '「颜色」一节' '声明几套' '只写了一套不声明' '照加' '每套主题'; do
  has prototype "$t"
done

echo "[prototype 对比一节]"
for t in '只比布局、文案、每种状态、每个交互操作后的结果' '示例数据' '订单号、人名、金额、数量、日期' '外壳的左栏和框上方一行不参与对比' '多套主题逐套对比'; do
  has prototype "$t"
done

echo "[prd、revise、exec 的调用写法和文件名]"
has prd 'Skill bb-spec-workflow:prototype'
has prd '--file ${CACHE_DIR}/ui-preview/<YYYY-MM-DD>.<主题>.html'
has revise 'Skill bb-spec-workflow:prototype'
has revise '--file ${CACHE_DIR}/ui-preview/revise-<YYYY-MM-DD>-<主题>.html'
for s in exec revise; do
  has "$s" 'Skill bb-spec-workflow:prototype'
  has "$s" '--compare <预览页路径>'
done
lacks prd '同步骤 3'

echo "[prd、revise 调用 prototype，不含做法细节]"
for s in prd revise; do
  has "$s" 'bb-spec-workflow:prototype'
  for t in 'PROTOTYPE-START' 'terminal: true' '把没选中的方案删掉' '框里禁止放说明或切换控件' 'templates/ui-preview-shell.html'; do
    lacks "$s" "$t"
  done
done

echo "[prd、revise 的外壳不写成产品功能]"
has prd '外壳不写成产品功能'
has revise '外壳不算'

echo "[exec、revise 调用对比模式，不含对比细节]"
for s in exec revise; do
  has "$s" '--compare'
  for t in '不参与对比' '假数据和假操作'; do lacks "$s" "$t"; done
done

echo "[exec 保留三种处理]"
for t in '全部一致' '有不一致' '实际界面跑不起来'; do has exec "$t"; done

echo "[prototype 引用的外壳文件]"
if [[ -f "$ROOT/$SHELL_REL" ]]; then pass; else fail "外壳文件不存在：$SHELL_REL"; fi

echo "[validate.sh 对外壳文件的检查]"
COPY="$(mktemp -d)"
COPY="$(cd "$COPY" && pwd -P)"
trap 'rm -rf "$COPY"' EXIT

copy_repo() {
  local dst="$1" item
  mkdir -p "$dst"
  for item in "$ROOT"/* "$ROOT"/.[!.]*; do
    case "$(basename "$item")" in .git|.bb-spec) continue ;; esac
    [[ -e "$item" ]] && cp -R "$item" "$dst/"
  done
}

copy_repo "$COPY/ok"
if (cd "$COPY/ok" && bash tests/validate.sh >"$COPY/ok.out" 2>&1); then pass; else fail "外壳存在时 validate.sh 应退出 0"; fi

copy_repo "$COPY/missing"
rm -f "$COPY/missing/$SHELL_REL"
if (cd "$COPY/missing" && bash tests/validate.sh >"$COPY/missing.out" 2>&1); then
  fail "删掉外壳后 validate.sh 应退出非 0"
else
  pass
fi
if grep -qF 'ui-preview-shell.html' "$COPY/missing.out"; then pass; else fail "删掉外壳后输出应含 ui-preview-shell.html"; fi

copy_repo "$COPY/leak"
printf '<!-- /Users/someone/x -->\n' >> "$COPY/leak/$SHELL_REL"
if (cd "$COPY/leak" && bash tests/validate.sh >"$COPY/leak.out" 2>&1); then
  fail "外壳含个人路径时 validate.sh 应退出非 0"
else
  pass
fi

echo ""
echo "通过 ${PASS}，失败 ${FAIL}"
[[ "$FAIL" -eq 0 ]]
