#!/usr/bin/env bash
# git-push、prd、revise 三个 skill 的正文大小上限，以及搬到 references/ 的内容与正文的对应关系
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SK="$ROOT/plugins/bb-spec-workflow/skills"
PRD_LIMIT=18000
PRD_MAX_REFS=4
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

SKILLS=(git-push prd revise)

echo "[SKILL.md 大小：git-push、revise 不超过 12000 字节，prd 不超过 ${PRD_LIMIT} 字节]"
for s in "${SKILLS[@]}"; do
  f="$SK/$s/SKILL.md"
  if [[ ! -r "$f" ]]; then fail "读不到 $s/SKILL.md"; continue; fi
  n="$(wc -c <"$f" | tr -d ' ')"
  limit=12000
  if [[ "$s" == prd ]]; then limit="$PRD_LIMIT"; fi
  if [[ "$n" -le "$limit" ]]; then pass; else fail "$s/SKILL.md 是 ${n} 字节，超过 ${limit}"; fi
done

echo "[references 目录有 .md 文件，每个第一行以「> 用在 /」开头]"
for s in "${SKILLS[@]}"; do
  refs=()
  for r in "$SK/$s"/references/*.md; do
    if [[ -f "$r" ]]; then refs+=("$r"); fi
  done
  if [[ "${#refs[@]}" -gt 0 ]]; then pass; else fail "$s/references/ 下没有 .md 文件"; continue; fi
  for r in "${refs[@]}"; do
    first="$(head -n1 "$r")"
    if [[ "$first" == '> 用在 /'* ]]; then pass; else fail "$s/references/$(basename "$r") 第一行不是以「> 用在 /」开头"; fi
  done
done

echo "[prd/references 文件数不超过 ${PRD_MAX_REFS}]"
prd_refs=0
for r in "$SK/prd"/references/*.md; do
  if [[ -f "$r" ]]; then prd_refs=$((prd_refs + 1)); fi
done
if [[ "$prd_refs" -le "$PRD_MAX_REFS" ]]; then pass; else fail "prd/references 有 ${prd_refs} 个 .md 文件，超过 ${PRD_MAX_REFS}"; fi

echo "[正文指到的 references 路径都存在]"
for s in "${SKILLS[@]}"; do
  f="$SK/$s/SKILL.md"
  paths="$(grep -o 'references/[A-Za-z0-9._-]*\.md' "$f" 2>/dev/null | sort -u || true)"
  if [[ -z "$paths" ]]; then fail "$s/SKILL.md 没有指向 references/ 的路径"; continue; fi
  while IFS= read -r p; do
    if [[ -f "$SK/$s/$p" ]]; then pass; else fail "$s/SKILL.md 指向的 $p 不存在"; fi
  done <<<"$paths"
done

echo "[每个 references 文件名都在正文里出现]"
for s in "${SKILLS[@]}"; do
  for r in "$SK/$s"/references/*.md; do
    [[ -f "$r" ]] || continue
    b="$(basename "$r")"
    if grep -qF -- "$b" "$SK/$s/SKILL.md" 2>/dev/null; then pass; else fail "$s/SKILL.md 没有提到 $b"; fi
  done
done

echo "[正文含「走到这一步先读」]"
for s in "${SKILLS[@]}"; do
  if grep -qF -- '走到这一步先读' "$SK/$s/SKILL.md" 2>/dev/null; then pass; else fail "$s/SKILL.md 缺少：走到这一步先读"; fi
done

echo "[正文仍含核心段落标题]"
has_skill() {
  local s="$1" text="$2"
  if grep -qF -- "$text" "$SK/$s/SKILL.md" 2>/dev/null; then pass; else fail "$s/SKILL.md 缺少：${text}"; fi
}
has_skill git-push '## 禁止操作'
has_skill prd '## 核心原则'
has_skill revise '## 核心原则'
has_skill revise '## 三类归因'

echo "[prd 每次都走的步骤全文留在正文]"
for t in '### 步骤 0：读取配置 + 现状扫描' '**重叠判定**' '### 步骤 2：质疑（对用户可见）' '有没有更便宜的替代' \
  '### 步骤 3：澄清与发散' '**怎么呈现选项**' '### 步骤 4：收敛与拆解' '### 步骤 5：方案质检' '是否可证伪' \
  '## 四样东西各管什么' '**一条约束放哪**'; do
  has_skill prd "$t"
done

echo "[正文仍含前三份需求加的段落标题]"
for t in '**子代理报告**' '**跑脚本**'; do has_skill git-push "$t"; done
has_skill prd '**调查交给子代理**'
for t in '**子代理报告**' '**调查交给子代理**' '**跑脚本**'; do has_skill revise "$t"; done

# 只读 SKILL.md：从以 $2 开头的标题行到下一个同级或更高级标题之前（不含）
skill_section() {
  awk -v start="$2" '
    BEGIN { n = 0; while (substr(start, n + 1, 1) == "#") n++ }
    found && match($0, /^#+ /) && RLENGTH - 1 <= n { exit }
    index($0, start) == 1 { found = 1 }
    found { print }
  ' "$SK/$1/SKILL.md" 2>/dev/null || true
}

section_has() {
  local s="$1" head="$2" text="$3" body
  body="$(skill_section "$s" "$head")"
  if [[ -z "$body" ]]; then fail "$s/SKILL.md 找不到标题：${head}"; return; fi
  if printf '%s\n' "$body" | grep -F -- "$text" >/dev/null; then pass; else fail "$s/SKILL.md「${head}」一节缺少：${text}"; fi
}

echo "[先读提示放在对应步骤]"
section_has prd '### 步骤 7：落盘' 'references/write-files.md'
section_has prd '### 步骤 7：落盘' 'references/templates.md'
section_has prd '### 步骤 0：读取配置 + 现状扫描' 'references/repo-layout.md'
section_has revise '### 步骤 3' 'references/fix-by-type.md'
has_skill git-push 'references/ocr-review.md'

echo "[revise 不单独拆短文件]"
for n in verify.md route.md agent-isolation.md; do
  if [[ -e "$SK/revise/references/$n" ]]; then fail "revise/references/$n 不应存在"; else pass; fi
done

echo "[revise 正文保留每次必走的内容]"
has_skill revise '流程归属判定'
has_skill revise '写完简报后删掉 `${CACHE_DIR}/reports/` 下本次产生的细节文件'

echo "[fix-by-type.md 讲信息隔离]"
fbt="$SK/revise/references/fix-by-type.md"
if grep -qF -- '信息隔离' "$fbt" 2>/dev/null || grep -qF -- '隔离矩阵' "$fbt" 2>/dev/null; then pass; else fail "revise/references/fix-by-type.md 缺少：信息隔离 或 隔离矩阵"; fi

echo "[git-push 正文不含已搬走的核实规则]"
if grep -qF -- '照下面的规则逐条读代码核实' "$SK/git-push/SKILL.md" 2>/dev/null; then fail "git-push/SKILL.md 不应含：照下面的规则逐条读代码核实"; else pass; fi

echo "[references 每个文件不小于 600 字节]"
for s in "${SKILLS[@]}"; do
  for r in "$SK/$s"/references/*.md; do
    [[ -f "$r" ]] || continue
    n="$(wc -c <"$r" | tr -d ' ')"
    if [[ "$n" -ge 600 ]]; then pass; else fail "$s/references/$(basename "$r") 只有 ${n} 字节，不足 600"; fi
  done
done

echo ""
echo "通过 ${PASS}，失败 ${FAIL}"
[[ "$FAIL" -eq 0 ]]
