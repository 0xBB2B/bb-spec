#!/usr/bin/env bash
# 调查子代理规则校验：子代理定义、三个流程 SKILL、AGENTS.md 来源规则、子代理数量与 README 清单
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PL="$ROOT/plugins"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

skill_scope() {
  case "$1" in
    */skills/git-push/SKILL.md|*/skills/prd/SKILL.md|*/skills/revise/SKILL.md) dirname "$1" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

has() {
  local file="$1" text="$2"
  if grep -rqF -- "$text" "$(skill_scope "$PL/$file")" 2>/dev/null; then pass; else fail "${file} 缺少：${text}"; fi
}

has_root() {
  local file="$1" text="$2"
  if grep -qF -- "$text" "$ROOT/$file" 2>/dev/null; then pass; else fail "${file} 缺少：${text}"; fi
}

lacks() {
  local file="$1" text="$2"
  local rc=0
  grep -rqF -- "$text" "$(skill_scope "$PL/$file")" 2>/dev/null || rc=$?
  case "$rc" in
    0) fail "${file} 不应含：${text}" ;;
    1) pass ;;
    *) fail "读不到 ${PL}/${file}" ;;
  esac
}

AG=bb-spec-workflow/agents
SK=bb-spec-workflow/skills
INV="$AG/code-investigator.md"

echo "[调查子代理定义]"
for t in 'model: sonnet' 'agent-type: general-purpose' '报告不超过 2,000 字符' \
  '每条结论一行并带 `文件:行号`' '没查到' '查过哪些目录、用过哪些关键词' \
  '细节文件：<完整路径>' '不修改项目文件、不操作 git' '## 安全基线'; do
  has "$INV" "$t"
done

echo "[prd / revise / exec：调查委派规则]"
for s in prd revise exec; do
  for t in '**调查交给子代理**' '不知道答案在哪个文件，或预计要读 3 个以上源码文件' \
    'bb-spec-workflow:code-investigator' \
    '要回答的问题、已知线索（功能名、相关 PRD 目录、报错文字）、项目根路径' \
    '主窗口自己读那一段（定点读）' '看 `git diff` 验收子代理的改动' '算本次实际读过的代码' \
    '先按行号定点读，确认和报告一致才能用' \
    '不一致以读到的代码为准，这条结论作废，重新调查这一点'; do
    has "$SK/$s/SKILL.md" "$t"
  done
done

echo "[prd 模板与仓库根 AGENTS.md：两种来源]"
for t in '或调查子代理本次交回的带 `文件:行号` 的结论' '还没有依据就说"还没确认"'; do
  has "$SK/prd/SKILL.md" "$t"
  has_root AGENTS.md "$t"
done

echo "[子代理数量与目录文件数一致]"
N="$(ls "$PL"/bb-spec-workflow/agents/*.md | wc -l | tr -d ' ')"
has bb-spec-workflow/.claude-plugin/plugin.json "${N} 个编排 subagent"
has_root .claude-plugin/marketplace.json "${N} 个编排 subagent"

echo "[五份 README 列出 code-investigator 且数量一致]"
for r in README.md README.en.md README.ja.md README.ko.md README.zh-TW.md; do
  has_root "$r" 'code-investigator'
  if grep -qE "(^|[^0-9])${N}[^0-9]{0,16}(subagent|サブエージェント)" "$ROOT/$r" 2>/dev/null; then pass; else fail "${r} 的子代理数量不是 ${N}"; fi
done

echo "[细节文件目录与 reports_dir]"
for s in prd revise exec; do
  has "$SK/$s/SKILL.md" '细节文件目录 `${CACHE_DIR}/reports/`'
done
has "$INV" '写进 {reports_dir} 下的一个文件'
has "$INV" '{reports_dir} 为空时不建细节文件'
has "$INV" '和缓存目录的 `.gitignore`'
lacks "$INV" '为空时用'

echo "[流程里原有读代码指令与调查分流一致]"
has "$SK/revise/SKILL.md" '实现代码按「调查交给子代理」分流'
has "$SK/revise/SKILL.md" '调查子代理交回的位置算读过'
has "$SK/revise/SKILL.md" '或调查子代理交回的结论'
lacks "$SK/prd/SKILL.md" '直接在代码里搜）'
has "$SK/prd/SKILL.md" '同样按下面的分流处理'

echo
echo "通过：${PASS}，失败：${FAIL}"
[ "$FAIL" -eq 0 ]
