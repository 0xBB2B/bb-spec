#!/usr/bin/env bash
# bbspec-paths.sh 行为校验：配置查找顺序、base_dir 解析、多仓库工作区、$HOME 截止
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/plugins/bb-spec-workflow/scripts/bbspec-paths.sh"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

FIXROOT="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$FIXROOT"' EXIT

mkgitrepo() {
  git init -q -b main "$1"
  git -C "$1" -c user.email=t@t.local -c user.name=t commit -q --allow-empty -m init
}

run() { (cd "$1" && HOME="${2:-$HOME}" bash "$SCRIPT"); }
val() { grep "^$2=" <<<"$1" | head -1 | cut -d= -f2-; }

expect() {
  local out="$1" key="$2" want="$3"
  if [[ "$(val "$out" "$key")" == "$want" ]]; then pass; else fail "$key 预期 [$want]，实际 [$(val "$out" "$key")]"; fi
}

echo "[单仓库 .bb-spec.yaml 默认 base_dir，从子目录运行]"
R="$FIXROOT/single"
mkgitrepo "$R"
printf '# 注释\nbase_dir: .bb-spec\n' > "$R/.bb-spec.yaml"
mkdir -p "$R/.bb-spec/docs/prd" "$R/src/sub"
out=$(run "$R/src/sub")
expect "$out" root "$R"
expect "$out" base_dir "$R/.bb-spec"
expect "$out" docs_dir "$R/.bb-spec/docs"
expect "$out" prd_dir "$R/.bb-spec/docs/prd"
expect "$out" cache_dir "$R/.bb-spec/.cache"
expect "$out" docs_repo "$R"

echo "[只有 .bb-spec/ 目录、没有配置文件 → base_dir 取 .bb-spec]"
R="$FIXROOT/dironly"
mkgitrepo "$R"
mkdir -p "$R/.bb-spec/docs"
out=$(run "$R")
expect "$out" root "$R"
expect "$out" docs_dir "$R/.bb-spec/docs"

echo "[base_dir: ./ → 交付物落项目根]"
R="$FIXROOT/dotroot"
mkgitrepo "$R"
printf 'base_dir: ./\n' > "$R/.bb-spec.yaml"
out=$(run "$R")
expect "$out" base_dir "$R"
expect "$out" docs_dir "$R/docs"
expect "$out" cache_dir "$R/.cache"

echo "[base_dir 带引号和行尾注释]"
R="$FIXROOT/quoted"
mkgitrepo "$R"
printf 'base_dir: "my/bb/"  # 自定义\n' > "$R/.bb-spec.yaml"
out=$(run "$R")
expect "$out" base_dir "$R/my/bb"
expect "$out" docs_dir "$R/my/bb/docs"

echo "[多仓库工作区：配置在上级目录，文档仓库独立]"
WS="$FIXROOT/ws"
mkdir -p "$WS"
printf 'base_dir: ./\n' > "$WS/.bb-spec.yaml"
mkgitrepo "$WS/docs"
mkgitrepo "$WS/trade"
mkdir -p "$WS/trade/internal"
out=$(run "$WS/trade/internal")
expect "$out" root "$WS"
expect "$out" docs_dir "$WS/docs"
expect "$out" prd_dir "$WS/docs/prd"
expect "$out" docs_repo "$WS/docs"

echo "[成员仓库里残留 .bb-spec/ 目录 → 仍以上级的配置文件为准]"
mkdir -p "$WS/trade/.bb-spec/.cache"
out=$(run "$WS/trade")
expect "$out" root "$WS"

echo "[哪里都没有配置 → 仓库根下的 .bb-spec，文档目录不存在时 docs_repo 为空]"
R="$FIXROOT/plain"
mkgitrepo "$R"
out=$(run "$R")
expect "$out" root "$R"
expect "$out" docs_dir "$R/.bb-spec/docs"
expect "$out" docs_repo ""

echo "[\$HOME 下的 .bb-spec/ 是 worktree 存放目录，不算项目]"
H="$FIXROOT/home"
R="$H/.bb-spec/worktrees/proj-feat"
mkdir -p "$H/.bb-spec/worktrees"
mkgitrepo "$R"
out=$(run "$R" "$H")
expect "$out" root "$R"

echo "[传入目录参数 → 按该目录解析，不看当前目录]"
out=$(cd "$FIXROOT" && bash "$SCRIPT" "$WS/trade")
expect "$out" root "$WS"

echo "[base_dir 带引号且行尾有空格]"
R="$FIXROOT/quoted-space"
mkgitrepo "$R"
printf 'base_dir: "my/bb"  \n' > "$R/.bb-spec.yaml"
out=$(run "$R")
expect "$out" base_dir "$R/my/bb"
expect "$out" docs_dir "$R/my/bb/docs"

echo "[base_dir 含 .. → 输出规范化后的真实路径]"
R="$FIXROOT/dotdot"
mkgitrepo "$R"
printf 'base_dir: sub/../.bb-spec\n' > "$R/.bb-spec.yaml"
mkdir -p "$R/sub" "$R/.bb-spec/docs"
out=$(run "$R")
expect "$out" base_dir "$R/.bb-spec"
expect "$out" cache_dir "$R/.bb-spec/.cache"
expect "$out" docs_dir "$R/.bb-spec/docs"
expect "$out" prd_dir "$R/.bb-spec/docs/prd"
expect "$out" docs_repo "$R"

echo "[docs 是指向另一个 git 仓库的软链接 → 输出真实路径]"
R="$FIXROOT/linkdocs"
D="$FIXROOT/linkdocs-d"
mkgitrepo "$R"
mkgitrepo "$D"
mkdir -p "$R/.bb-spec"
ln -s "$D" "$R/.bb-spec/docs"
out=$(run "$R")
expect "$out" docs_dir "$D"
expect "$out" prd_dir "$D/prd"
expect "$out" docs_repo "$D"

echo "[base_dir 本身是软链接 → 输出真实路径]"
R="$FIXROOT/linkbase"
mkgitrepo "$R"
mkdir -p "$R/real-bb"
ln -s real-bb "$R/bb"
printf 'base_dir: bb\n' > "$R/.bb-spec.yaml"
out=$(run "$R")
expect "$out" base_dir "$R/real-bb"
expect "$out" cache_dir "$R/real-bb/.cache"

echo "[base_dir 含 .. 且目标不存在 → 原样输出]"
R="$FIXROOT/dotdot-missing"
mkgitrepo "$R"
printf 'base_dir: a/../b\n' > "$R/.bb-spec.yaml"
out=$(run "$R")
expect "$out" base_dir "$R/a/../b"

echo ""
echo "==============================="
echo "通过: $PASS  |  失败: $FAIL"
echo "==============================="

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
