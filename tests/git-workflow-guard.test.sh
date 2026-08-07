#!/usr/bin/env bash
# git-workflow-guard.sh 行为校验：cd/-C 目录推导、保守回退、状态注入锚点、既有拦截回归
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$ROOT/plugins/bb-spec-core/hooks/git-workflow-guard.sh"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

FIXROOT="$(mktemp -d)"
HOMEFIX="$HOME/.bb-spec/worktrees/guard-test-fixtures-$$"
cleanup() { rm -rf "$FIXROOT" "$HOMEFIX"; }
trap cleanup EXIT

mkgitrepo() {
  local dir="$1" branch="$2"
  git init -q -b "$branch" "$dir"
  git -C "$dir" -c user.email=t@t.local -c user.name=t commit -q --allow-empty -m init
}

MAIN_REPO="$FIXROOT/main-repo"
FEAT_REPO="$FIXROOT/feat-repo"
BASE_DIR="$FIXROOT/base"
FEATSUB_REPO="$BASE_DIR/featsub"
HOMEFIX_PROJ="$HOMEFIX/proj"
HOMEFIX_HOMEVAR="$HOMEFIX/homevar"
HOMEOVERRIDE_REPO="$FIXROOT/homeoverride"

mkgitrepo "$MAIN_REPO" main
mkgitrepo "$FEAT_REPO" feat-x
mkgitrepo "$FEATSUB_REPO" feat-x
mkgitrepo "$HOMEFIX_PROJ" feat-x
mkgitrepo "$HOMEFIX_HOMEVAR" feat-x
mkgitrepo "$HOMEOVERRIDE_REPO" feat-x

run_hook() {
  local cmd="$1" cwd="$2"
  (cd "$cwd" && jq -nc --arg cmd "$cmd" '{tool_name:"Bash",tool_input:{command:$cmd}}' | bash "$HOOK")
}

run_hook_with_home() {
  local cmd="$1" cwd="$2" home_override="$3"
  (cd "$cwd" && jq -nc --arg cmd "$cmd" '{tool_name:"Bash",tool_input:{command:$cmd}}' | HOME="$home_override" bash "$HOOK")
}

