#!/usr/bin/env bash
# 开发者导出 CDPATH 时 tests/ 下的脚本结果与不设 CDPATH 相同
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." >/dev/null && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "[设了 CDPATH 后相对路径运行测试脚本，退出码为 0]"
for t in md-lib skill-size; do
  rc=0
  (cd "$ROOT" && CDPATH=".:/tmp" bash "tests/${t}.test.sh" >/dev/null 2>&1) || rc=$?
  if [[ "$rc" -eq 0 ]]; then pass; else fail "CDPATH 下 tests/${t}.test.sh 退出码 ${rc}"; fi
done

echo "[tests/ 下每个脚本求自身目录的写法不受 CDPATH 影响]"
pat='cd (-- )?"\$\(dir''name "\$0"\)'
for f in "$ROOT"/tests/*.sh; do
  name="tests/$(basename "$f")"
  lines="$(grep -E -- "$pat" "$f" || true)"
  if [[ -z "$lines" ]]; then pass; continue; fi
  bad=0
  while IFS= read -r line; do
    [[ "$line" == *'CDPATH= cd --'* && "$line" == *'>/dev/null'* ]] || bad=1
  done <<< "$lines"
  if [[ "$bad" -eq 0 ]]; then pass; else fail "${name} 求自身目录的写法受 CDPATH 影响"; fi
done

echo "通过 ${PASS}，失败 ${FAIL}"
[[ "$FAIL" -eq 0 ]]
