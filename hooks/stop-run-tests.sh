#!/usr/bin/env bash
# Stop hook：任务结束前在 Go 项目根目录跑一遍全套测试（vet / lint / test / integration）。
# 触发条件：cwd（或其祖先）存在 go.mod。否则静默放行。
# 防循环：依赖 stop_hook_active；二次触发直接放行，避免修测试 → 触发 → 再修死循环。
# 启用开关：默认不跑，必须显式启用——环境变量 CLAUDE_ENABLE_STOP_TESTS=1，
#           或项目根存在 .enable-stop-tests 标记文件，二者满足其一即可。
# 输入：标准 Stop stdin JSON（含 cwd 字段，fallback 到 $PWD）。
# 输出：失败 → decision:block + 失败摘要交还给 AI；通过 → 静默 exit 0。

set -uo pipefail

# ---- 依赖检查 ----------------------------------------------------------------
if ! command -v jq &>/dev/null; then
  exit 0
fi
if ! command -v go &>/dev/null; then
  exit 0
fi

# ---- 输入解析 ----------------------------------------------------------------
INPUT=$(cat)
ACTIVE=$(jq -r '.stop_hook_active // false' <<<"$INPUT")
if [ "$ACTIVE" = "true" ]; then
  # 上一轮已经触发过测试自检；本轮放行，避免死循环。
  exit 0
fi

HOOK_CWD=$(jq -r '.cwd // empty' <<<"$INPUT")
[ -z "$HOOK_CWD" ] && HOOK_CWD="$PWD"

# ---- 项目根定位：向上找最近的 go.mod -----------------------------------------
find_module_root() {
  local dir="$1"
  while [ "$dir" != "/" ] && [ -n "$dir" ]; do
    if [ -f "$dir/go.mod" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

MOD_ROOT=$(find_module_root "$HOOK_CWD") || exit 0

# ---- 启用开关 ----------------------------------------------------------------
# 默认关。必须显式启用，避免在不期望测试自动跑的项目里炸出意外开销。
if [ "${CLAUDE_ENABLE_STOP_TESTS:-0}" != "1" ] && [ ! -f "$MOD_ROOT/.enable-stop-tests" ]; then
  exit 0
fi

cd "$MOD_ROOT" || exit 0

# ---- 工具命令探测 ------------------------------------------------------------
# timeout 在 macOS 默认没有，brew 装的可能叫 gtimeout；都没有就裸跑。
TIMEOUT_BIN=""
if command -v timeout &>/dev/null; then
  TIMEOUT_BIN="timeout"
elif command -v gtimeout &>/dev/null; then
  TIMEOUT_BIN="gtimeout"
fi
run_with_timeout() {
  # 用法：run_with_timeout <秒> <cmd...>
  local secs="$1"; shift
  if [ -n "$TIMEOUT_BIN" ]; then
    "$TIMEOUT_BIN" "$secs" "$@"
  else
    "$@"
  fi
}

# ---- 测试执行 ----------------------------------------------------------------
FAILED_STAGES=()
LOG_FILE=$(mktemp -t stop-run-tests.XXXXXX.log)
trap 'rm -f "$LOG_FILE"' EXIT

run_stage() {
  # 用法：run_stage <阶段名> <超时秒> <命令...>
  local name="$1"; local secs="$2"; shift 2
  {
    printf '\n========== [%s] $ %s ==========\n' "$name" "$*"
    run_with_timeout "$secs" "$@" 2>&1
    local rc=$?
    if [ "$rc" -ne 0 ]; then
      printf '========== [%s] FAILED (rc=%d) ==========\n' "$name" "$rc"
      FAILED_STAGES+=("$name")
    else
      printf '========== [%s] OK ==========\n' "$name"
    fi
  } >>"$LOG_FILE"
}

# 1) go vet
run_stage "go vet" 120 go vet ./...

# 2) golangci-lint（若安装）
if command -v golangci-lint &>/dev/null; then
  run_stage "golangci-lint" 300 golangci-lint run ./...
fi

# 3) go test（含 -race，覆盖单元测试）
run_stage "go test" 600 go test -race -count=1 ./...

# 4) Makefile 自定义集成测试 target（若存在）
if [ -f "Makefile" ] || [ -f "makefile" ]; then
  if make -n test-integration &>/dev/null; then
    run_stage "make test-integration" 900 make test-integration
  fi
fi

# ---- 结果反馈 ----------------------------------------------------------------
if [ ${#FAILED_STAGES[@]} -eq 0 ]; then
  # 全通过：静默放行
  exit 0
fi

# 失败：截取日志尾部（避免输出过大），交还给 AI 处理
MAX_BYTES=8000
LOG_TAIL=$(tail -c "$MAX_BYTES" "$LOG_FILE")
FAILED_LIST=$(printf '  - %s\n' "${FAILED_STAGES[@]}")

REASON=$(cat <<EOF
任务结束前自动跑了 Go 项目全套测试，**以下阶段失败，必须修复后才能停下**：

$FAILED_LIST

项目根：$MOD_ROOT
失败日志（尾部 ${MAX_BYTES} 字节）：

\`\`\`
$LOG_TAIL
\`\`\`

请按 TDD 纪律先修测试再动实现（或修实现让测试通过），改完后这一轮 stop hook 不会再触发（防循环），但下次任务结束会再次校验。如果你判断这些失败与本次任务无关、属于历史遗留，请显式告知用户并征求是否**临时停用**本 hook（删除项目根 .enable-stop-tests 文件，或 \`unset CLAUDE_ENABLE_STOP_TESTS\`）。
EOF
)

jq -nc --arg reason "$REASON" '{
  "decision": "block",
  "reason": $reason
}'
