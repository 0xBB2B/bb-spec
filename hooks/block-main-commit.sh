#!/usr/bin/env bash
# 拦截 main / master 分支的 git commit 动作。
# Git 工作流纪律：所有非热修复内容必须在新分支开发，禁止直接污染主干。
# 输入：标准 PreToolUse stdin JSON
# 命中规则：命令首动词为 git、子命令为 commit、且当前分支为 main/master。
# 不命中 → 静默退出 0，让其他 hook 与默认权限继续生效。

set -euo pipefail

if ! command -v jq &>/dev/null || ! command -v git &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
TOOL=$(jq -r '.tool_name // empty' <<<"$INPUT")
[ "$TOOL" = "Bash" ] || exit 0

CMD=$(jq -r '.tool_input.command // empty' <<<"$INPUT")
[ -n "$CMD" ] || exit 0

# 拆 tokens（剥 env 前缀 / sudo / nohup）
read -r FIRST REST <<<"$CMD" || true
while [[ "$FIRST" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || [[ "$FIRST" == "sudo" ]] || [[ "$FIRST" == "nohup" ]]; do
  read -r FIRST REST <<<"$REST" || true
  [ -z "$FIRST" ] && break
done

[ "$FIRST" = "git" ] || exit 0

# 处理 `git -C <path> ...` 的工作目录覆盖
WORKTREE=""
read -r SECOND REST2 <<<"$REST" || true
if [ "$SECOND" = "-C" ]; then
  read -r WORKTREE REST3 <<<"$REST2" || true
  read -r SECOND _ <<<"$REST3" || true
fi

[ "$SECOND" = "commit" ] || exit 0

# 取分支
if [ -n "$WORKTREE" ]; then
  BRANCH=$(git -C "$WORKTREE" branch --show-current 2>/dev/null || true)
else
  BRANCH=$(git branch --show-current 2>/dev/null || true)
fi

# 拿不到分支说明不在 git 仓库或 detached HEAD，不阻止
[ -n "$BRANCH" ] || exit 0

case "$BRANCH" in
  main|master) ;;
  *) exit 0 ;;
esac

REASON=$(printf 'Git 工作流纪律：当前分支为 %s，禁止直接 commit 到主干。请先 `git switch -c <feature-branch>` 切到新分支再提交。' "$BRANCH")

jq -nc --arg reason "$REASON" '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": $reason
  }
}'
