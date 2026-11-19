#!/usr/bin/env bash
# 用法：show-prototype.sh <原型 HTML 文件>
# 浏览器（Chrome、Safari）里已开着这份原型就切过去并刷新，输出 reloaded；否则用系统默认方式打开，输出 opened
set -euo pipefail

file_url() {
  local dir path c i out=""
  dir=$(CDPATH= cd -- "$(dirname "$1")" >/dev/null && pwd -P)
  path="$dir/$(basename "$1")"
  local LC_ALL=C
  for ((i = 0; i < ${#path}; i++)); do
    c="${path:i:1}"
    case "$c" in
      [A-Za-z0-9._~/-] | [\!\$\&\'\(\)\*+,=@:]) out+="$c" ;;
      *) out+=$(printf '%%%02X' $(($(printf '%d' "'$c") & 255))) ;;
    esac
  done
  echo "file://$out"
}

# 判断 is running 必须在 tell application 之前，否则 tell 会把没开的浏览器启动起来
# Chrome 和 Safari 分两次调用：没装 Chrome 的机器上，含 active tab index、reload 的脚本编译就失败，写在一起 Safari 永远跑不到
focus_chrome() {
  osascript - "$1" <<'APPLESCRIPT'
on run argv
  set target to item 1 of argv
  if application "Google Chrome" is running then
    tell application "Google Chrome"
      repeat with w in windows
        set ti to 0
        repeat with t in tabs of w
          set ti to ti + 1
          if URL of t is target then
            set active tab index of w to ti
            set index of w to 1
            reload t
            activate
            return "reloaded"
          end if
        end repeat
      end repeat
    end tell
  end if
  return "notfound"
end run
APPLESCRIPT
}

focus_safari() {
  osascript - "$1" <<'APPLESCRIPT'
on run argv
  set target to item 1 of argv
  if application "Safari" is running then
    tell application "Safari"
      repeat with w in windows
        repeat with t in tabs of w
          if URL of t is target then
            set current tab of w to t
            set index of w to 1
            set URL of t to (URL of t)
            activate
            return "reloaded"
          end if
        end repeat
      end repeat
    end tell
  end if
  return "notfound"
end run
APPLESCRIPT
}

main() {
  if [ $# -lt 1 ] || [ ! -f "$1" ]; then
    echo "用法：show-prototype.sh <原型 HTML 文件>（文件必须存在）" >&2
    exit 1
  fi
  local url fn result=""
  url=$(file_url "$1")
  for fn in focus_chrome focus_safari; do
    result=$("$fn" "$url" 2>/dev/null) || true
    if [ "$result" = "reloaded" ]; then
      echo reloaded
      return
    fi
  done
  open "$1"
  echo opened
}

main "$@"
