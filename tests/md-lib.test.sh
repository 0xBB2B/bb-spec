#!/usr/bin/env bash
# tests/lib/md.sh 的接口：按代码块规则取一节、找标题行号、按行过滤、给每行标代码块状态
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." >/dev/null && pwd)"
LIB="$ROOT/tests/lib/md.sh"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

summary() {
  echo ""
  echo "通过 ${PASS}，失败 ${FAIL}"
  [[ "$FAIL" -eq 0 ]]
}

TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

if [[ ! -r "$LIB" ]]; then
  fail "读不到 tests/lib/md.sh"
  summary
  exit 1
fi
# shellcheck source=/dev/null
source "$LIB"

# 比较：eq <标签> <期望> <实际>
eq() {
  if [[ "$3" == "$2" ]]; then pass; else fail "$1：期望「${2//$'\n'/⏎}」，实际「${3//$'\n'/⏎}」"; fi
}

# 读取文件内容，不管命令成功与否都返回 0，并把返回码记到 RC
RC=0
run() { local out; RC=0; out="$("$@")" || RC=$?; printf '%s' "$out"; }

mk() { printf '%s\n' "${@:2}" >"$TMP/$1"; }

echo "[接口存在]"
for f in md_section md_line md_grep_n; do
  if declare -F "$f" >/dev/null; then pass; else fail "缺少函数：$f"; fi
done
if [[ -n "${MD_CB_AWK:-}" ]]; then pass; else fail "缺少变量：MD_CB_AWK"; fi

mk basic.md \
  '# T' \
  'intro' \
  '## A' \
  'a1' \
  '### A1' \
  'a11' \
  '```bash' \
  '## fake' \
  '# c' \
  '```' \
  'a2' \
  '## B' \
  'b1' \
  '**7d. X**：见 `y`' \
  '**7e. Z**'

echo "[md_section：正常和代码块]"
eq 同级标题结束 "$(printf '%s\n' '## A' 'a1' '### A1' 'a11' '```bash' '## fake' '# c' '```' 'a2')" "$(run md_section "$TMP/basic.md" '## A')"
eq 带结束正则 "$(printf '%s\n' '## A' 'a1' '### A1' 'a11' '```bash' '## fake' '# c' '```' 'a2')" "$(run md_section "$TMP/basic.md" '## A' '^## ')"
eq 一级标题到文件末尾 "$(cat "$TMP/basic.md")" "$(run md_section "$TMP/basic.md" '# T')"
eq 三级标题被二级标题结束 "$(printf '%s\n' '### A1' 'a11' '```bash' '## fake' '# c' '```' 'a2')" "$(run md_section "$TMP/basic.md" '### A1')"
eq 最后一节到文件末尾 "$(printf '%s\n' '## B' 'b1' '**7d. X**：见 `y`' '**7e. Z**')" "$(run md_section "$TMP/basic.md" '## B')"
eq 加粗起始行和结束正则 '**7d. X**：见 `y`' "$(run md_section "$TMP/basic.md" '**7d.' '^\*\*7[a-z]\.|^## ' | head -n1)"
eq 起始行不当结束行 "$(printf '%s\n' '## B' 'b1' '**7d. X**：见 `y`')" "$(run md_section "$TMP/basic.md" '## B' '^\*\*7e\.')"
eq 起始行只在代码块里 '' "$(run md_section "$TMP/basic.md" '## fake')"
eq 结束正则只在代码块里不结束 "$(printf '%s\n' '### A1' 'a11' '```bash' '## fake' '# c' '```' 'a2' '## B' 'b1' '**7d. X**：见 `y`' '**7e. Z**')" "$(run md_section "$TMP/basic.md" '### A1' '^# fake$|^## Z')"
eq 找不到起始行 '' "$(run md_section "$TMP/basic.md" '## 不存在')"
eq 读不到文件 '' "$(run md_section "$TMP/没有这个文件.md" '## A')"
run md_section "$TMP/没有这个文件.md" '## A' >/dev/null
eq 读不到文件返回码 0 "$RC"
run md_section "$TMP/basic.md" '## 不存在' >/dev/null
eq 找不到起始行返回码 0 "$RC"
eq "FILE 为 -" "$(printf '%s\n' '### A1' 'a11' '```bash' '## fake' '# c' '```' 'a2')" "$(md_section - '### A1' <"$TMP/basic.md")"

echo "[md_section：嵌套代码块、尾随空白、反引号数]"
mk nested.md \
  '## N' \
  'n1' \
  '````markdown' \
  '```bash' \
  '## in1' \
  '```' \
  '## in2' \
  '````' \
  'n2' \
  '## After'
eq 嵌套里的内层围栏不关闭外层 "$(printf '%s\n' '## N' 'n1' '````markdown' '```bash' '## in1' '```' '## in2' '````' 'n2')" "$(run md_section "$TMP/nested.md" '## N')"

