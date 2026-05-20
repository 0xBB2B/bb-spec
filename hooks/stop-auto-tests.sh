#!/usr/bin/env bash
# Stop hook：任务结束前在 Go 项目根目录跑一遍全套测试（vet / lint / test / integration）。
# 触发条件：
#   - 单模块：cwd（或其祖先）存在 go.mod —— 沿用原行为。
#   - 多模块兜底：cwd 不在任何 Go 模块内，但**显式启用**后：
#       1) 优先解析 cwd/go.work 的 Use 列表（聚合工作区场景）；
#       2) 否则扫 cwd 一级子目录里含 go.mod 的目录（每个子目录是独立 Go 仓的场景）。
#     兜底前先校验启用开关，避免对非 Go 项目误扫到无关模块。
# 防循环：依赖 stop_hook_active；二次触发直接放行，避免修测试 → 触发 → 再修死循环。
# 启用开关：默认不跑，必须显式启用——满足其一即可：
#   - 环境变量 CLAUDE_ENABLE_AUTO_TESTS=1（全局开，所有发现的模块都跑）；
#   - cwd 存在 .enable-auto-tests 标记（工作区全开，所有发现的模块都跑）；
#   - 任一模块根存在 .enable-auto-tests（仅该模块开）。
#   注：兜底扫描（路径 2 / 3）本身要求"全局开"或"cwd 标记开"，否则连扫都不扫。
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

# ---- 模块根定位辅助函数 ------------------------------------------------------

# 路径 1：从给定目录向上找最近的 go.mod。失败返回 1，成功打印目录。
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

