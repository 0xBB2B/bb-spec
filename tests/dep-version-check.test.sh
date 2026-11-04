#!/usr/bin/env bash
# dep-version-check.sh 行为校验：新技术批准提示、非依赖文件静默、无 jq 静默放行
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$ROOT/plugins/bb-spec-core/hooks/dep-version-check.sh"
BASH_BIN="$(command -v bash)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

OUT=""
RC=0

mkin() { jq -nc --arg t "$1" --arg f "$2" '{tool_name:$t,tool_input:{file_path:$f}}'; }

run() {
  OUT=""
  RC=0
  OUT="$(printf '%s' "$1" | "$BASH_BIN" "$HOOK" 2>/dev/null)" || RC=$?
}

ctx_of() { jq -r '.hookSpecificOutput.additionalContext // empty' <<<"$OUT" 2>/dev/null || true; }

assert_empty() {
  if [[ -z "$OUT" && "$RC" -eq 0 ]]; then pass; else fail "${1}（退出码=$RC 输出=${OUT:0:80}）"; fi
}

assert_ctx_has() {
  local name="$1" ctx want
  ctx="$(ctx_of)"
  shift
  if [[ "$RC" -ne 0 ]]; then fail "${name}（退出码=$RC）"; return; fi
  for want in "$@"; do
    if [[ "$ctx" == *"$want"* ]]; then pass; else fail "${name} 应含「${want}」（实际=${ctx:0:120}）"; fi
  done
}

echo "[改 package.json]"
run "$(mkin Edit /p/package.json)"
if [[ "$RC" -eq 0 ]]; then pass; else fail "退出码应为 0（实际=$RC）"; fi
if jq -e . <<<"$OUT" >/dev/null 2>&1; then pass; else fail "输出应是合法 JSON"; fi
if [[ "$(jq -r '.hookSpecificOutput.hookEventName // empty' <<<"$OUT" 2>/dev/null || true)" == "PostToolUse" ]]; then pass; else fail "hookEventName 应为 PostToolUse"; fi
assert_ctx_has "package.json 提示" "立刻撤回这次改动" "新技术清单" "请用户批准" "官方渠道"

echo "[改 Dockerfile 与 CI 配置]"
run "$(mkin Write /p/Dockerfile)"
assert_ctx_has "Dockerfile 提示" "立刻撤回这次改动"
run "$(mkin Write /p/.github/workflows/ci.yml)"
assert_ctx_has "workflow 提示" "立刻撤回这次改动"

echo "[新技术提醒七项内容]"
run "$(mkin Edit /p/package.json)"
assert_ctx_has "package.json 新技术提醒" "七项内容" "名称、类别、来源、用途、现有手段为什么不够、替代方案为什么不选、版本策略" "弹一次窗" "不管改的是不是版本字段都要检查"
if [[ "$(ctx_of)" != *"请忽略本提示"* ]]; then pass; else fail "package.json 提示不应含「请忽略本提示」"; fi

echo "[所有依赖与配置文件共用同一条提示]"
run "$(mkin Write /p/Dockerfile)"
assert_ctx_has "Dockerfile 共用提示" "新技术清单" "请用户批准" "官方渠道"
run "$(mkin Write /p/.github/workflows/ci.yml)"
assert_ctx_has "workflow 共用提示" "新技术清单" "请用户批准" "官方渠道"
run "$(mkin Edit /p/go.mod)"
assert_ctx_has "go.mod 提示" "立刻撤回这次改动"
run "$(mkin Edit /p/compose.yaml)"
assert_ctx_has "compose.yaml 提示" "立刻撤回这次改动"

echo "[非依赖文件静默]"
run "$(mkin Edit /p/README.md)"
assert_empty "README.md 应无输出"

echo "[非 Write/Edit 工具静默]"
run "$(mkin Bash /p/package.json)"
assert_empty "Bash 工具应无输出"

echo "[没有 jq]"
NOJQ="$TMP/nojq-bin"
mkdir -p "$NOJQ"
for t in bash cat basename printf dirname env sh; do
  p="$(command -v "$t" 2>/dev/null || true)"
  if [[ -n "$p" && "$p" == /* ]]; then ln -sf "$p" "$NOJQ/$t"; fi
done
IN="$(mkin Edit /p/package.json)"
OUT=""
RC=0
OUT="$(printf '%s' "$IN" | PATH="$NOJQ" "$BASH_BIN" "$HOOK" 2>/dev/null)" || RC=$?
assert_empty "PATH 里没有 jq 应无输出"

echo ""
echo "通过 ${PASS}，失败 ${FAIL}"
[[ "$FAIL" -eq 0 ]]