printf '%s\n' '## S' 's1' '```  ' '## in' '```   ' 's2' '## E' >"$TMP/trail.md"
eq 带尾随空格的关闭行 "$(printf '%s\n' '## S' 's1' '```  ' '## in' '```   ' 's2')" "$(run md_section "$TMP/trail.md" '## S')"
printf '%s\n' '## S' '```' '## in' '```	' 's2' '## E' >"$TMP/tab.md"
eq 带尾随制表符的关闭行 "$(printf '%s\n' '## S' '```' '## in' '```	' 's2')" "$(run md_section "$TMP/tab.md" '## S')"

mk fewer.md \
  '## S' \
  '````' \
  '```' \
  '## in' \
  '````' \
  's2' \
  '## E'
eq 反引号更少的行不关闭 "$(printf '%s\n' '## S' '````' '```' '## in' '````' 's2')" "$(run md_section "$TMP/fewer.md" '## S')"

mk more.md \
  '## S' \
  '```' \
  '## in' \
  '`````' \
  's2' \
  '## E'
eq 反引号更多的行关闭 "$(printf '%s\n' '## S' '```' '## in' '`````' 's2')" "$(run md_section "$TMP/more.md" '## S')"

mk withtext.md \
  '## S' \
  '```' \
  '```bash' \
  '## in' \
  '```' \
  's2' \
  '## E'
eq 带文字的围栏行不关闭 "$(printf '%s\n' '## S' '```' '```bash' '## in' '```' 's2')" "$(run md_section "$TMP/withtext.md" '## S')"

mk unclosed.md \
  '## S' \
  '```' \
  '## in' \
  's2'
eq 没关闭的代码块一直到文件末尾 "$(cat "$TMP/unclosed.md")" "$(run md_section "$TMP/unclosed.md" '## S')"

echo "[md_line]"
mk lines.md \
  '```' \
  '## X' \
  '```' \
  '## X 后缀' \
  '## X' \
  '````md' \
  '```' \
  '## X' \
  '```' \
  '````' \
  '## X'
eq 跳过代码块里的同名行 4 "$(run md_line "$TMP/lines.md" '## X')"
eq 精确匹配跳过前缀相同的行 5 "$(run md_line "$TMP/lines.md" '## X' exact)"
eq 行内容只在代码块里 '' "$(run md_line "$TMP/basic.md" '## fake')"
eq 找不到 '' "$(run md_line "$TMP/basic.md" '## 不存在')"
eq 读不到文件 '' "$(run md_line "$TMP/没有这个文件.md" '## X')"
run md_line "$TMP/没有这个文件.md" '## X' >/dev/null
eq 读不到文件返回码 0 "$RC"
run md_line "$TMP/basic.md" '## 不存在' >/dev/null
eq 找不到返回码 0 "$RC"
eq 嵌套代码块后的行 9 "$(run md_line "$TMP/nested.md" 'n2' exact)"
eq "FILE 为 -" 4 "$(md_line - '## X' <"$TMP/lines.md")"
eq 精确匹配不认尾随空白 '' "$(printf '%s\n' '## X ' | md_line - '## X' exact)"

echo "[md_grep_n]"
eq 只输出代码块外的匹配 "$(printf '%s\n' '4:## X 后缀' '5:## X' '11:## X')" "$(run md_grep_n "$TMP/lines.md" '^## X')"
eq 带结束符的正则 "$(printf '%s\n' '5:## X' '11:## X')" "$(run md_grep_n "$TMP/lines.md" '^## X$')"
eq 没有匹配 '' "$(run md_grep_n "$TMP/lines.md" '^## 不存在')"
run md_grep_n "$TMP/lines.md" '^## 不存在' >/dev/null
eq 没有匹配返回码 0 "$RC"
eq 读不到文件 '' "$(run md_grep_n "$TMP/没有这个文件.md" '.')"
run md_grep_n "$TMP/没有这个文件.md" '.' >/dev/null
eq 读不到文件返回码 0 "$RC"
eq "FILE 为 -" "$(printf '%s\n' '4:## X 后缀' '5:## X' '11:## X')" "$(md_grep_n - '^## X' <"$TMP/lines.md")"
eq 扩展正则的或 "$(printf '%s\n' '1:# T' '12:## B')" "$(run md_grep_n "$TMP/basic.md" '^# T$|^## B$')"

echo "[MD_CB_AWK：每行的 cb]"
mk cb.md \
  '外' \
  '````markdown' \
  '```bash' \
  '内' \
  '```' \
  '````  ' \
  '外2' \
  '```' \
  '内2' \
  '```' \
  '外3'
cb_out="$(awk "${MD_CB_AWK}"$'\n''{ print cb }' "$TMP/cb.md" | tr '\n' ' ')"
eq "每行的 cb" "0 1 1 1 1 1 0 1 1 1 0 " "$cb_out"
cb_text="$(awk "${MD_CB_AWK}"$'\n''{ print }' "$TMP/cb.md")"
eq 不输出也不跳过行 "$(cat "$TMP/cb.md")" "$cb_text"

summary
