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

section_text() {
  local path="${3:-$PL}/$1" heading="$2" body r
  body="$(awk -v h="$heading" '
    BEGIN { n = 0; while (substr(h, n + 1, 1) == "#") n++ }
    /^```/ { fence = !fence; if (found) print; next }
    !fence && found && match($0, /^#+ /) && RLENGTH - 1 <= n { exit }
    !fence && index($0, h) == 1 { found = 1 }
    found { print }
  ' "$path" 2>/dev/null || true)"
  [ -n "$body" ] || return 1
  printf '%s\n' "$body"
  while IFS= read -r r; do
    if [ -f "$(dirname "$path")/$r" ]; then cat "$(dirname "$path")/$r"; fi
  done < <(printf '%s\n' "$body" | grep -o 'references/[A-Za-z0-9_.-]*\.md' | sort -u || true)
}

has_after_rc() {
  section_text "$1" "$2" "${4:-}" | grep -F -- "$3" >/dev/null
}

has_after() {
  if has_after_rc "$1" "$2" "$3"; then pass; else fail "${1} 中「${2}」这一节缺少：${3}"; fi
}

lacks_after() {
  local body
  if ! body="$(section_text "$1" "$2")"; then fail "读不到 ${1} 中「${2}」这一节"; return; fi
  if printf '%s\n' "$body" | grep -F -- "$3" >/dev/null; then fail "${1} 中「${2}」这一节不应含：${3}"; else pass; fi
}

line_of() {
  awk -v h="$2" 'index($0, h) == 1 { print NR; exit }' "${3:-$PL}/$1" 2>/dev/null || true
}

before_rc() {
  local a b
  a="$(line_of "$1" "$2" "${4:-}")"
  b="$(line_of "$1" "$3" "${4:-}")"
  [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]
}

before() {
  if before_rc "$1" "$2" "$3"; then pass; else fail "${1} 中标题「${2}」应出现在标题「${3}」之前"; fi
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
has_after "$SK/revise/SKILL.md" '### 步骤 5' '删掉 `${CACHE_DIR}/reports/` 下本次产生的细节文件'
lacks_after "$SK/revise/SKILL.md" '### 步骤 4' '删掉 `${CACHE_DIR}/reports/` 下本次产生的细节文件'
has_after "$SK/git-push/SKILL.md" '## 4.5' '删掉 `${CACHE_DIR}/reports/` 下本次产生的细节文件'
lacks "$SK/git-push/SKILL.md" '自查通过（PASS）后，删掉'
has "$SK/git-push/SKILL.md" '自查结束后（不管结论是 PASS 还是 FAIL）'

echo "[prototype-designer：报告长度]"
PD="$AG/prototype-designer.md"
for t in '## 报告长度' 'reports_dir' \
  '没有待用户确认的问题：报告不超过 800 字符' '有待用户确认的问题：报告不超过 3,000 字符' \
  '字符数按报告正文算，标点和空白都算' '细节文件：<完整路径>' '没有细节可写时不建文件' \
  '{reports_dir} 为空时不建细节文件' '确认内容清单不算在上限内'; do
  has "$PD" "$t"
done
lacks "$PD" '为空时用'
before "$PD" '## 报告长度' '## 安全基线'

echo "[prototype：子代理报告处理]"
for t in '**子代理报告**' '${CACHE_DIR}/reports/' '报告超过上限照常使用，不退回重写' '删掉本次产生的细节文件'; do
  has "$SK/prototype/SKILL.md" "$t"
done

echo "[辅助函数自检]"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/$SK/revise/references" "$T/$AG"

expect() {
  local want="$1" desc="$2" rc=0
  shift 2
  "$@" || rc=$?
  if { [ "$want" = ok ] && [ "$rc" -eq 0 ]; } || { [ "$want" = bad ] && [ "$rc" -ne 0 ]; }; then pass; else fail "自检：${desc}"; fi
}

REV="$SK/revise/SKILL.md"
DEL='删掉 `${CACHE_DIR}/reports/` 下本次产生的细节文件'
printf '%s\n' '### 步骤 4' "$DEL" '### 步骤 5' '收尾' > "$T/$REV"
expect ok "删除句在步骤 4 一节内应通过" has_after_rc "$REV" '### 步骤 4' "$DEL" "$T"
printf '%s\n' '### 步骤 4' '收尾' '### 步骤 5' "$DEL" > "$T/$REV"
expect bad "删除句挪到下一节应失败" has_after_rc "$REV" '### 步骤 4' "$DEL" "$T"
printf '%s\n' '### 步骤 5' "$DEL" > "$T/$REV"
expect bad "找不到标题应失败" has_after_rc "$REV" '### 步骤 4' "$DEL" "$T"

printf '%s\n' '### 步骤 4' '走到这一步先读 `references/a.md`' '### 步骤 5' > "$T/$REV"
printf '%s\n' "$DEL" > "$T/$SK/revise/references/a.md"
printf '%s\n' '无关' > "$T/$SK/revise/references/b.md"
expect ok "这一节提到的 references 文件内容算在范围内" has_after_rc "$REV" '### 步骤 4' "$DEL" "$T"
printf '%s\n' '### 步骤 4' '走到这一步先读 `references/b.md`' '### 步骤 5' > "$T/$REV"
expect bad "这一节没提到的 references 文件不算" has_after_rc "$REV" '### 步骤 4' "$DEL" "$T"

printf '%s\n' '### 步骤 4' '收尾' > "$T/$REV"
printf '%s\n' "$DEL" > "$T/$SK/revise/references/c.md"
expect bad "最后一节没提到的 references 文件里有删除句应失败" has_after_rc "$REV" '### 步骤 4' "$DEL" "$T"
printf '%s\n' '### 步骤 4' '```bash' '# 注释' '```' "$DEL" '### 步骤 5' > "$T/$REV"
expect ok "代码块里的注释行不结束这一节" has_after_rc "$REV" '### 步骤 4' "$DEL" "$T"

A="$AG/x.md"
printf '%s\n' '前言 提到 ## 安全基线 字样' '## 报告长度' '正文' '## 安全基线' '正文' > "$T/$A"
expect ok "正文里含标题字样的句子不干扰标题顺序" before_rc "$A" '## 报告长度' '## 安全基线' "$T"
printf '%s\n' '## 安全基线' '## 报告长度' > "$T/$A"
expect bad "标题顺序反了应失败" before_rc "$A" '## 报告长度' '## 安全基线' "$T"
printf '%s\n' '前言 提到 ## 安全基线 字样' '## 报告长度' > "$T/$A"
expect bad "只有正文提到、没有标题行应失败" before_rc "$A" '## 报告长度' '## 安全基线' "$T"

echo
echo "通过：${PASS}，失败：${FAIL}"
[ "$FAIL" -eq 0 ]
