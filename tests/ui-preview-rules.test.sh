#!/usr/bin/env bash
# 界面预览外壳规则校验：prd/revise/exec 的 SKILL 文案与 validate.sh 对外壳文件的检查
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
  if grep -qF -- "$text" "$SKILLS/$skill/SKILL.md"; then pass; else fail "${skill} 缺少：${text}"; fi
}

lacks() {
  local skill="$1" text="$2"
  if grep -qF -- "$text" "$SKILLS/$skill/SKILL.md"; then fail "${skill} 不应含：${text}"; else pass; fi
}

echo "[prd、revise 用外壳出原型]"
for s in prd revise; do
  for t in '${CLAUDE_PLUGIN_ROOT}/templates/ui-preview-shell.html' 'PROTOTYPE-START' 'PROTOTYPE-END' '外壳一律不改' '`note`' '`fake`' '`openQuestions`' \
    '框里禁止放说明或切换控件' '`schemes`' '不拆成多个文件' '把没选中的方案删掉' \
    'terminal: true' 'data-go'; do
    has "$s" "$t"
  done
done

echo "[prd、revise 的外壳不写成产品功能]"
has prd '外壳不写成产品功能'
has revise '外壳不算'

echo "[exec、revise 只比框里的内容]"
for s in exec revise; do
  for t in '和预览框里的内容逐项对比' '不参与对比' '假数据和假操作'; do
    has "$s" "$t"
  done
done

echo "[prd、revise 不含过期表述]"
for s in prd revise; do lacks "$s" 'CSS 和 JS 都写在文件里'; done

echo "[外壳文件存在]"
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
