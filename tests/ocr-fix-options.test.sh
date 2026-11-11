#!/usr/bin/env bash
# ocr 核实后的修复选项规则校验：git-push 的四个选项名、范围、等级图标、去选项规则和选「全不修复」的去向
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GIT_PUSH="$ROOT/plugins/bb-spec-workflow/skills/git-push/SKILL.md"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

has() {
  local text="$1"
  if grep -rqF -- "$text" "$(dirname "$GIT_PUSH")" 2>/dev/null; then pass; else fail "git-push/SKILL.md 缺少：${text}"; fi
}

lacks() {
  local text="$1"
  local rc=0
  grep -rqF -- "$text" "$(dirname "$GIT_PUSH")" 2>/dev/null || rc=$?
  case "$rc" in
    0) fail "git-push/SKILL.md 不应含：${text}" ;;
    1) pass ;;
    *) fail "读不到 ${GIT_PUSH}" ;;
  esac
}

echo "[问题文字与选项顺序]"
for t in 'ocr 核实后建议修 C 条（🔴 a · 🔶 b · 🔷 c），修哪些？' \
  '选项依次为：全部修复（Recommended）/ 只修重点 / 只修核心 / 全不修复'; do
  has "$t"
done

echo "[四个选项的范围]"
for t in '「全部修复」是「建议修复」表里的全部条目' '「只修重点」是其中的 🔴 和 🔶' \
  '「只修核心」是其中的 🔴' '「全不修复」一条也不修' '四个选项都不含「不建议修」表里的条目'; do
  has "$t"
done

echo "[选项名带的等级图标]"
for t in '前三个选项名后面带全角括号' '这次没有出现的等级不写' \
  '「全部修复（🔴🔶🔷）」「只修重点（🔴🔶）」「只修核心（🔴）」' \
  '没有 🔷 时第一项是「全部修复（🔴🔶）」'; do
  has "$t"
done

echo "[去掉选项的规则]"
for t in '某个选项这次一条都修不到（如没有 🔴 时的「只修核心」），去掉它' \
  '「只修重点」和「只修核心」修的范围相同（只有 🔴 和 🔷 时），去掉「只修重点」' \
  '某个选项和排在它前面的选项修的范围相同（如没有 🔷 时的「只修重点」），去掉它' \
  '「全不修复」始终保留，Recommended 标在剩下的第一个选项上' \
  '写在等级括号后面，如「全部修复（🔴🔶🔷）(Recommended)」'; do
  has "$t"
done

echo "[其他与选定后的去向]"
for t in '用户选「其他」时按输入的编号取（如 `1,3,A`，可含「不建议修」表的字母编号）' \
  '成立的条目为 0 → 不提问，输出总结行与「不建议修」表，跳到「收尾」。' \
  '选「全不修复」→ 跳到「收尾」。否则用 Skill 工具调用 `revise`' \
  '把选中项一次全部传入' \
  '删除本次的 `<cache_dir>/ocr/<branch>.json`（存在时），进 4.3。'; do
  has "$t"
done

echo "[旧选项名清除]"
for t in '修全部 🔴🔶' '只修 🔴' '建议项全修' '都不修'; do lacks "$t"; done

echo ""
echo "通过 ${PASS}，失败 ${FAIL}"
[[ "$FAIL" -eq 0 ]]
