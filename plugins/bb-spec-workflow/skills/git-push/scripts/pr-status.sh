#!/usr/bin/env bash
# 用法：pr-status.sh <PR/MR 编号> [remote，缺省 origin]
# 按 remote 地址选 gh / glab，把两边的状态归成同一套值，输出三行：
#   state=merged|open|closed
#   merge_commit=<合并进基线的 commit 哈希，没有为空>
#   blocker=none|conflict|computing|ci_running|ci_failed|other:<平台原始状态>   （只在 state=open 时有意义）
set -euo pipefail

NUM="${1:?用法：pr-status.sh <编号> [remote]}"
REMOTE="${2:-origin}"
URL=$(git remote get-url "$REMOTE")

GH_JQ='
(.state | ascii_downcase) as $s
| [.statusCheckRollup[]? | if .__typename == "StatusContext" then .state elif .status != "COMPLETED" then "PENDING" else .conclusion end] as $c
| (if $s != "open" then "none"
   elif .mergeable == "CONFLICTING" or .mergeStateStatus == "DIRTY" then "conflict"
   elif .mergeable == "UNKNOWN" or .mergeStateStatus == "UNKNOWN" then "computing"
   elif any($c[]; . == "FAILURE" or . == "ERROR" or . == "TIMED_OUT" or . == "CANCELLED" or . == "ACTION_REQUIRED" or . == "STARTUP_FAILURE") then "ci_failed"
   elif any($c[]; . == "PENDING" or . == "EXPECTED" or . == "QUEUED") then "ci_running"
   elif .mergeStateStatus == "CLEAN" or .mergeStateStatus == "HAS_HOOKS" then "none"
   else "other:" + (.mergeStateStatus // "") end) as $b
| "state=\($s)", "merge_commit=\(.mergeCommit.oid // "")", "blocker=\($b)"'

# glab 输出里没值的哈希是空字符串而不是 null，要显式判空
GL_JQ='
.state as $st
| (if $st == "merged" then "merged" elif $st == "opened" or $st == "locked" then "open" else "closed" end) as $s
| (.detailed_merge_status // "") as $d
| (.head_pipeline.status // "") as $p
| (if $s != "open" then "none"
   elif $st == "locked" then "computing"
   elif $d == "conflict" or $d == "need_rebase" then "conflict"
   elif $d == "checking" or $d == "unchecked" or $d == "preparing" or $d == "approvals_syncing" then "computing"
   elif $d == "ci_still_running" then "ci_running"
   elif $d == "ci_must_pass" and ($p == "failed" or $p == "canceled") then "ci_failed"
   elif $d == "ci_must_pass" and ($p == "created" or $p == "pending" or $p == "running" or $p == "preparing" or $p == "waiting_for_resource" or $p == "scheduled") then "ci_running"
   elif $d == "mergeable" then "none"
   else "other:" + $d end) as $b
| "state=\($s)", "merge_commit=\(if (.squash_commit_sha // "") != "" then .squash_commit_sha else (.merge_commit_sha // "") end)", "blocker=\($b)"'

case "$URL" in
  *github*)
    SLUG=$(sed -E -e '/^[a-z+]+:\/\//{' -e 's#^[a-z+]+://([^@/]+@)?##' -e 's#^([^/:]+):[0-9]+/#\1/#' -e 'b' -e '}' -e 's#^[^@/]+@##; s#:#/#' <<<"$URL" | sed -E 's#\.git$##')
    gh pr view "$NUM" --repo "$SLUG" --json state,mergeCommit,mergeable,mergeStateStatus,statusCheckRollup --jq "$GH_JQ"
    ;;
  *gitlab*)
    glab mr view "$NUM" -R "$URL" -F json --jq "$GL_JQ"
    ;;
  *)
    echo "无法从 $REMOTE 的地址判断是 GitHub 还是 GitLab：$URL" >&2
    exit 2
    ;;
esac
