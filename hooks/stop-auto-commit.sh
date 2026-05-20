#!/usr/bin/env bash
# Stop hook：任务结束前在 Stop hook 链路最后，把"用语义化 message 自己 commit"的任务交还给 AI。
# 设计原则：
#   - hook 不再自己 commit。Shell 脚本看不懂 diff 语义，只能拼"时间戳 + stat"模板，
#     缺少"做了什么 / 为什么"的信息——commit 历史价值约等于零。
#     只有 AI 清楚本轮改动的意图，由 AI 写 message 才是合适的。
#   - 只 commit，不 push（符合 git-workflow-discipline："阶段性 commit 仅本地保存"）。
#   - 提示 AI 用 `git add -u`：仅暂存已追踪文件的修改 / 删除；untracked 由 AI 判断是否纳入。
#   - 不在 main / master / detached HEAD 上触发（与 block-main-commit.sh 保持一致）。
# 触发条件：
#   - 单仓：cwd 在某个 git 工作树内 —— 沿用原行为。
#   - 多仓兜底：cwd 不在任何 git 工作树内，但**显式启用**后扫 cwd 一级子目录里的独立
#     仓库（聚合工作区 + 每个子目录是独立 git 仓的场景）。兜底前先校验启用开关，
#     避免对非 git 工作区误扫。
# 防循环：依赖 stop_hook_active；二次触发直接放行（AI 已收过指令，无论是否 commit 都不再回灌）。
# 启用开关：默认不跑，必须显式启用——满足其一即可：
#   - 环境变量 CLAUDE_ENABLE_AUTO_COMMIT=1（全局开，所有发现的仓库都触发）；
#   - cwd 存在 .enable-auto-commit 标记（工作区全开）；
#   - 仓库根存在 .enable-auto-commit 标记（仅该仓库开）。
#   注：兜底扫描本身要求"全局开"或"cwd 标记开"，否则连扫都不扫。
# 输入：标准 Stop stdin JSON（含 cwd 字段，fallback 到 $PWD）。
# 输出：满足条件 → decision:block + 让 AI 自己写 message 并 commit 的指令；否则静默 exit 0。

set -uo pipefail

# ---- 依赖检查 ----------------------------------------------------------------
command -v jq &>/dev/null || exit 0
command -v git &>/dev/null || exit 0

# ---- 输入解析 ----------------------------------------------------------------
INPUT=$(cat)
ACTIVE=$(jq -r '.stop_hook_active // false' <<<"$INPUT")
if [ "$ACTIVE" = "true" ]; then
  # 上一轮 Stop 已经触发过本提示；本轮放行，避免死循环。
  exit 0
fi

HOOK_CWD=$(jq -r '.cwd // empty' <<<"$INPUT")
[ -z "$HOOK_CWD" ] && HOOK_CWD="$PWD"

cd "$HOOK_CWD" 2>/dev/null || exit 0

