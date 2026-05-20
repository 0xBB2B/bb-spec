#!/usr/bin/env bash
# Stop hook：任务结束前在 Stop hook 链路最后，把"用语义化 message 自己 commit"的任务交还给 AI。
# 设计原则：
#   - hook 不再自己 commit。Shell 脚本看不懂 diff 语义，只能拼"时间戳 + stat"模板，
#     缺少"做了什么 / 为什么"的信息——commit 历史价值约等于零。
#     只有 AI 清楚本轮改动的意图，由 AI 写 message 才是合适的。
#   - 只 commit，不 push（符合 git-workflow-discipline："阶段性 commit 仅本地保存"）。
#   - 提示 AI 用 `git add -u`：仅暂存已追踪文件的修改 / 删除；untracked 由 AI 判断是否纳入。
#   - 不在 main / master / detached HEAD 上触发（与 block-main-commit.sh 保持一致）。
# 防循环：依赖 stop_hook_active；二次触发直接放行（AI 已收过指令，无论是否 commit 都不再回灌）。
# 跳过开关：CLAUDE_SKIP_AUTO_COMMIT=1，或仓库根存在 .skip-auto-commit 标记文件。
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

# 移动到 cwd；失败则放弃。
cd "$HOOK_CWD" 2>/dev/null || exit 0

# ---- 必须在 git 仓库内 -------------------------------------------------------
git rev-parse --is-inside-work-tree &>/dev/null || exit 0

# 拿到仓库根（用于检测 .skip-auto-commit 标记 + 提示信息）。
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0

# ---- 跳过开关 ----------------------------------------------------------------
[ "${CLAUDE_SKIP_AUTO_COMMIT:-0}" = "1" ] && exit 0
[ -f "$REPO_ROOT/.skip-auto-commit" ] && exit 0

# ---- 分支保护 ----------------------------------------------------------------
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0
case "$BRANCH" in
  main|master|HEAD)
    # main / master：与 block-main-commit.sh 一致，不动。
    # HEAD：detached，不安全 commit。
    exit 0
    ;;
esac

# ---- 检查是否有可提交的"已追踪文件改动" --------------------------------------
# git diff HEAD --quiet：worktree+index 综合相对 HEAD 是否有差异。
if git diff --quiet HEAD -- 2>/dev/null; then
  # 没有已追踪文件变更，没什么好 commit 的。
  exit 0
fi

# ---- 收集摘要供 AI 参考 -------------------------------------------------------
# 文件级 name-status，限 40 行避免占用过多上下文；AI 自己会再跑 git diff 看细节。
FILES_LIST=$(git diff --name-status HEAD 2>/dev/null | head -40)
SHORTSTAT=$(git diff --shortstat HEAD 2>/dev/null | sed 's/^ *//')

# ---- 回灌指令：让 AI 自己写 message 并 commit ----------------------------------
REASON=$(cat <<EOF
任务结束前检测到当前分支（\`$BRANCH\`）有**已追踪文件**的改动尚未 commit。请你**亲自**用一条**语义化 commit message** 把这次改动提交到本地（不要 push）。

要求：

1. **message 必须如实反映本次改动的"做了什么 + 为什么"**。严禁 \`chore: auto-commit by claude code @ 时间戳\`、\`files changed: N\` 这类纯机械模板——commit 历史的价值在于语义，不在于元数据。
2. 沿用本仓库已有的 commit 规范：先看 \`git log --oneline -n 20\`，模仿现有风格（前缀、语种、句式）。若无明确规范，遵循 Conventional Commits（\`feat:\` / \`fix:\` / \`refactor:\` / \`docs:\` / \`test:\` / \`chore:\` 等），标题用中文，正文按需要展开"为什么"。
3. **暂存策略**：默认 \`git add -u\`（仅已追踪文件的修改 / 删除）。untracked 文件由你判断是否纳入；纳入前再三确认不是临时产物 / 测试输出 / 缓存 / 编辑器 swap 文件。
4. **commit 前自己再跑一遍 \`git diff --cached\` 复核**，确认 staged 内容确实就是你要表达的语义。
5. 本地 commit，**不要 push**（推送走 \`/git-push-pr\`）。
6. 完成 commit 后正常结束本轮即可——下一次 Stop 不会再触发本提示（防循环）。
7. 如果你判断本轮**不该** commit（例如改动尚未到一个合理的语义阶段、应该拆成多个 commit、或包含调试残留待清理），直接说明理由并停下，不要硬塞 commit。

参考信息：

- 分支：\`$BRANCH\`
- 仓库根：\`$REPO_ROOT\`
- 变更摘要：$SHORTSTAT
- 变更文件（最多 40 行 name-status）：

\`\`\`
$FILES_LIST
\`\`\`
EOF
)

jq -nc --arg reason "$REASON" '{
  "decision": "block",
  "reason": $reason
}'
