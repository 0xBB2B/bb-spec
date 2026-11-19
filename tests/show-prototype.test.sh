#!/usr/bin/env bash
# show-prototype.sh 行为校验：已开标签页刷新、未开则新开、出错回退、参数校验、只查在运行的浏览器
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/plugins/bb-spec-workflow/scripts/show-prototype.sh"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

expect_eq() {
  local got="$1" want="$2" label="$3"
  if [[ "$got" == "$want" ]]; then pass; else fail "${label}：预期 [$want]，实际 [$got]"; fi
}

FIXROOT="$(mktemp -d)"
FIXROOT="$(cd "$FIXROOT" && pwd -P)"
trap 'rm -rf "$FIXROOT"' EXIT

BIN="$FIXROOT/bin"
mkdir -p "$BIN" "$FIXROOT/a b"
PROTO="$FIXROOT/a b/原型.html"
PLAIN="$FIXROOT/plain.html"
echo '<html></html>' > "$PROTO"
echo '<html></html>' > "$PLAIN"

OSA_DIR="$FIXROOT/osa"
OPEN_LOG="$FIXROOT/open.log"

cat > "$BIN/osascript" <<FAKE
#!/usr/bin/env bash
n=\$(( \$(ls "$OSA_DIR"/script.* 2>/dev/null | wc -l) + 1 ))
cat > "$OSA_DIR/script.\$n"
printf '%s\n' "\$@" > "$OSA_DIR/args.\$n"
if grep -q '"Google Chrome"' "$OSA_DIR/script.\$n"; then mode="\${OSA_CHROME:-notfound}"
elif grep -q '"Safari"' "$OSA_DIR/script.\$n"; then mode="\${OSA_SAFARI:-notfound}"
else mode=notfound; fi
case "\$mode" in
  reloaded) echo reloaded ;;
  notfound) echo notfound ;;
  error) echo "osascript: not authorized" >&2; exit 1 ;;
esac
FAKE
cat > "$BIN/open" <<FAKE
#!/usr/bin/env bash
{ echo CALL; printf '%s\n' "\$@"; } >> "$OPEN_LOG"
FAKE
chmod +x "$BIN/osascript" "$BIN/open"

OUT="" ERR="" CODE=0
run_script() {
  local chrome="$1" safari="$2"; shift 2
  rm -rf "$OSA_DIR"; mkdir -p "$OSA_DIR"; : > "$OPEN_LOG"
  CODE=0
  OUT=$(OSA_CHROME="$chrome" OSA_SAFARI="$safari" PATH="$BIN:$PATH" bash "$SCRIPT" "$@" 2>"$FIXROOT/err.txt") || CODE=$?
  ERR=$(cat "$FIXROOT/err.txt")
}
osa_calls() { ls "$OSA_DIR"/script.* 2>/dev/null | wc -l | tr -d ' '; }
open_calls() { grep -c '^CALL$' "$OPEN_LOG" || true; }
last_arg() { tail -n 1 "$OSA_DIR/args.$1"; }

# 第 n 次调用的脚本只提到 browser 一个浏览器
expect_only_browser() {
  local n="$1" browser="$2" other
  [[ "$browser" == "Chrome" ]] && other='Safari' || other='Google Chrome'
  local mine='Safari'; [[ "$browser" == "Chrome" ]] && mine='Google Chrome'
  local f="$OSA_DIR/script.$n"
  if [[ -f "$f" ]] && grep -q "\"$mine\"" "$f" && ! grep -q "$other" "$f"; then pass
  else fail "第 $n 次调用的脚本应只提到 $mine"; fi
}

# 每个 tell application "X" 之前必须有 if application "X" is running then
expect_running_before_tell() {
  local n="$1" f="$OSA_DIR/script.$1" app run tell
  if [[ ! -f "$f" ]]; then fail "第 $n 次调用没有脚本"; return; fi
  for app in "Google Chrome" Safari; do
    tell=$(grep -n "tell application \"$app\"" "$f" | cut -d: -f1 || true)
    [[ -z "$tell" ]] && continue
    run=$(grep -n "if application \"$app\" is running then" "$f" | head -n 1 | cut -d: -f1 || true)
    if [[ -n "$run" ]] && [[ "$run" -lt "$(echo "$tell" | head -n 1)" ]] && [[ "$(echo "$tell" | wc -l)" -eq 1 ]]; then pass
    else fail "第 $n 次调用：tell application \"$app\" 前应有且仅有一处在其前的 is running 判断"; fi
  done
}

echo "[Chrome 刷新成功 → 输出 reloaded，osascript 只调 1 次，不调 open]"
run_script reloaded reloaded "$PROTO"
expect_eq "$OUT" "reloaded" "输出"
expect_eq "$CODE" "0" "退出码"
expect_eq "$(osa_calls)" "1" "osascript 调用次数"
expect_eq "$(open_calls)" "0" "open 调用次数"
expect_only_browser 1 Chrome

echo "[Chrome notfound、Safari 刷新成功 → 输出 reloaded，osascript 调 2 次，不调 open]"
run_script notfound reloaded "$PROTO"
expect_eq "$OUT" "reloaded" "输出"
expect_eq "$(osa_calls)" "2" "osascript 调用次数"
expect_eq "$(open_calls)" "0" "open 调用次数"
expect_only_browser 1 Chrome
expect_only_browser 2 Safari

