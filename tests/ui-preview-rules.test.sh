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

echo "[prototype 写明原型做法]"
for t in '${CLAUDE_PLUGIN_ROOT}/templates/ui-preview-shell.html' 'PROTOTYPE-START' 'PROTOTYPE-END' '外壳一律不改' \
  '框里禁止放说明或切换控件' '`note`' '`fake`' '`openQuestions`' '`css`' '照实还原' '默认页面样式' \
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
  '外壳的左栏、框上方提示、底部说明不参与对比' '与实际界面不同不算不一致' '- 不一致：' '- 没跑起来：'; do
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
COPY="$(cd "$(mktemp -d)" && pwd -P)"
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
