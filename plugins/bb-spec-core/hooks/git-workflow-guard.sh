#!/usr/bin/env bash
# git-workflow 流程纪律守卫（PreToolUse / Bash）。
# 一份命令解析逻辑，承担两种职责：
#   1) 硬约束拦截 → deny
#      - main / master 分支上的 git commit（禁止直接污染主干）
#      - git worktree add 目标路径不在 ~/.bb-spec/worktrees/ 下（禁嵌套当前 repo / 禁 sibling 目录）
#   2) 其余 git / gh pr 流程动作（开分支 / commit / push / worktree / merge / PR …）
#                                                 → allow + 注入 git-workflow 约束与实时 git 状态
#   3) 其它命令                                   → 静默放行（exit 0）
# 输入：标准 PreToolUse stdin JSON。
# 设计：注入而非拦截——不打断模型，只在 git 操作发生时把 git-workflow 纪律推到模型眼前，
#       配合 SKILL.md 给不了的实时 git 状态（当前分支、工作区是否干净）。

set -euo pipefail

# 缺 jq / git 则无从判断，静默放行
command -v jq &>/dev/null || exit 0
command -v git &>/dev/null || exit 0

INPUT=$(cat)
TOOL=$(jq -r '.tool_name // empty' <<<"$INPUT")
[ "$TOOL" = "Bash" ] || exit 0

CMD=$(jq -r '.tool_input.command // empty' <<<"$INPUT")
[ -n "$CMD" ] || exit 0

# 按 && / || / ; 拆成多段，逐段识别动词
SEGMENTS=$(printf '%s\n' "$CMD" | sed 's/ *&& */\n/g; s/ *|| */\n/g; s/ *; */\n/g')

FLOW=0            # 命中任一 git / gh pr 流程动作 → 需注入
DENY=0            # 命中 main / master 上的 commit → 需拦截
DENY_BRANCH=""    # 触发 deny 时的分支名（用于提示文案）
DENY_WT_PATH=""   # 触发 deny 时的 worktree 目标路径（用于提示文案）
DENY_KIND=""      # branch | worktree-path
GIT_C_PATH=""     # 最近一个流程段的 `git -C <path>` 工作目录覆盖

while IFS= read -r SEG; do
  [ -z "$SEG" ] && continue

  # 剥掉 env 前缀（FOO=bar）/ sudo / nohup，定位真正的首动词
  read -r FIRST REST <<<"$SEG" || true
  while [[ "$FIRST" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || [[ "$FIRST" == "sudo" ]] || [[ "$FIRST" == "nohup" ]]; do
    read -r FIRST REST <<<"$REST" || true
    [ -z "$FIRST" ] && break
  done

  case "$FIRST" in
    git)
      # 处理 `git -C <path> ...` 的工作目录覆盖
      read -r SECOND REST2 <<<"$REST" || true
      SEG_C=""
      if [ "$SECOND" = "-C" ]; then
        read -r SEG_C REST3 <<<"$REST2" || true
        read -r SECOND _ <<<"$REST3" || true
      fi
      case "$SECOND" in
        commit|push|switch|checkout|branch|worktree|merge|rebase|cherry-pick)
          FLOW=1
          [ -n "$SEG_C" ] && GIT_C_PATH="$SEG_C"
          if [ "$SECOND" = "commit" ]; then
            # 取该段所在仓库的当前分支，判断是否在主干
            if [ -n "$SEG_C" ]; then
              BR=$(git -C "$SEG_C" branch --show-current 2>/dev/null || true)
            else
              BR=$(git branch --show-current 2>/dev/null || true)
            fi
            case "$BR" in
              main|master) DENY=1; DENY_KIND="branch"; DENY_BRANCH="$BR" ;;
            esac
          fi
          if [ "$SECOND" = "worktree" ]; then
            # 仅 `worktree add` 需要校验路径；list/remove/prune/lock 等放行
            read -r THIRD WT_REST <<<"$REST2" || true
            if [ "$THIRD" = "add" ]; then
              # 从 add 后的 token 流里找到第一个「非 flag 且非 flag 取值」的 token = 目标路径
              # 取值型 flag：-b / -B / --reason / --track-from（保守覆盖常见的）
              WT_PATH=""
              # shellcheck disable=SC2086
              set -- $WT_REST
              while [ $# -gt 0 ]; do
                case "$1" in
                  -b|-B|--reason)
                    shift; shift || true ;;
                  --*=*|-*)
                    shift ;;
                  *)
                    WT_PATH="$1"; break ;;
                esac
              done
              if [ -n "$WT_PATH" ]; then
                # 展开 ~ / $HOME（${var#~} 里的 ~ 会被 bash 当 tilde expansion 解析，故用 substring）
                case "$WT_PATH" in
                  "~") WT_PATH="$HOME" ;;
                  "~/"*) WT_PATH="${HOME}/${WT_PATH:2}" ;;
                esac
                WT_PATH="${WT_PATH//\$HOME/$HOME}"
                # 必须落在 ~/.bb-spec/worktrees/ 下（单 repo / 多 repo 工作区共用此前缀）
                case "$WT_PATH" in
                  "$HOME/.bb-spec/worktrees/"*) : ;;
                  *) DENY=1; DENY_KIND="worktree-path"; DENY_WT_PATH="$WT_PATH" ;;
                esac
              fi
            fi
          fi
          ;;
      esac
      ;;
    gh)
      # gh pr <create|merge|...> 视为 PR 流程动作
      read -r SECOND _ <<<"$REST" || true
      [ "$SECOND" = "pr" ] && FLOW=1
      ;;
  esac
