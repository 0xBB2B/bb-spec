#!/usr/bin/env bash
# background-script-wait.sh 行为校验：新命令提示、去重、截断、异常静默放行
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$ROOT/plugins/bb-spec-core/hooks/background-script-wait.sh"
HOOKS_JSON="$ROOT/plugins/bb-spec-core/hooks/hooks.json"
BASH_BIN="$(command -v bash)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

WORKDIR="$TMP/cwd"
mkdir -p "$WORKDIR"
DATA=""
OUT=""
RC=0

new_data() {
  DATA="$(mktemp -d "$TMP/data.XXXXXX")"
}

run() {
  OUT=""
  RC=0
  OUT="$(cd "$WORKDIR" && printf '%s' "$1" | CLAUDE_PLUGIN_DATA="$DATA" "$BASH_BIN" "$HOOK" 2>/dev/null)" || RC=$?
}

task() { jq -nc --arg id "$1" --arg type "$2" --arg status "$3" --arg cmd "$4" '{id:$id,type:$type,status:$status,command:$cmd}'; }
tj() { local IFS=,; printf '[%s]' "$*"; }
mkin() { jq -nc --arg s "$1" --argjson t "$2" '{session_id:$s,background_tasks:$t}'; }

rep() {
  local s="" i
  for ((i = 0; i < $2; i++)); do s+="$1"; done
  printf '%s' "$s"
}

expected() {
  printf '后台命令还在运行：\n'
  local l
  for l in "$@"; do printf '%s\n' "$l"; done
  printf '会自己结束的脚本（测试、构建、审查）：用前台 Bash 循环等它结束，每次最多等 2 分钟，没结束就再等一次，看完结果再结束回合。\n'
  printf '常驻服务（dev server、watch、tail -f）：不用等。全部是常驻服务时，直接结束回合。\n'
}

ctx_of() { jq -r '.hookSpecificOutput.additionalContext // empty' <<<"$OUT" 2>/dev/null || true; }

assert_empty() {
  if [[ -z "$OUT" && "$RC" -eq 0 ]]; then pass; else fail "${1}（退出码=$RC 输出=${OUT:0:80}）"; fi
}

assert_ctx() {
  local name="$1" want actual
  want="$(expected "${@:2}")"
  actual="$(ctx_of)"
  if [[ "$RC" -eq 0 && "$actual" == "$want" ]]; then pass; else fail "${name}（退出码=$RC 实际=${actual:0:120}）"; fi
}

echo "[一条新命令]"
new_data
run "$(mkin s1 "$(tj "$(task t1 shell running 'npm test')")")"
assert_ctx "一条新命令提示文本逐字一致" "- t1: npm test"
if [[ "$(jq -r '.hookSpecificOutput.hookEventName // empty' <<<"$OUT" 2>/dev/null || true)" == "Stop" ]]; then pass; else fail "hookEventName 应为 Stop"; fi
if jq -e 'has("decision") | not' <<<"$OUT" >/dev/null 2>&1; then pass; else fail "不应带 decision 字段"; fi

echo "[两条新命令]"
new_data
run "$(mkin s1 "$(tj "$(task t1 shell running 'make a')" "$(task t2 shell running 'make b')")")"
assert_ctx "两条新命令各占一行" "- t1: make a" "- t2: make b"

echo "[去重]"
new_data
IN="$(mkin s1 "$(tj "$(task t1 shell running 'npm test')")")"
run "$IN"
run "$IN"
assert_empty "同会话同编号第二次应无输出"

new_data
run "$(mkin s1 "$(tj "$(task A shell running 'cmd a')")")"
run "$(mkin s1 "$(tj "$(task A shell running 'cmd a')" "$(task B shell running 'cmd b')")")"
assert_ctx "新旧混合只列新的" "- B: cmd b"
run "$(mkin s1 "$(tj "$(task A shell running 'cmd a')" "$(task B shell running 'cmd b')")")"
assert_empty "新的也被记下后再输入应无输出"

