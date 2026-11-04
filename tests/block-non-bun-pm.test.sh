#!/usr/bin/env bash
# block-non-bun-pm.sh 行为校验：无 lockfile 时询问、有别的 lockfile 时拒绝、匹配 lockfile 或非安装命令静默
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$ROOT/plugins/bb-spec-frontend/hooks/block-non-bun-pm.sh"
BASH_BIN="$(command -v bash)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

X="$(mktemp -d)"
TMP="$(cd "$X" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

OUT=""
RC=0

# 用法：newrepo <名字> [lockfile...]，返回仓库根路径
newrepo() {
  local name="$1" f
  shift
  mkdir -p "$TMP/$name/.git"
  for f in "$@"; do : >"$TMP/$name/$f"; done
  printf '%s' "$TMP/$name"
}

run() {
  OUT=""
  RC=0
  OUT="$(jq -nc --arg c "$2" --arg d "$1" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}' | "$BASH_BIN" "$HOOK" 2>/dev/null)" || RC=$?
}

field() { jq -r ".hookSpecificOutput.$1 // empty" <<<"$OUT" 2>/dev/null || true; }

assert_empty() {
  if [[ -z "$OUT" && "$RC" -eq 0 ]]; then pass; else fail "${1}（退出码=$RC 输出=${OUT:0:80}）"; fi
}

assert_decision() {
  local name="$1" want="$2" got
  got="$(field permissionDecision)"
  if [[ "$RC" -eq 0 && "$got" == "$want" ]]; then pass; else fail "${name} 应为 ${want}（退出码=$RC 实际=${got}）"; fi
}

assert_reason_has() {
  local name="$1" reason want
  reason="$(field permissionDecisionReason)"
  shift
  for want in "$@"; do
    if [[ "$reason" == *"$want"* ]]; then pass; else fail "${name} 应含「${want}」（实际=${reason:0:120}）"; fi
  done
}

echo "[无 lockfile：npm install]"
D="$(newrepo none-npm)"
run "$D" "npm install"
assert_decision "npm install" ask
if [[ "$(field hookEventName)" == "PreToolUse" ]]; then pass; else fail "hookEventName 应为 PreToolUse"; fi
WANT='这个项目还没有 lockfile。前端默认推荐 bun，npm 对这个项目是新技术：你已经在新技术清单里批准用 npm，就选允许；没批准过就选拒绝，Claude 会改用 bun，或先列清单问你。'
if [[ "$(field permissionDecisionReason)" == "$WANT" ]]; then pass; else fail "reason 与期望文字不一致（实际=$(field permissionDecisionReason)）"; fi

echo "[无 lockfile：yarn add]"
D="$(newrepo none-yarn)"
run "$D" "yarn add vue"
assert_decision "yarn add" ask
assert_reason_has "yarn reason" "yarn 对这个项目是新技术" "批准用 yarn"

echo "[无 lockfile：pnpm add]"
D="$(newrepo none-pnpm)"
run "$D" "pnpm add vue"
assert_decision "pnpm add" ask
assert_reason_has "pnpm reason" "pnpm 对这个项目是新技术"

echo "[只有 bun.lock：npm install]"
D="$(newrepo bun-only bun.lock)"
run "$D" "npm install"
assert_decision "bun.lock + npm install" deny

echo "[有匹配 lockfile：npm install]"
D="$(newrepo npm-lock package-lock.json)"
run "$D" "npm install"
assert_empty "package-lock.json + npm install 应无输出"

echo "[无 lockfile：非安装命令]"
D="$(newrepo none-build)"
run "$D" "npm run build"
assert_empty "npm run build 应无输出"
run "$D" "npm test"
assert_empty "npm test 应无输出"

echo "[lockfile 在上一级]"
D="$(newrepo parent-bun bun.lock)"
mkdir -p "$D/web"
run "$D/web" "npm install"
assert_decision "上一级 bun.lock" deny
D="$(newrepo parent-npm package-lock.json)"
mkdir -p "$D/web"
run "$D/web" "npm install"
assert_empty "上一级 package-lock.json 应无输出"

echo "[.git 是文件或目录：到仓库根为止，不越过去找上级 lockfile]"
mkdir -p "$TMP/gitfile/repo"
: >"$TMP/gitfile/yarn.lock"
printf 'gitdir: /elsewhere\n' >"$TMP/gitfile/repo/.git"
run "$TMP/gitfile/repo" "npm install"
assert_decision ".git 是文件时不越过仓库根" ask
mkdir -p "$TMP/gitdir/repo/.git"
: >"$TMP/gitdir/yarn.lock"
run "$TMP/gitdir/repo" "npm install"
assert_decision ".git 是目录时不越过仓库根" ask

echo ""
echo "通过 ${PASS}，失败 ${FAIL}"
[[ "$FAIL" -eq 0 ]]
