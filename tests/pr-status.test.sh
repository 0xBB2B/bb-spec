#!/usr/bin/env bash
# pr-status.sh 行为校验：用假的 gh / glab 回放平台 JSON，检查归一后的 state / merge_commit / blocker
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/plugins/bb-spec-workflow/skills/git-push/scripts/pr-status.sh"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

FIXROOT="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$FIXROOT"' EXIT

STUBS="$FIXROOT/bin"
mkdir -p "$STUBS"
for tool in gh glab; do
  cat > "$STUBS/$tool" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$STUB_ARGS"
expr=""
while [ $# -gt 0 ]; do
  [ "$1" = "--jq" ] && { expr="$2"; shift; }
  shift
done
jq -r "$expr" <<<"$STUB_JSON"
EOF
  chmod +x "$STUBS/$tool"
done
export STUB_ARGS="$FIXROOT/args"

GH_REPO="$FIXROOT/gh-repo"
GL_REPO="$FIXROOT/gl-repo"
git init -q "$GH_REPO" && git -C "$GH_REPO" remote add origin git@github.com:o/r.git
git init -q "$GL_REPO" && git -C "$GL_REPO" remote add origin https://gitlab.example.com/g/sub/r.git
git -C "$GL_REPO" remote add upstream https://github.com/up/r.git

run() { (cd "$1" && STUB_JSON="$2" PATH="$STUBS:$PATH" bash "$SCRIPT" "${@:3}"); }

case_of() {
  local label="$1" repo="$2" json="$3" want="$4"
  shift 4
  local out
  out=$(run "$repo" "$json" "$@")
  if [[ "$out" == "$want" ]]; then pass; else fail "$label：预期 [$want]，实际 [$out]"; fi
}

lines() { printf 'state=%s\nmerge_commit=%s\nblocker=%s' "$1" "$2" "$3"; }

echo "=== GitHub ==="
case_of "已合并" "$GH_REPO" '{"state":"MERGED","mergeCommit":{"oid":"abc"},"mergeable":"UNKNOWN","mergeStateStatus":"UNKNOWN","statusCheckRollup":[]}' "$(lines merged abc none)" 12
if [[ "$(cat "$STUB_ARGS")" == "pr view 12 --repo github.com/o/r "* ]]; then pass; else fail "gh 参数不对：$(cat "$STUB_ARGS")"; fi
case_of "冲突" "$GH_REPO" '{"state":"OPEN","mergeCommit":null,"mergeable":"CONFLICTING","mergeStateStatus":"DIRTY","statusCheckRollup":[]}' "$(lines open "" conflict)" 12
case_of "还在计算" "$GH_REPO" '{"state":"OPEN","mergeCommit":null,"mergeable":"UNKNOWN","mergeStateStatus":"UNKNOWN","statusCheckRollup":[]}' "$(lines open "" computing)" 12
case_of "CI 失败" "$GH_REPO" '{"state":"OPEN","mergeCommit":null,"mergeable":"MERGEABLE","mergeStateStatus":"BLOCKED","statusCheckRollup":[{"__typename":"CheckRun","status":"COMPLETED","conclusion":"SUCCESS"},{"__typename":"CheckRun","status":"COMPLETED","conclusion":"FAILURE"}]}' "$(lines open "" ci_failed)" 12
case_of "CI 进行中" "$GH_REPO" '{"state":"OPEN","mergeCommit":null,"mergeable":"MERGEABLE","mergeStateStatus":"BLOCKED","statusCheckRollup":[{"__typename":"CheckRun","status":"IN_PROGRESS","conclusion":null}]}' "$(lines open "" ci_running)" 12
case_of "状态检查进行中" "$GH_REPO" '{"state":"OPEN","mergeCommit":null,"mergeable":"MERGEABLE","mergeStateStatus":"BLOCKED","statusCheckRollup":[{"__typename":"StatusContext","state":"PENDING"}]}' "$(lines open "" ci_running)" 12
case_of "可合并" "$GH_REPO" '{"state":"OPEN","mergeCommit":null,"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[]}' "$(lines open "" none)" 12
case_of "其他原因" "$GH_REPO" '{"state":"OPEN","mergeCommit":null,"mergeable":"MERGEABLE","mergeStateStatus":"BEHIND","statusCheckRollup":[]}' "$(lines open "" other:BEHIND)" 12
case_of "已关闭" "$GH_REPO" '{"state":"CLOSED","mergeCommit":null,"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN","statusCheckRollup":[]}' "$(lines closed "" none)" 12

echo "=== GitLab ==="
case_of "已合并（squash 哈希）" "$GL_REPO" '{"state":"merged","squash_commit_sha":"s1","merge_commit_sha":"","detailed_merge_status":"not_open","head_pipeline":null}' "$(lines merged s1 none)" 7
if [[ "$(cat "$STUB_ARGS")" == "mr view 7 -R https://gitlab.example.com/g/sub/r.git "* ]]; then pass; else fail "glab 参数不对：$(cat "$STUB_ARGS")"; fi
case_of "已合并（squash 哈希为空串）" "$GL_REPO" '{"state":"merged","squash_commit_sha":"","merge_commit_sha":"m1","detailed_merge_status":"not_open","head_pipeline":null}' "$(lines merged m1 none)" 7
case_of "冲突" "$GL_REPO" '{"state":"opened","squash_commit_sha":"","merge_commit_sha":"","detailed_merge_status":"conflict","head_pipeline":null}' "$(lines open "" conflict)" 7
case_of "需要 rebase" "$GL_REPO" '{"state":"opened","squash_commit_sha":"","merge_commit_sha":"","detailed_merge_status":"need_rebase","head_pipeline":null}' "$(lines open "" conflict)" 7
case_of "还在计算" "$GL_REPO" '{"state":"opened","squash_commit_sha":"","merge_commit_sha":"","detailed_merge_status":"checking","head_pipeline":null}' "$(lines open "" computing)" 7
case_of "CI 进行中" "$GL_REPO" '{"state":"opened","squash_commit_sha":"","merge_commit_sha":"","detailed_merge_status":"ci_still_running","head_pipeline":{"status":"running"}}' "$(lines open "" ci_running)" 7
case_of "CI 失败" "$GL_REPO" '{"state":"opened","squash_commit_sha":"","merge_commit_sha":"","detailed_merge_status":"ci_must_pass","head_pipeline":{"status":"failed"}}' "$(lines open "" ci_failed)" 7
case_of "其他原因" "$GL_REPO" '{"state":"opened","squash_commit_sha":"","merge_commit_sha":"","detailed_merge_status":"not_approved","head_pipeline":null}' "$(lines open "" other:not_approved)" 7
case_of "已关闭" "$GL_REPO" '{"state":"closed","squash_commit_sha":"","merge_commit_sha":"","detailed_merge_status":"not_open","head_pipeline":null}' "$(lines closed "" none)" 7

echo "=== 指定 remote ==="
case_of "upstream 是 GitHub" "$GL_REPO" '{"state":"MERGED","mergeCommit":{"oid":"u1"},"mergeable":"UNKNOWN","mergeStateStatus":"UNKNOWN","statusCheckRollup":[]}' "$(lines merged u1 none)" 3 upstream
if [[ "$(cat "$STUB_ARGS")" == "pr view 3 --repo github.com/up/r "* ]]; then pass; else fail "gh 参数不对：$(cat "$STUB_ARGS")"; fi

echo "[认不出平台 → 退出码非 0]"
OTHER="$FIXROOT/other"
git init -q "$OTHER" && git -C "$OTHER" remote add origin https://git.example.com/o/r.git
if (cd "$OTHER" && PATH="$STUBS:$PATH" bash "$SCRIPT" 1) >/dev/null 2>&1; then fail "预期失败，实际成功"; else pass; fi

echo ""
echo "==============================="
echo "通过: $PASS  |  失败: $FAIL"
echo "==============================="

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
