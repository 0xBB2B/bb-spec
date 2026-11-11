#!/usr/bin/env bash
# exec 重试与自修上限校验：实现重试每个 plan 最多 2 次、impl-defect 自修每个 plan 最多 2 轮，插件与测试目录里无旧上限句子
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PL="$ROOT/plugins"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

has() {
  local file="$1" text="$2"
  if grep -qF -- "$text" "$PL/$file" 2>/dev/null; then pass; else fail "${file} 缺少：${text}"; fi
}

lacks() {
  local file="$1" text="$2"
  local rc=0
  grep -qF -- "$text" "$PL/$file" 2>/dev/null || rc=$?
  case "$rc" in
    0) fail "${file} 不应含：${text}" ;;
    1) pass ;;
    *) fail "读不到 ${PL}/${file}" ;;
  esac
}

EXEC=bb-spec-workflow/skills/exec/SKILL.md
PLAN=bb-spec-workflow/skills/plan/SKILL.md

echo "[exec：实现重试]"
for t in '反馈错误给 Impl Agent 重试（每个 plan 最多 2 次）' \
  '第 2 次重试后仍失败 → 报告用户' \
  '其余不重试，直接进下方「归因」' \
  '每次重试前先在 PROGRESS.md「重试与自修」区记一条'; do
  has "$EXEC" "$t"
done

echo "[exec：impl-defect 自修轮数]"
for t in '自修**每个 plan 最多 2 轮**' \
  '每轮都是补测试(Red) → 改实现(Green) → 重新 Review' \
  '重新 Review 报出的 ❌ 无论和上一轮是不是同一条，都算在这 2 轮之内' \
  '第 2 轮后仍不过 → 标 blocked 上报用户' \
  '每轮自修开始前先在 PROGRESS.md「重试与自修」区记一条，这一轮结束后无论成败都在这一条补上结果，并计入完成简报' \
  '按 impl-defect 改实现，占 1 轮自修' \
  '同类位置和测试缺口跟着上面 impl-defect 的当轮自修一起做，不另算轮次' \
  '2 轮自修后复查仍有 ❌ 的按上面的规则标 blocked'; do
  has "$EXEC" "$t"
done

lacks "$EXEC" '「当前」区如实记一笔'
lacks "$EXEC" '这一区只追加'

echo "[exec：重试与自修记录区]"
for t in '每次实现重试、每轮自修开始前在「重试与自修」区追加一行' \
  '重试结束后在这一条补上结果' \
  '结束后在这一行补上结果' \
  '这一区已记的行不删，步骤完成时不清' \
  '只有开头、还没补结果的那一行也算用掉一次' \
  '步骤完成时只改三处' \
  '「无关发现」「重试与自修」两区随发生随记，不等步骤完成' \
  '先读出 PROGRESS.md「重试与自修」「无关发现」两区，再 `git rm -r` 删除本主题 plan 目录' \
  '断点续接时，每个 plan 已用的实现重试次数和自修轮数从「重试与自修」区读出来接着数' \
  '- 重试与自修：<每个 plan 实现重试 N 次 / 自修 M 轮（各轮结果）/ 无>' \
  '收尾删 plan 目录前先读出这一区，写进完成简报的「重试与自修」一行' \
  '## 重试与自修（每次记一条）'; do
  has "$EXEC" "$t"
done
has "$PLAN" '## 重试与自修（每次记一条）'

echo "[exec：测试缺口处理时机]"
has "$EXEC" '都在这次 Review 之后补上'
lacks "$EXEC" '都在本轮补上'

echo "[插件与测试目录：旧上限句子]"
for t in '最多 1 次' '一次自修'; do
  rc=0
  grep -rqF --exclude=exec-retry-limit.test.sh -- "$t" "$PL" "$ROOT/tests" 2>/dev/null || rc=$?
  case "$rc" in
    0) fail "plugins/ 或 tests/ 不应含：${t}" ;;
    1) pass ;;
    *) fail "搜索 ${t} 出错" ;;
  esac
done

echo ""
echo "通过 ${PASS}，失败 ${FAIL}"
[[ "$FAIL" -eq 0 ]]
