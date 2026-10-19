#!/usr/bin/env bash
# branch-prds.sh 行为校验：本分支新增 PRD、commit 指向的已合并 PRD、多仓库工作区
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/plugins/bb-spec-workflow/scripts/branch-prds.sh"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

FIXROOT="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$FIXROOT"' EXIT

g() { git -C "$1" -c user.email=t@t.local -c user.name=t "${@:2}"; }
mkgitrepo() { git init -q -b main "$1"; g "$1" commit -q --allow-empty -m init; }
addfile() { mkdir -p "$(dirname "$1/$2")"; printf '%s\n' "${3:-x}" > "$1/$2"; g "$1" add "$2"; }

expect_out() {
  local got="$1" want="$2" label="$3"
  if [[ "$got" == "$want" ]]; then pass; else fail "$label：预期 [$want]，实际 [$got]"; fi
}

echo "[单仓库：新增 PRD、已合并 PRD、none 与不存在的目录]"
R="$FIXROOT/single"
mkgitrepo "$R"
P=".bb-spec/docs/prd"
addfile "$R" "$P/2026-01-01.old/OVERVIEW.md"
addfile "$R" "$P/GLOSSARY.md"
g "$R" commit -q -m "old prd"
g "$R" switch -q -c feat
addfile "$R" "$P/2026-10-19.new/OVERVIEW.md"
addfile "$R" "$P/GLOSSARY.md" changed
addfile "$R" "$P/2026-01-01.old/OVERVIEW.md" changed
g "$R" commit -q -m "$(printf 'docs\n\nRequirement: 2026-10-19.new')"
g "$R" commit -q --allow-empty -m "$(printf 'fix\n\nRequirement: 2026-01-01.old')"
g "$R" commit -q --allow-empty -m "$(printf 'chore\n\nRequirement: none（与需求无关）')"
g "$R" commit -q --allow-empty -m "$(printf 'mix\n\nRequirement: missing-dir，2026-01-01.old')"
out=$(cd "$R" && bash "$SCRIPT" main)
expect_out "$out" "$(printf 'new=2026-10-19.new\nmerged=2026-01-01.old')" "单仓库输出"

echo "[没有文档目录 → 无输出、退出码 0]"
R="$FIXROOT/plain"
mkgitrepo "$R"
g "$R" switch -q -c feat
if out=$(cd "$R" && bash "$SCRIPT" main); then expect_out "$out" "" "无文档目录"; else fail "无文档目录时退出码非 0"; fi

echo "[多仓库工作区：新增 PRD 看文档仓库，已合并 PRD 看代码仓库的 commit]"
WS="$FIXROOT/ws"
mkdir -p "$WS"
printf 'base_dir: ./\n' > "$WS/.bb-spec.yaml"
mkgitrepo "$WS/docs"
addfile "$WS/docs" "prd/2026-02-02.merged/OVERVIEW.md"
g "$WS/docs" commit -q -m merged
g "$WS/docs" switch -q -c feat
addfile "$WS/docs" "prd/2026-10-19.ws-new/OVERVIEW.md"
g "$WS/docs" commit -q -m new
mkgitrepo "$WS/trade"
g "$WS/trade" switch -q -c feat
g "$WS/trade" commit -q --allow-empty -m "$(printf 'feat\n\nRequirement: 2026-10-19.ws-new')"
g "$WS/trade" commit -q --allow-empty -m "$(printf 'fix\n\nRequirement: 2026-02-02.merged')"
out=$(cd "$WS/trade" && bash "$SCRIPT" main)
expect_out "$out" "$(printf 'new=2026-10-19.ws-new\nmerged=2026-02-02.merged')" "多仓库输出"

echo ""
echo "==============================="
echo "通过: $PASS  |  失败: $FAIL"
echo "==============================="

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