echo "[Chrome 调用以 1 退出、Safari 刷新成功 → 输出 reloaded，不调 open]"
run_script error reloaded "$PROTO"
expect_eq "$OUT" "reloaded" "输出"
expect_eq "$CODE" "0" "退出码"
expect_eq "$(osa_calls)" "2" "osascript 调用次数"
expect_eq "$(open_calls)" "0" "open 调用次数"

echo "[两次都 notfound → 输出 opened，open 调 1 次]"
run_script notfound notfound "$PROTO"
expect_eq "$OUT" "opened" "输出"
expect_eq "$CODE" "0" "退出码"
expect_eq "$(osa_calls)" "2" "osascript 调用次数"
expect_eq "$(open_calls)" "1" "open 调用次数"
expect_eq "$(grep -v '^CALL$' "$OPEN_LOG")" "$PROTO" "open 参数"

echo "[两次都以 1 退出 → 输出 opened，退出码 0，open 调 1 次]"
run_script error error "$PROTO"
expect_eq "$OUT" "opened" "输出"
expect_eq "$CODE" "0" "退出码"
expect_eq "$(osa_calls)" "2" "osascript 调用次数"
expect_eq "$(open_calls)" "1" "open 调用次数"

echo "[每次调用的最后一个参数都是物理路径的 file:// 地址]"
run_script notfound reloaded "$PROTO"
want="file://$FIXROOT/a%20b/%E5%8E%9F%E5%9E%8B.html"
expect_eq "$(last_arg 1)" "$want" "第 1 次，带空格和中文的路径"
expect_eq "$(last_arg 2)" "$want" "第 2 次，带空格和中文的路径"
run_script reloaded reloaded "$PLAIN"
expect_eq "$(last_arg 1)" "file://$FIXROOT/plain.html" "普通路径"

echo "[符号链接路径被解开]"
ln -s "$FIXROOT/a b" "$FIXROOT/link"
run_script reloaded reloaded "$FIXROOT/link/原型.html"
expect_eq "$(last_arg 1)" "$want" "符号链接目录"

echo "[保留字符原样，其余字节转大写 %XX]"
SAFE="$FIXROOT/x(1)!,+=@&;'.html"
echo '<html></html>' > "$SAFE"
run_script reloaded reloaded "$SAFE"
expect_eq "$(last_arg 1)" "file://$FIXROOT/x(1)!,+=@&%3B'.html" "保留字符与分号"
MIXED="$FIXROOT/"'y$*:#%[].html'
echo '<html></html>' > "$MIXED"
run_script reloaded reloaded "$MIXED"
expect_eq "$(last_arg 1)" "file://$FIXROOT/"'y$*:%23%25%5B%5D.html' "# % [ ] 转义"

echo "[导出 CDPATH 时相对路径的地址与不设 CDPATH 相同]"
mkdir -p "$FIXROOT/cd/sub"
echo '<html></html>' > "$FIXROOT/cd/sub/p.html"
rm -rf "$OSA_DIR"; mkdir -p "$OSA_DIR"; : > "$OPEN_LOG"
(cd "$FIXROOT/cd" && CDPATH=".:/tmp" OSA_CHROME=reloaded PATH="$BIN:$PATH" bash "$SCRIPT" sub/p.html >/dev/null 2>&1) || true
expect_eq "$(last_arg 1)" "file://$FIXROOT/cd/sub/p.html" "CDPATH 下相对路径"

echo '[文件名含特殊字符 { } ^ 反引号 | 双引号 < > → 转成大写 %XX]'
SPECIAL="$FIXROOT/"'y{}^`|"<>.html'
echo '<html></html>' > "$SPECIAL"
run_script reloaded reloaded "$SPECIAL"
expect_eq "$(last_arg 1)" "file://$FIXROOT/"'y%7B%7D%5E%60%7C%22%3C%3E.html' "特殊字符转义"

echo "[参数错误 → 退出码非 0，stderr 有说明，不调用 osascript 和 open]"
run_script reloaded reloaded
if [[ "$CODE" -ne 0 ]]; then pass; else fail "不带参数：退出码应非 0"; fi
if [[ -n "$ERR" ]]; then pass; else fail "不带参数：stderr 应有说明"; fi
expect_eq "$(osa_calls)" "0" "不带参数 osascript 调用次数"
expect_eq "$(open_calls)" "0" "不带参数 open 调用次数"
run_script reloaded reloaded "$FIXROOT/不存在.html"
if [[ "$CODE" -ne 0 ]]; then pass; else fail "文件不存在：退出码应非 0"; fi
if [[ -n "$ERR" ]]; then pass; else fail "文件不存在：stderr 应有说明"; fi
expect_eq "$(osa_calls)" "0" "文件不存在 osascript 调用次数"
expect_eq "$(open_calls)" "0" "文件不存在 open 调用次数"

echo "[每段脚本里 tell application 都在对应的 is running 判断之后]"
run_script notfound notfound "$PROTO"
expect_running_before_tell 1
expect_running_before_tell 2

echo "通过 ${PASS}，失败 ${FAIL}"
[[ "$FAIL" -eq 0 ]]
