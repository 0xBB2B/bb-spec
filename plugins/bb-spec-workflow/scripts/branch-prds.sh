#!/usr/bin/env bash
# 用法：branch-prds.sh <基线> [目录，缺省当前目录]
# 输出本分支涉及的 PRD 目录名，每行一个：
#   new=<目录>     文档仓库里本分支改动过、基线上没有而 HEAD 上有 OVERVIEW.md 的 PRD
#   merged=<目录>  当前仓库本分支 commit 的 Requirement 行指向、基线上已有的 PRD
set -euo pipefail

BASE_REF="${1:?用法：branch-prds.sh <基线> [目录]}"
SELF_DIR=$(cd "$(dirname "$0")" && pwd)
[ $# -gt 1 ] && cd "$2"

PATHS=$("$SELF_DIR/bbspec-paths.sh")
DOCS_REPO=$(sed -n 's/^docs_repo=//p' <<<"$PATHS")
PRD_DIR=$(sed -n 's/^prd_dir=//p' <<<"$PATHS")
[ -n "$DOCS_REPO" ] || exit 0
PRD_REL="${PRD_DIR#"$DOCS_REPO"/}"

if ! git -C "$DOCS_REPO" rev-parse --verify --quiet "$BASE_REF^{commit}" >/dev/null; then
  echo "文档仓库 ${DOCS_REPO} 里找不到基线 ${BASE_REF}，无法判断 PRD" >&2
  exit 1
fi

on_base() { git -C "$DOCS_REPO" cat-file -e "$BASE_REF:$PRD_REL/$1/OVERVIEW.md" 2>/dev/null; }
on_head() { git -C "$DOCS_REPO" cat-file -e "HEAD:$PRD_REL/$1/OVERVIEW.md" 2>/dev/null; }

git -C "$DOCS_REPO" -c core.quotePath=false diff --name-only "$BASE_REF...HEAD" -- "$PRD_REL" \
  | awk -v p="$PRD_REL/" 'index($0, p) == 1 { rest = substr($0, length(p) + 1); if (index(rest, "/")) print substr(rest, 1, index(rest, "/") - 1) }' \
  | sort -u | while read -r d; do
    if ! on_base "$d" && on_head "$d"; then echo "new=$d"; fi
  done

# 全角逗号先换成半角再切分；awk 按字节处理，直接把全角逗号放进分隔符会切坏中文
git log --format=%B "$BASE_REF..HEAD" \
  | sed -n 's/^Requirement:[[:space:]]*//p' | sed 's/，/,/g' | tr ',' '\n' \
  | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; /^$/d; /^none/d' \
  | sort -u | while read -r d; do
    if on_base "$d"; then echo "merged=$d"; fi
  done
