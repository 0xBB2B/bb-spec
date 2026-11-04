#!/usr/bin/env bash
# 测试脚本在 mktemp 失败时必须直接退出，不能把当前目录当临时目录删掉
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SELF="$(basename "$0")"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

run_limited() {
  if command -v timeout >/dev/null 2>&1; then timeout 60 "$@"; else "$@"; fi
}

for script in "$ROOT"/tests/*.test.sh; do
  name="$(basename "$script")"
  [[ "$name" == "$SELF" ]] && continue
  grep -qF 'mktemp -d' "$script" || continue

  echo "[$name]"
  S="$(mktemp -d)" || exit 1
  trap 'rm -rf "$S"' EXIT
  : >"$S/keep"

  rc=0
  (cd "$S" && run_limited bash -c 'mktemp(){ return 1; }; export -f mktemp; bash "$1"' _ "$script" >/dev/null 2>&1) || rc=$?

  if [[ -e "$S/keep" ]]; then pass; else fail "$name 在 mktemp 失败时删掉了当前目录里的文件"; fi
  if [[ "$rc" -ne 0 ]]; then pass; else fail "$name 在 mktemp 失败时应退出非 0"; fi

  rm -rf "$S"
done

echo "通过 ${PASS}，失败 ${FAIL}"
[[ "$FAIL" -eq 0 ]]