new_data
run "$(mkin s1 "$(tj "$(task A shell running 'cmd a')")")"
run "$(mkin s2 "$(tj "$(task A shell running 'cmd a')")")"
assert_ctx "不同会话记录互不影响" "- A: cmd a"

echo "[不算新命令的输入]"
new_data
run "$(mkin s1 '[]')"
assert_empty "空列表应无输出"
run '{"session_id":"s1"}'
assert_empty "缺 background_tasks 应无输出"
run "$(mkin s1 "$(tj "$(task t1 subagent running 'x')")")"
assert_empty "subagent 类型应无输出"
run "$(mkin s1 "$(tj "$(task t1 monitor running 'x')")")"
assert_empty "monitor 类型应无输出"
run "$(mkin s1 "$(tj "$(task t1 shell completed 'x')")")"
assert_empty "completed 状态应无输出"
run "$(mkin s1 "$(tj '{"id":"t1","type":"shell","command":"x"}')")"
assert_empty "缺 status 字段应无输出"
run "$(mkin s1 "$(tj '{"type":"shell","status":"running","command":"x"}')")"
assert_empty "缺 id 字段应无输出"
run "$(mkin s2 "$(tj '{"id":"t1","type":"shell","status":"running"}')")"
assert_empty "缺 command 字段应无输出"

new_data
run "$(mkin s3 "$(tj "$(task good shell running 'npm test')" '{"id":"bad","type":"shell","status":"running","command":123}')")"
assert_ctx "command 不是字符串时只跳过这一条" "- good: npm test"

new_data
run "$(mkin s9 "$(tj "$(task t1 subagent running 'x')" "$(task t2 shell running 'real')" "$(task t3 shell completed 'done')")")"
assert_ctx "混合类型只列 shell 且 running" "- t2: real"

echo "[命令显示]"
new_data
run "$(mkin c1 "$(tj "$(task t1 shell running "$(rep a 81)")")")"
assert_ctx "81 个字符截成前 80 个加省略号" "- t1: $(rep a 80)…"
run "$(mkin c1 "$(tj "$(task t2 shell running "$(rep a 80)")")")"
assert_ctx "80 个字符完整显示" "- t2: $(rep a 80)"
run "$(mkin c1 "$(tj "$(task t3 shell running $'a\nb')")")"
assert_ctx "换行显示成空格" "- t3: a b"
run "$(mkin c1 "$(tj "$(task t4 shell running "$(rep x 39)"$'\n'"$(rep y 40)")")")"
assert_ctx "含换行恰好 80 个字符完整显示" "- t4: $(rep x 39) $(rep y 40)"
run "$(mkin c1 "$(tj "$(task t5 shell running "$(rep x 79)"$'\n'"yy")")")"
assert_ctx "换行先换空格再截断" "- t5: $(rep x 79) …"
run "$(mkin c1 "$(tj "$(task t6 shell running "$(rep 中 81)")")")"
assert_ctx "中文按字符数截断" "- t6: $(rep 中 80)…"
run "$(mkin c1 "$(tj "$(task t7 shell running "$(rep 中 80)")")")"
assert_ctx "80 个中文字符完整显示" "- t7: $(rep 中 80)"

echo "[命令不被执行]"
new_data
BT='`touch injected-mark`'
CMD="echo \$(touch injected-mark) $BT"
run "$(mkin i1 "$(tj "$(task t1 shell running "$CMD")")")"
assert_ctx "命令里的替换语法原样显示" "- t1: $CMD"
if [[ ! -e "$WORKDIR/injected-mark" ]]; then pass; else fail "命令里的 \$(touch) 被执行了"; fi