# ---- 仓库根定位辅助函数 ------------------------------------------------------
# 扫一级子目录，每个含 .git（目录或文件形式：worktree / submodule）的子目录视为独立仓。
scan_subdir_repos() {
  local cwd="$1"
  local saved
  saved=$(shopt -p nullglob)
  shopt -s nullglob
  local dir base r
  for dir in "$cwd"/*/; do
    base=$(basename "$dir")
    case "$base" in .*|vendor|node_modules) continue ;; esac
    [ -e "$dir/.git" ] || continue
    r=$(cd "$dir" && git rev-parse --show-toplevel 2>/dev/null) || continue
    printf '%s\n' "$r"
  done
  eval "$saved"
}

# ---- 仓库收集 ----------------------------------------------------------------
REPOS=()

if git rev-parse --is-inside-work-tree &>/dev/null; then
  # 路径 1：原"单仓"行为
  ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
  [ -n "${ROOT:-}" ] && REPOS=( "$ROOT" )
else
  # 路径 2：兜底扫子仓——必须 cwd 级显式启用，避免对非 git 工作区误触发。
  if [ "${CLAUDE_ENABLE_AUTO_COMMIT:-0}" = "1" ] || [ -f "$HOOK_CWD/.enable-auto-commit" ]; then
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      REPOS+=( "$line" )
    done < <(scan_subdir_repos "$HOOK_CWD")
  fi
fi

[ "${#REPOS[@]}" -eq 0 ] && exit 0

# ---- 按启用开关过滤仓库 -----------------------------------------------------
ENABLED_REPOS=()
for r in "${REPOS[@]}"; do
  if [ "${CLAUDE_ENABLE_AUTO_COMMIT:-0}" = "1" ] \
    || [ -f "$HOOK_CWD/.enable-auto-commit" ] \
    || [ -f "$r/.enable-auto-commit" ]; then
    ENABLED_REPOS+=( "$r" )
  fi
done
[ "${#ENABLED_REPOS[@]}" -eq 0 ] && exit 0

# ---- 逐仓收集待提交信息 -----------------------------------------------------
# 跳过：main / master / detached HEAD 分支；无已追踪文件变更的仓库。
ENTRIES=()
for repo in "${ENABLED_REPOS[@]}"; do
  cd "$repo" || continue
  BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || continue
  case "$BRANCH" in
    main|master|HEAD)
      # main / master：与 block-main-commit.sh 一致，不动。
      # HEAD：detached，不安全 commit。
      continue
      ;;
  esac
  # 没有已追踪文件变更则跳过
  if git diff --quiet HEAD -- 2>/dev/null; then
    continue
  fi

  FILES_LIST=$(git diff --name-status HEAD 2>/dev/null | head -40)
  SHORTSTAT=$(git diff --shortstat HEAD 2>/dev/null | sed 's/^ *//')

  entry=$(cat <<EOF
- 仓库：\`$repo\`
  分支：\`$BRANCH\`
  变更摘要：$SHORTSTAT
  变更文件（最多 40 行 name-status）：
  \`\`\`
$FILES_LIST
  \`\`\`
EOF
)
  ENTRIES+=( "$entry" )
done

[ "${#ENTRIES[@]}" -eq 0 ] && exit 0

# 拼接所有 entries
ENTRIES_BLOCK=""
for e in "${ENTRIES[@]}"; do
  ENTRIES_BLOCK="${ENTRIES_BLOCK}${e}

"
done

# ---- 回灌指令：让 AI 自己写 message 并 commit ----------------------------------
REASON=$(cat <<EOF
任务结束前检测到以下仓库有**已追踪文件**的改动尚未 commit。请你**亲自**用语义化 commit message 把改动逐一提交到本地（不要 push）。

要求：

1. **message 必须如实反映本次改动的"做了什么 + 为什么"**。严禁 \`chore: auto-commit by claude code @ 时间戳\`、\`files changed: N\` 这类纯机械模板——commit 历史的价值在于语义，不在于元数据。
2. 沿用各仓库自身的 commit 规范：先看 \`git log --oneline -n 20\`，模仿现有风格（前缀、语种、句式）。若无明确规范，遵循 Conventional Commits（\`feat:\` / \`fix:\` / \`refactor:\` / \`docs:\` / \`test:\` / \`chore:\` 等），标题用中文，正文按需要展开"为什么"。
3. **暂存策略**：默认 \`git add -u\`（仅已追踪文件的修改 / 删除）。untracked 文件由你判断是否纳入；纳入前再三确认不是临时产物 / 测试输出 / 缓存 / 编辑器 swap 文件。
4. **commit 前自己再跑一遍 \`git diff --cached\` 复核**，确认 staged 内容确实就是你要表达的语义。
5. 多个仓库逐一独立 commit；本地 commit，**不要 push**（推送走 \`/git-push-pr\`）。
6. 完成后正常结束本轮即可——下一次 Stop 不会再触发本提示（防循环）。
7. 如果某个仓库的改动**不该** commit（改动尚未到一个合理的语义阶段、应该拆成多个 commit、或包含调试残留待清理），直接说明理由并跳过该仓，不要硬塞 commit。

待处理仓库（cwd=\`$HOOK_CWD\`）：

$ENTRIES_BLOCK
EOF
)

jq -nc --arg reason "$REASON" '{
  "decision": "block",
  "reason": $reason
}'
