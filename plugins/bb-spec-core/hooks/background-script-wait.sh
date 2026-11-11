#!/usr/bin/env bash
# Stop：回合结束时若有第一次见到的后台 shell 命令，提示 Claude 不要循环等待。

set -uo pipefail

INPUT=$(cat)

command -v jq &>/dev/null || exit 0
[ -n "${CLAUDE_PLUGIN_DATA:-}" ] || exit 0

SID=$(jq -r '.session_id // empty' <<<"$INPUT" 2>/dev/null) || exit 0
case "$SID" in
  ''|*[!A-Za-z0-9_-]*) exit 0 ;;
esac

DIR="$CLAUDE_PLUGIN_DATA/background-script-wait"
SEEN="$DIR/$SID"
SEEN_SRC="$SEEN"
[ -f "$SEEN" ] || SEEN_SRC=/dev/null

NEW=$(jq -c --rawfile seen "$SEEN_SRC" '
  ($seen | split("\n")) as $s
  | [.background_tasks[]?
     | select(.type == "shell" and .status == "running" and (.id | type) == "string" and (.command | type) == "string")
     | select(.id as $i | $s | index($i) | not)
     | {id, command}]
' <<<"$INPUT" 2>/dev/null) || exit 0

[ "$(jq 'length' <<<"$NEW")" -gt 0 ] || exit 0

OUTPUT=$(jq -n --argjson tasks "$NEW" '
  ($tasks
   | map(.command | gsub("\n"; " ") | if length > 80 then .[:80] + "…" else . end) as $c
   | to_entries
   | map("- \(.value.id): \($c[.key])")) as $lines
  | {hookSpecificOutput: {hookEventName: "Stop", additionalContext:
      (["后台命令还在运行："] + $lines + [
        "会自己结束的脚本（测试、构建、审查）：不要循环等待，直接结束回合，它结束时系统会通知你；之后这类脚本交给跑脚本的子代理启动。",
        "常驻服务（dev server、watch、tail -f）：不用等。全部是常驻服务时，直接结束回合。"
      ] | join("\n"))}}' 2>/dev/null) || exit 0

mkdir -p "$DIR" 2>/dev/null || exit 0
jq -r '.[].id' <<<"$NEW" >>"$SEEN" 2>/dev/null || exit 0

printf '%s\n' "$OUTPUT"
exit 0