done <<<"$SEGMENTS"

# 职责一：硬约束拦截（deny 优先于注入）
if [ "$DENY" = "1" ]; then
  case "$DENY_KIND" in
    branch)
      REASON=$(printf 'Git 工作流纪律：当前分支为 %s，禁止直接 commit 到主干。请先 `git switch -c <feature-branch>` 切到新分支再提交。' "$DENY_BRANCH") ;;
    worktree-path)
      REASON=$(printf 'Git 工作流纪律：worktree 必须落在 ~/.bb-spec/worktrees/ 下（单 repo: <repo>-<branch>；多 repo 工作区: <project>-<branch>/<repo>），禁止嵌套当前 repo 或放 sibling 目录。本次目标路径：%s' "$DENY_WT_PATH") ;;
    *)
      REASON="Git 工作流纪律：命中硬约束。" ;;
  esac
  jq -nc --arg reason "$REASON" '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": $reason
    }
  }'
  exit 0
fi

# 非流程动作（纯读 / 非 git）→ 静默放行
[ "$FLOW" = "1" ] || exit 0

# 职责二：放行流程动作，同时注入 git-workflow 纪律 + 实时 git 状态
[ -n "$GIT_C_PATH" ] && GROOT="$GIT_C_PATH" || GROOT="."
BRANCH=$(git -C "$GROOT" branch --show-current 2>/dev/null || true)
[ -n "$BRANCH" ] || BRANCH="(detached / 非 git 仓库)"
DIRTY=$(git -C "$GROOT" status --short 2>/dev/null | head -5 || true)
[ -n "$DIRTY" ] || DIRTY="(clean)"

CONTEXT=$(cat <<EOF
[git-workflow 纪律] 本次涉及 git 流程操作。执行前请遵循 bb-spec-core 的 git-workflow skill（若尚未加载，先加载再操作）。核心约束：
- 开新任务先用 AskUserQuestion 选开分支方式（默认 worktree），禁止在 main 直接开发 / 提交。
- 阶段性 commit 后不立即 push；仅当功能本地完成 + 测试通过 + 用户确认后才推送。
- 开 PR 用六段式描述；PR 合并后清理本地分支 + 远程引用。

实时 git 状态：
- 当前分支：${BRANCH}
- 工作区：
${DIRTY}
EOF
)

jq -nc --arg ctx "$CONTEXT" '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "git 流程操作，已注入 git-workflow 纪律与实时状态",
    "additionalContext": $ctx
  }
}'
exit 0
