#!/usr/bin/env bash
# 输出当前目录所属 bb-spec 项目的各目录绝对路径，每行一个 key=value：
#   root / base_dir / docs_dir / prd_dir / cache_dir / docs_repo（文档目录所在 git 仓库根，目录不存在时为空）
# 从仓库根往上找：先找最近的 .bb-spec.yaml，找不到再找最近的 .bb-spec/ 目录，都找不到用仓库根
set -euo pipefail

TOP=$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)

# 不查 $HOME 本身：~/.bb-spec/ 是 worktree 存放目录，不代表项目
find_up() {
  local test_flag="$1" name="$2" d="$TOP"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "$HOME" ]; do
    if [ "$test_flag" "$d/$name" ]; then echo "$d"; return; fi
    d=$(dirname "$d")
  done
}

ROOT=$(find_up -f .bb-spec.yaml)
[ -n "$ROOT" ] || ROOT=$(find_up -d .bb-spec)
[ -n "$ROOT" ] || ROOT="$TOP"

BASE=".bb-spec"
if [ -f "$ROOT/.bb-spec.yaml" ]; then
  V=$(sed -n -e '/^base_dir:/{' -e 's/^base_dir:[[:space:]]*//' -e 'p' -e 'q' -e '}' "$ROOT/.bb-spec.yaml" \
    | sed -E "s/[[:space:]]+#.*$//; s/^[\"']//; s/[\"']$//")
  [ -n "$V" ] && BASE="$V"
fi

while [ "${BASE#./}" != "$BASE" ]; do BASE="${BASE#./}"; done
BASE="${BASE%/}"
case "$BASE" in
  "" | ".") BASE_DIR="$ROOT" ;;
  /*) BASE_DIR="$BASE" ;;
  *) BASE_DIR="$ROOT/$BASE" ;;
esac

DOCS_DIR="$BASE_DIR/docs"
DOCS_REPO=""
[ -d "$DOCS_DIR" ] && DOCS_REPO=$(git -C "$DOCS_DIR" rev-parse --show-toplevel 2>/dev/null || true)

printf 'root=%s\nbase_dir=%s\ndocs_dir=%s\nprd_dir=%s\ncache_dir=%s\ndocs_repo=%s\n' \
  "$ROOT" "$BASE_DIR" "$DOCS_DIR" "$DOCS_DIR/prd" "$BASE_DIR/.cache" "$DOCS_REPO"