echo "[非法输入静默放行]"
BASE9="$TMP/c9"
DATA="$BASE9/data"
mkdir -p "$DATA"
TASKS="$(tj "$(task t1 shell running 'x')")"
run 'not json {'
assert_empty "非法 JSON 应无输出"
run "$(jq -nc --argjson t "$TASKS" '{background_tasks:$t}')"
assert_empty "缺 session_id 应无输出"
run "$(mkin '../x' "$TASKS")"
assert_empty "session_id 为 ../x 应无输出"
run "$(mkin 'a/b' "$TASKS")"
assert_empty "session_id 为 a/b 应无输出"
run "$(mkin '..' "$TASKS")"
assert_empty "session_id 为 .. 应无输出"
OUTSIDE="$(find "$BASE9" -type f 2>/dev/null || true)"
if [[ -z "$OUTSIDE" ]]; then pass; else fail "非法输入不应写任何文件：$OUTSIDE"; fi

echo "[没有 jq]"
NOJQ="$TMP/nojq-bin"
mkdir -p "$NOJQ"
for t in cat mkdir grep sed tr cut head tail printf date dirname basename touch rm mv ls wc sort awk env sh mktemp tee cp find; do
  p="$(command -v "$t" 2>/dev/null || true)"
  if [[ -n "$p" && "$p" == /* ]]; then ln -sf "$p" "$NOJQ/$t"; fi
done
new_data
OUT=""
RC=0
OUT="$(cd "$WORKDIR" && printf '%s' "$(mkin s1 "$TASKS")" | PATH="$NOJQ" CLAUDE_PLUGIN_DATA="$DATA" "$BASH_BIN" "$HOOK" 2>/dev/null)" || RC=$?
assert_empty "PATH 里没有 jq 应无输出"

echo "[记录写不进去]"
IN="$(mkin s1 "$TASKS")"
DATA=""
run "$IN"
assert_empty "CLAUDE_PLUGIN_DATA 为空应无输出"
run "$IN"
assert_empty "CLAUDE_PLUGIN_DATA 为空再调一次仍无输出"

: >"$TMP/plainfile"
DATA="$TMP/plainfile/sub"
run "$IN"
assert_empty "数据目录是普通文件的子路径应无输出"
run "$IN"
assert_empty "不可写时再调一次仍无输出"

new_data
run "$(mkin s1 "$(tj "$(task t0 shell running 'x')")")"
RECORD="$(find "$DATA" -type f | head -1)"
rm "$RECORD"
mkdir "$RECORD"
run "$IN"
assert_empty "记录路径不能写入时应无输出"
run "$IN"
assert_empty "记录路径不能写入时再调一次仍无输出"

echo "[不污染当前目录]"
new_data
CLEANCWD="$TMP/cleancwd"
mkdir -p "$CLEANCWD"
WORKDIR="$CLEANCWD"
run "$IN"
DATA=""
run "$IN"
WORKDIR="$TMP/cwd"
if [[ -z "$(find "$CLEANCWD" -mindepth 1 2>/dev/null)" ]]; then pass; else fail "当前工作目录出现了新文件"; fi

echo "[hooks.json 注册]"
if jq -e '[.hooks.Stop[]?.hooks[]?.command // empty | select(contains("background-script-wait.sh"))] | length > 0' "$HOOKS_JSON" >/dev/null 2>&1; then pass; else fail "Stop 下应注册 background-script-wait.sh"; fi
if jq -e '[.hooks.SubagentStop[]?.hooks[]?.command // empty | select(contains("background-script-wait.sh"))] | length == 0' "$HOOKS_JSON" >/dev/null 2>&1; then pass; else fail "SubagentStop 下不应注册 background-script-wait.sh"; fi

echo "[说明文档同步]"
GIT_PUSH_SKILL="$ROOT/plugins/bb-spec-workflow/skills/git-push/SKILL.md"
if grep -qF "每次前台调用最多等 2 分钟" "$GIT_PUSH_SKILL"; then pass; else fail "git-push SKILL 应写明每次前台调用最多等 2 分钟"; fi
if grep -qF "循环等 ocr 进程退出" "$GIT_PUSH_SKILL"; then pass; else fail "git-push SKILL 应等 ocr 进程退出"; fi
if grep -qF "等完成通知" "$GIT_PUSH_SKILL"; then fail "git-push SKILL 不应再靠等完成通知"; else pass; fi

for f in "$ROOT/plugins/bb-spec-core/.claude-plugin/plugin.json" "$ROOT/.claude-plugin/marketplace.json"; do
  if grep -qF "background-script-wait" "$f"; then pass; else fail "$f 应提到 background-script-wait"; fi
  if grep -qF "三个被动 hook" "$f"; then pass; else fail "$f 应写三个被动 hook"; fi
  if grep -qF "两个被动 hook" "$f"; then fail "$f 不应再写两个被动 hook"; else pass; fi
done

check_readme() {
  local file="$1" list_marker="$2" stop_item="$3" new_item="$4" total="$5" core="$6" stale_row="$7" new_row="$8"
  local list_line
  list_line="$(grep -F "$list_marker" "$ROOT/$file" | head -1)"
  if grep -q '^| `background-script-wait` |' "$ROOT/$file"; then pass; else fail "$file 钩子表应有 background-script-wait 行"; fi
  if [[ "$list_line" == *"$stop_item"* ]]; then fail "$file 被动 hook 列表仍含 Stop 自检项"; else pass; fi
  if [[ "$list_line" == *"$new_item"* ]]; then pass; else fail "$file 被动 hook 列表应含 $new_item"; fi
  if [[ "$list_line" == *"$total"* ]]; then pass; else fail "$file 被动 hook 列表数量应为 $total"; fi
  local items
  items="$(LINE="$list_line" python3 -c 'import os, re; print(len(re.split("、|, ", os.environ["LINE"].split("):", 1)[1])))')"
  if [[ "$items" == "3" ]]; then pass; else fail "$file 被动 hook 列表实际应有 3 项，现在是 $items 项"; fi
  if grep -F '**bb-spec-core**' "$ROOT/$file" | grep -qF "$core"; then pass; else fail "$file bb-spec-core 钩子数量应为 $core"; fi
  if grep -qF "$stale_row" "$ROOT/$file"; then fail "$file 开关速查仍有 Stop 自检行"; else pass; fi
  if grep -qF "$new_row" "$ROOT/$file"; then pass; else fail "$file 开关速查应有 $new_row"; fi
}
check_readme README.md "被动 hook**" "Stop 四项自检" "等后台脚本跑完" "3 个被动 hook" "3 个被动 hook" "跳过 Stop 自检" "跳过后台脚本等待提示"
check_readme README.zh-TW.md "被動 hook**" "Stop 四項自檢" "等背景腳本跑完" "3 個被動 hook" "3 個被動 hook" "跳過 Stop 自檢" "跳過背景腳本等待提示"
check_readme README.en.md "passive hooks**" "Stop four-point self-check" "wait for background scripts to finish" "3 passive hooks" "3 passive hooks" "Skip the Stop self-check" "Skip the background-script wait prompt"
check_readme README.ja.md "受動 hook**" "Stop 時の 4 項目セルフチェック" "バックグラウンドスクリプトの完了待ち" "3 つの受動 hook" "3 つの受動 hook" "Stop セルフチェックをスキップ" "バックグラウンドスクリプト待ちの通知をスキップ"
check_readme README.ko.md "수동 hook**" "Stop 시 4항목 자가 점검" "백그라운드 스크립트 완료 대기" "3개 수동 hook" "3개 수동 hook" "Stop 자가 점검 건너뛰기" "백그라운드 스크립트 대기 알림 건너뛰기"

echo ""
echo "通过 ${PASS}，失败 ${FAIL}"
[[ "$FAIL" -eq 0 ]]
