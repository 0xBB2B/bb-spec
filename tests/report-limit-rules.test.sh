#!/usr/bin/env bash
# 子代理报告长度上限规则校验：五个子代理定义写明上限与细节文件，四个流程 SKILL 写明给目录、用报告、收尾清理
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

skill_cat() {
  cat "$1" || return
  case "$1" in
    */skills/git-push/SKILL.md|*/skills/prd/SKILL.md|*/skills/revise/SKILL.md)
      local r
      for r in "$(dirname "$1")"/references/*.md; do
        if [ -f "$r" ]; then cat "$r"; fi
      done ;;
  esac
  return 0
}

has() {
  local file="$1" text="$2"
  if grep -rqF -- "$text" "$(skill_scope "$PL/$file")" 2>/dev/null; then pass; else fail "${file} 缺少：${text}"; fi
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

has_after() {
  local file="$1" heading="$2" text="$3"
  if skill_cat "$PL/$file" 2>/dev/null | awk -v h="$heading" 'found { print } index($0, h) == 1 { found = 1 }' | grep -F -- "$text" >/dev/null; then
    pass
  else
    fail "${file} 中「${heading}」之后缺少：${text}"
  fi
}

line_of() {
  grep -nF -- "$2" "$PL/$1" 2>/dev/null | head -1 | cut -d: -f1 || true
}

before() {
  local file="$1" first="$2" second="$3" a b
  a="$(line_of "$file" "$first")"
  b="$(line_of "$file" "$second")"
  if [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]; then pass; else fail "${file} 中「${first}」应出现在「${second}」之前"; fi
}

AG=bb-spec-workflow/agents
SK=bb-spec-workflow/skills
AGENTS="$AG/test-engineer.md $AG/impl-engineer.md $AG/prd-reviewer.md $AG/pre-reviewer.md $AG/webview-test-runner.md"

echo "[子代理定义：报告长度小节内容]"
for f in $AGENTS; do
  for t in '## 报告长度' '报告不超过 800 字符' '全文不超过 3,000 字符' \
    '通过或合规的条目只报数量，不逐条列出' '只展开有问题的条目' \
    '字符数按报告正文算，标点和空白都算' '细节文件：<完整路径>' \
    '没有细节可写时不建文件' 'reports_dir'; do
    has "$f" "$t"
  done
done

echo "[子代理定义：reports_dir 为空]"
for f in $AGENTS; do
  lacks "$f" '为空时用'
  has "$f" '{reports_dir} 为空时不建细节文件'
done
for f in $AG/prd-reviewer.md $AG/pre-reviewer.md; do
  has "$f" '和缓存目录的 `.gitignore`'
done

echo "[子代理定义：必须留在正文的内容]"
for f in $AGENTS; do
  has "$f" '新建或改动的文件路径、「方案问题」小节（没有就写"无"）、有问题条目的 `文件:行号`'
done

echo "[子代理定义：小节顺序]"
for f in $AGENTS; do
  before "$f" '## 报告长度' '## 安全基线'
done

echo "[只读子代理：唯一可写文件]"
for f in $AG/prd-reviewer.md $AG/pre-reviewer.md; do
  has "$f" '唯一可以写的是'
done

echo "[exec / revise / git-push：子代理报告处理]"
for s in exec revise git-push; do
  for t in '**子代理报告**' '${CACHE_DIR}/reports/' '报告超过上限照常使用，不退回重写' \
    '只读需要的那一段，不整份读入' '收尾时删掉本次产生的细节文件'; do
    has "$SK/$s/SKILL.md" "$t"
  done
done

echo "[test-webview：子代理报告处理]"
for t in '**子代理报告**' '${CACHE_DIR}/reports/' '删掉本次产生的细节文件'; do
  has "$SK/test-webview/SKILL.md" "$t"
done

echo "[报告模板：不逐条列通过项]"
lacks "$AG/prd-reviewer.md" '- ✅ 约束 1'
lacks "$AG/prd-reviewer.md" '- ✅ R1.1'
lacks "$AG/test-engineer.md" '<每条 PRD 约束对应的测试用例名>'
lacks "$AG/pre-reviewer.md" '- ✅ <约束 / 验收>'

echo "[无「方案问题」小节的子代理]"
for f in $AG/prd-reviewer.md $AG/pre-reviewer.md $AG/webview-test-runner.md; do
  has "$f" '（「方案问题」小节只在模板里有这一节时才写）'
done

echo "[webview-test-runner：报告字段不新增]"
lacks "$AG/webview-test-runner.md" '- steps:'

echo "[流程收尾步骤里删细节文件]"
has_after "$SK/test-webview/SKILL.md" '### 步骤 6' '细节文件'
has_after "$SK/revise/SKILL.md" '### 步骤 4' '删掉 `${CACHE_DIR}/reports/` 下本次产生的细节文件'
has_after "$SK/git-push/SKILL.md" '## 4.5' '删掉 `${CACHE_DIR}/reports/` 下本次产生的细节文件'
lacks "$SK/git-push/SKILL.md" '自查通过（PASS）后，删掉'
has "$SK/git-push/SKILL.md" '自查结束后（不管结论是 PASS 还是 FAIL）'

echo
echo "通过：${PASS}，失败：${FAIL}"
[ "$FAIL" -eq 0 ]