decision_of() { jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$1"; }
reason_of() { jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$1"; }
context_of() { jq -r '.hookSpecificOutput.additionalContext // empty' <<<"$1"; }
branch_line_of() { context_of "$1" | grep -o '当前分支：.*'; }

echo "=== cd 目录追踪 ==="

echo "[cd 到功能分支目录后 commit → 放行]"
out=$(run_hook "cd $FEAT_REPO && git commit -m m" "$MAIN_REPO")
if [[ "$(decision_of "$out")" != "deny" ]]; then pass; else fail "预期放行，实际 deny：$(reason_of "$out")"; fi

echo "[会话目录在 main → 直接 commit deny（回归）]"
out=$(run_hook "git commit -m m" "$MAIN_REPO")
if [[ "$(decision_of "$out")" == "deny" && "$(reason_of "$out")" == *main* ]]; then pass; else fail "预期 deny 含 main，实际：$out"; fi

echo "[会话目录在 feature，cd 到 main 目录后 commit → deny]"
out=$(run_hook "cd $MAIN_REPO && git commit -m m" "$FEAT_REPO")
if [[ "$(decision_of "$out")" == "deny" && "$(reason_of "$out")" == *main* ]]; then pass; else fail "预期 deny 含 main，实际：$out"; fi

echo "[cd 无法解析的变量 → 回退会话目录且 deny 含'会话'说明]"
out=$(run_hook 'cd $WT && git commit -m m' "$MAIN_REPO")
if [[ "$(decision_of "$out")" == "deny" && "$(reason_of "$out")" == *会话* ]]; then pass; else fail "预期 deny 含'会话'说明，实际：$out"; fi

echo "[cd 无参数 → 等价于 cd \$HOME（HOME 覆盖指向功能分支仓库）]"
out=$(run_hook_with_home "cd && git commit -m m" "$MAIN_REPO" "$HOMEOVERRIDE_REPO")
if [[ "$(decision_of "$out")" != "deny" ]]; then pass; else fail "预期放行，实际 deny：$(reason_of "$out")"; fi

echo "=== -C 与保守回退 ==="

echo "[-C 含未展开变量 → deny 且按会话目录判定]"
out=$(run_hook 'git -C "$WT" commit -m m' "$MAIN_REPO")
if [[ "$(decision_of "$out")" == "deny" && "$(reason_of "$out")" == *会话* ]]; then pass; else fail "预期 deny 含'会话'说明，实际：$out"; fi

echo "[-C 字面量路径指向功能分支 → 放行（回归）]"
out=$(run_hook "git -C $FEAT_REPO commit -m m" "$MAIN_REPO")
if [[ "$(decision_of "$out")" != "deny" ]]; then pass; else fail "预期放行，实际 deny：$(reason_of "$out")"; fi

echo "[-C 带双引号路径 → 剥离引号后正确判定分支]"
out=$(run_hook "git -C \"$FEAT_REPO\" commit -m m" "$MAIN_REPO")
if [[ "$(decision_of "$out")" != "deny" && "$(context_of "$out")" == *feat-x* && "$(context_of "$out")" != *detached* ]]; then
  pass
else
  fail "预期放行且状态显示 feat-x 非 detached，实际：$out"
fi

echo "[cd 后 -C 相对路径 → 基于推导目录拼接]"
out=$(run_hook "cd $BASE_DIR && git -C featsub commit -m m" "$MAIN_REPO")
if [[ "$(decision_of "$out")" != "deny" && "$(context_of "$out")" == *feat-x* ]]; then
  pass
else
  fail "预期放行且状态显示 feat-x，实际：$out"
fi

echo "[git -C <path> worktree add <非法路径> → deny（-C 与 worktree 组合正确解析）]"
out=$(run_hook "git -C $FEAT_REPO worktree add $FIXROOT/illegal-wt -b b main" "$MAIN_REPO")
if [[ "$(decision_of "$out")" == "deny" ]]; then pass; else fail "预期 deny，实际：$out"; fi

echo "[cd 无法解析的变量后又 cd 到合法目录 → fallback 说明不外溢]"
out=$(run_hook "cd \$V && cd $FEAT_REPO && git push" "$MAIN_REPO")
if [[ "$(context_of "$out")" == *feat-x* && "$(context_of "$out")" != *会话* ]]; then
  pass
else
  fail "预期状态显示 feat-x 且不含'会话'说明，实际：$out"
fi

echo "=== \$HOME 展开 ==="
REL_HOMEVAR="${HOMEFIX_HOMEVAR#"$HOME"/}"
echo "[cd \$HOME/<相对路径> → 展开后正确判定，不回退]"
out=$(run_hook 'cd $HOME/'"$REL_HOMEVAR"' && git commit -m m' "$MAIN_REPO")
if [[ "$(context_of "$out")" == *feat-x* && "$(context_of "$out")" != *会话* ]]; then
  pass
else
  fail "预期状态显示 feat-x 且不含'会话'回退说明，实际：$out"
fi

echo "[git -C \$HOME/<路径> commit → 展开后正确判定，不回退]"
out=$(run_hook 'git -C $HOME/'"$REL_HOMEVAR"' commit -m m' "$MAIN_REPO")
if [[ "$(context_of "$out")" == *feat-x* && "$(context_of "$out")" != *会话* ]]; then
  pass
else
  fail "预期状态显示 feat-x 且不含'会话'回退说明，实际：$out"
fi

echo "[cd \$HOME（单独 token）→ 展开为 HOME 且不回退]"
out=$(run_hook_with_home 'cd $HOME && git commit -m m' "$MAIN_REPO" "$HOMEOVERRIDE_REPO")
if [[ "$(decision_of "$out")" != "deny" ]]; then pass; else fail "预期放行，实际 deny：$(reason_of "$out")"; fi

echo "[\$HOMEBREW_PREFIX 类变量不得被当作 \$HOME 前缀子串展开 → 回退会话目录且 deny 含'会话']"
out=$(run_hook 'cd $HOMEBREW_PREFIX/repo && git commit -m m' "$MAIN_REPO")
if [[ "$(decision_of "$out")" == "deny" && "$(reason_of "$out")" == *会话* ]]; then
  pass
else
  fail "预期 deny 含'会话'说明（\$HOMEBREW_PREFIX 不应被当作 \$HOME 子串展开），实际：$out"
fi

echo "[deny 段的回退状态不被其后合法段冲掉：cd \$V && commit && -C <合法> push → deny 含'会话']"
out=$(run_hook "cd \$V && git commit -m m && git -C $FEAT_REPO push" "$MAIN_REPO")
if [[ "$(decision_of "$out")" == "deny" && "$(reason_of "$out")" == *会话* ]]; then
  pass
else
  fail "预期 deny 含'会话'说明，实际：$out"
fi

echo "=== 状态注入锚点 ==="

echo "[cd 到功能分支目录后 push → 注入分支为该目录分支]"
out=$(run_hook "cd $FEAT_REPO && git push" "$MAIN_REPO")
if [[ "$(context_of "$out")" == *feat-x* ]]; then pass; else fail "预期状态含 feat-x，实际：$out"; fi

echo "[-C 不污染后续段：commit 用 -C 目录，push 状态回落会话目录]"
out=$(run_hook "git -C $FEAT_REPO commit -m m && git push" "$MAIN_REPO")
if [[ "$(branch_line_of "$out")" == *main* && "$(branch_line_of "$out")" != *feat-x* ]]; then
  pass
else
  fail "预期状态分支为会话目录 main 而非 feat-x，实际：$out"
fi

echo "=== ~ 展开 ==="
REL="${HOMEFIX_PROJ#"$HOME"/}"
echo "[cd ~/相对路径 → 正确定位功能分支]"
out=$(run_hook "cd ~/$REL && git commit -m m" "$MAIN_REPO")
if [[ "$(decision_of "$out")" != "deny" ]]; then pass; else fail "预期放行，实际 deny：$(reason_of "$out")"; fi

echo "=== 既有行为回归 ==="

echo "[worktree add 落在 \$HOME/.bb-spec/worktrees/ 下 → 放行]"
out=$(run_hook "git worktree add $HOMEFIX/newwt -b b main" "$MAIN_REPO")
if [[ "$(decision_of "$out")" != "deny" ]]; then pass; else fail "预期放行，实际 deny：$(reason_of "$out")"; fi

echo "[worktree add 路径含 \$HOME 字面 token（未被外层 shell 预展开）→ 放行]"
out=$(run_hook 'git worktree add $HOME/.bb-spec/worktrees/x -b b main' "$MAIN_REPO")
if [[ "$(decision_of "$out")" != "deny" ]]; then pass; else fail "预期放行，实际 deny：$(reason_of "$out")"; fi

echo "[worktree add 落在其它路径 → deny]"
out=$(run_hook "git worktree add $FIXROOT/sibling -b b main" "$MAIN_REPO")
if [[ "$(decision_of "$out")" == "deny" ]]; then pass; else fail "预期 deny，实际：$out"; fi

echo "[非 git 命令静默放行]"
out=$(run_hook "ls" "$MAIN_REPO")
if [[ -z "$out" ]]; then pass; else fail "预期无输出，实际：$out"; fi

echo "[gh pr 视为流程动作 → allow 且注入 context]"
out=$(run_hook "gh pr view 1" "$MAIN_REPO")
if [[ "$(decision_of "$out")" == "allow" && -n "$(context_of "$out")" ]]; then
  pass
else
  fail "预期 allow 且注入 context，实际：$out"
fi

echo ""
echo "==============================="
echo "通过: $PASS  |  失败: $FAIL"
echo "==============================="

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