# 路径 2：解析 cwd/go.work 的 Use 列表，输出每个 use 模块的绝对路径。
#         需要 Go 1.18+。无 go.work 或解析失败时返回 1。
collect_via_goworkfile() {
  local cwd="$1"
  [ -f "$cwd/go.work" ] || return 1
  local json
  json=$(cd "$cwd" && go work edit -json 2>/dev/null) || return 1
  [ -z "$json" ] && return 1
  local relpath abs any=0
  while IFS= read -r relpath; do
    [ -z "$relpath" ] && continue
    if [[ "$relpath" = /* ]]; then
      abs="$relpath"
    else
      abs=$(cd "$cwd/$relpath" 2>/dev/null && pwd)
    fi
    if [ -n "$abs" ] && [ -f "$abs/go.mod" ]; then
      printf '%s\n' "$abs"
      any=1
    fi
  done < <(jq -r '.Use[]?.DiskPath // empty' <<<"$json")
  [ "$any" -eq 1 ] && return 0
  return 1
}

# 路径 3：扫描 cwd 一级子目录里直接含 go.mod 的目录。深度仅 1，避免误扫
#         vendor / examples 等次级目录。无匹配返回 1。
collect_via_dirscan() {
  local cwd="$1"
  local saved
  saved=$(shopt -p nullglob)
  shopt -s nullglob
  local dir base any=0
  for dir in "$cwd"/*/; do
    base=$(basename "$dir")
    case "$base" in .*|vendor|node_modules) continue ;; esac
    if [ -f "$dir/go.mod" ]; then
      printf '%s\n' "${dir%/}"
      any=1
    fi
  done
  eval "$saved"
  [ "$any" -eq 1 ] && return 0
  return 1
}

# ---- 模块根收集 --------------------------------------------------------------
MOD_ROOTS=()

SINGLE_ROOT=$(find_module_root "$HOOK_CWD" || true)
if [ -n "${SINGLE_ROOT:-}" ]; then
  # 路径 1：原"单模块"行为
  MOD_ROOTS=( "$SINGLE_ROOT" )
else
  # 路径 2 / 3 是兜底扫描，可能找到与本任务无关的 Go 项目。
  # 必须 cwd 级显式启用（环境变量 or cwd 标记文件）才扫，避免在非 Go 工作区里误触发。
  GLOBAL_ON=0
  if [ "${CLAUDE_ENABLE_AUTO_TESTS:-0}" = "1" ] || [ -f "$HOOK_CWD/.enable-auto-tests" ]; then
    GLOBAL_ON=1
  fi
  if [ "$GLOBAL_ON" = "1" ]; then
    # 优先 go.work
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      MOD_ROOTS+=( "$line" )
    done < <(collect_via_goworkfile "$HOOK_CWD")
    # 没解析出来 / 不是 workspace → 扫一级子目录
    if [ "${#MOD_ROOTS[@]}" -eq 0 ]; then
      while IFS= read -r line; do
        [ -z "$line" ] && continue
        MOD_ROOTS+=( "$line" )
      done < <(collect_via_dirscan "$HOOK_CWD")
    fi
  fi
fi

[ "${#MOD_ROOTS[@]}" -eq 0 ] && exit 0

# ---- 按启用开关过滤模块 -----------------------------------------------------
# 单模块场景下保留对模块根 .enable-auto-tests 的兼容；多模块场景下，cwd 标记 / 环境
# 变量统一开关，单模块根的 .enable-auto-tests 仅对该模块生效。
ENABLED_ROOTS=()
for r in "${MOD_ROOTS[@]}"; do
  if [ "${CLAUDE_ENABLE_AUTO_TESTS:-0}" = "1" ] \
    || [ -f "$HOOK_CWD/.enable-auto-tests" ] \
    || [ -f "$r/.enable-auto-tests" ]; then
    ENABLED_ROOTS+=( "$r" )
  fi
done

[ "${#ENABLED_ROOTS[@]}" -eq 0 ] && exit 0

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
LOG_FILE=$(mktemp -t stop-auto-tests.XXXXXX.log)
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

for MOD_ROOT in "${ENABLED_ROOTS[@]}"; do
  cd "$MOD_ROOT" || continue
  MOD_NAME=$(basename "$MOD_ROOT")

  # 1) go vet
  run_stage "$MOD_NAME · go vet" 120 go vet ./...

  # 2) golangci-lint（若安装）
  if command -v golangci-lint &>/dev/null; then
    run_stage "$MOD_NAME · golangci-lint" 300 golangci-lint run ./...
  fi

  # 3) go test（含 -race，覆盖单元测试）
  run_stage "$MOD_NAME · go test" 600 go test -race -count=1 ./...

  # 4) Makefile 自定义集成测试 target（若存在）
  if [ -f "Makefile" ] || [ -f "makefile" ]; then
    if make -n test-integration &>/dev/null; then
      run_stage "$MOD_NAME · make test-integration" 900 make test-integration
    fi
  fi
done

# ---- 结果反馈 ----------------------------------------------------------------
if [ ${#FAILED_STAGES[@]} -eq 0 ]; then
  # 全通过：静默放行
  exit 0
fi

# 失败：截取日志尾部（避免输出过大），交还给 AI 处理
MAX_BYTES=8000
LOG_TAIL=$(tail -c "$MAX_BYTES" "$LOG_FILE")
FAILED_LIST=$(printf '  - %s\n' "${FAILED_STAGES[@]}")
ROOTS_LIST=$(printf '  - %s\n' "${ENABLED_ROOTS[@]}")

REASON=$(cat <<EOF
任务结束前自动跑了 Go 项目全套测试，**以下阶段失败，必须修复后才能停下**：

$FAILED_LIST

涉及的模块根（cwd=\`$HOOK_CWD\`）：

$ROOTS_LIST

失败日志（尾部 ${MAX_BYTES} 字节）：

\`\`\`
$LOG_TAIL
\`\`\`

请按 TDD 纪律先修测试再动实现（或修实现让测试通过），改完后这一轮 stop hook 不会再触发（防循环），但下次任务结束会再次校验。如果你判断这些失败与本次任务无关、属于历史遗留，请显式告知用户并征求是否**临时停用**本 hook（删除对应模块根的 .enable-auto-tests 文件、或工作区根的 .enable-auto-tests，或 \`unset CLAUDE_ENABLE_AUTO_TESTS\`）。
EOF
)

jq -nc --arg reason "$REASON" '{
  "decision": "block",
  "reason": $reason
}'
