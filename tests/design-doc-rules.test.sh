#!/usr/bin/env bash
# DESIGN.md 模板结构，以及各规程对 DESIGN.md 的读取、传递、草稿和核对规则
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REL="plugins/bb-spec-workflow/templates/DESIGN.md"
DOC="$ROOT/$REL"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# 取以 $1 开头的标题行到下一个匹配 $2 的标题行之间的内容（含起始标题行）
section() {
  awk -v start="$1" -v stop="$2" '
    found && $0 ~ stop { exit }
    index($0, start) == 1 { found = 1 }
    found { print }
  ' "$DOC" 2>/dev/null || true
}

in_text() {
  local label="$1" text="$2" body="$3"
  if printf '%s\n' "$body" | grep -qF -- "$text"; then pass; else fail "${label} 缺少：${text}"; fi
}

summary() {
  echo ""
  echo "通过 ${PASS}，失败 ${FAIL}"
  [[ "$FAIL" -eq 0 ]]
}

echo "[DESIGN.md 存在]"
if [[ -f "$DOC" ]]; then
  pass
else
  fail "读不到 DESIGN.md 模板：$REL"
  summary
  exit 1
fi

echo "[10 个二级标题及顺序]"
HEADINGS=('## 1. 风格定位' '## 2. 颜色' '## 3. 字体与字号' '## 4. 间距' '## 5. 圆角、边框、阴影' \
  '## 6. 布局与断点' '## 7. 组件' '## 8. 动效' '## 9. 无障碍' '## 10. 终端界面')
PREV=0
for h in "${HEADINGS[@]}"; do
  N="$(grep -nxF -- "$h" "$DOC" | head -n1 | cut -d: -f1 || true)"
  if [[ -z "$N" ]]; then
    fail "缺少标题：$h"
  elif [[ "$N" -le "$PREV" ]]; then
    fail "标题顺序不对：$h"
  else
    pass
    PREV="$N"
  fi
done

echo "[开头的写法要求]"
HEAD="$(awk '/^## /{exit} {print}' "$DOC")"
for t in '不适用' '原因' '4.5:1' '3:1' '24px' '18.66px' '4 的倍数' '9999px' '形容词' 'px、ms' '按用途命名'; do
  in_text 开头 "$t" "$HEAD"
done

echo "[颜色一节]"
COLOR="$(section '## 2. 颜色' '^## ')"
in_text 颜色 '浅色' "$COLOR"
in_text 颜色 '深色' "$COLOR"
if printf '%s\n' "$COLOR" | grep -E '^\|' | grep -F '浅色' | grep -qF '深色'; then pass; else fail "颜色一节的表头应同一行含 浅色 和 深色"; fi
for t in primary on-primary background surface text text-muted border border-strong danger; do
  in_text 颜色 "| $t |" "$COLOR"
done
if printf '%s\n' "$COLOR" | grep -F '| border-strong |' | grep -qF '3:1'; then pass; else fail "border-strong 一行应写明对比度至少 3:1"; fi

echo "[圆角一节]"
in_text 圆角 '全圆角' "$(section '## 5. 圆角、边框、阴影' '^## ')"

echo "[组件一节的 6 种组件和 5 种状态]"
S7="$(grep -nxF -- '## 7. 组件' "$DOC" | head -n1 | cut -d: -f1 || true)"
S8="$(grep -nxF -- '## 8. 动效' "$DOC" | head -n1 | cut -d: -f1 || true)"
in_text 组件开头 '不适用' "$(section '## 7. 组件' '^### ')"
for c in 按钮 输入框 表格 卡片 弹窗 提示条; do
  N="$(grep -nxF -- "### $c" "$DOC" | head -n1 | cut -d: -f1 || true)"
  if [[ -n "$N" && -n "$S7" && -n "$S8" && "$N" -gt "$S7" && "$N" -lt "$S8" ]]; then
    pass
    SUB="$(section "### $c" '^#{1,3} ' | tail -n +2)"
    for s in 默认 悬停 按下 禁用 聚焦; do
      if printf '%s\n' "$SUB" | grep -qF -- "| $s |" && printf '%s\n' "$SUB" | grep -q -- "^| $s |"; then pass; else fail "${c} 缺少以 | ${s} | 开头的行"; fi
    done
  else
    fail "第 7 节组件里缺少三级标题：### $c"
  fi
done

echo "[终端界面一节]"
TERM_SEC="$(section '## 10. 终端界面' '^## ')"
for t in 颜色值 符号 表格 进度条 不适用 '[█████░░░░░] 50%  10/20'; do
  in_text 终端界面 "$t" "$TERM_SEC"
done

echo "[间距尺度都是 4 的倍数]"
SPACING="$(section '## 4. 间距' '^## ')"
SCALE="$(printf '%s\n' "$SPACING" | grep -E '^- 尺度' | head -n1 || true)"
in_text 间距尺度 '照项目实际在用的值' "$SCALE"
if [[ -z "$SCALE" ]]; then
  fail "间距一节缺少以 - 尺度 开头的行"
else
  NUMS="$(printf '%s\n' "$SCALE" | grep -oE '[0-9]+(\.[0-9]+)?' || true)"
  COUNT=0
  BAD=""
  for n in $NUMS; do
    COUNT=$((COUNT + 1))
    if [[ ! "$n" =~ ^[0-9]+$ ]] || (( n % 4 != 0 )); then BAD="$BAD $n"; fi
  done
  if [[ "$COUNT" -ge 5 ]]; then pass; else fail "尺度行至少要有 5 个数字，实际 ${COUNT} 个"; fi
  if [[ -z "$BAD" ]]; then pass; else fail "尺度行有不是 4 的倍数的数字：${BAD}"; fi
fi

echo "[组件的写法]"
S7_HEAD="$(section '## 7. 组件' '^### ')"
in_text 组件开头 '写法' "$S7_HEAD"
in_text 组件开头 'HTML 结构和类名' "$S7_HEAD"
in_text 组件开头 '代码块' "$S7_HEAD"
in_text 组件开头 'modal-header' "$S7_HEAD"
in_text 按钮写法 '主按钮、次按钮各写一份' "$(section '### 按钮' '^#{1,3} ')"
for c in 按钮 输入框 表格 卡片 弹窗 提示条; do
  SUB="$(section "### $c" '^#{1,3} ' | tail -n +2)"
  if printf '%s\n' "$SUB" | grep -q -- '^- 写法：'; then pass; else fail "${c} 缺少以 - 写法： 开头的行"; fi
done

echo "[页面框架表]"
LAYOUT="$(section '## 6. 布局与断点' '^## ')"
if printf '%s\n' "$LAYOUT" | grep -E '^\|' | grep -F '位置和尺寸' | grep -F '写法（HTML 结构和类名）' | grep -qF '不同断点下怎么变'; then pass; else fail "布局一节的表头应同一行含 位置和尺寸、写法（HTML 结构和类名）、不同断点下怎么变"; fi
in_text 布局 '不适用：<原因>' "$LAYOUT"
in_text 布局 '页面框架写法' "$LAYOUT"
for r in 顶栏 侧边栏 导航; do
  if printf '%s\n' "$LAYOUT" | grep -q -- "^| $r |"; then pass; else fail "布局一节缺少以 | ${r} | 开头的行"; fi
done

echo "[无障碍例外表]"
A11Y="$(section '## 9. 无障碍' '^## ')"
in_text 无障碍 '例外' "$A11Y"
if printf '%s\n' "$A11Y" | grep -E '^\|' | grep -F '| 项 |' | grep -F '实际值' | grep -qF '用户确认日期'; then pass; else fail "无障碍一节的例外表头应同一行含 项、实际值、用户确认日期"; fi

WF="$ROOT/plugins/bb-spec-workflow"

# 取文件 $1 里以 $2 开头的行到下一个匹配 $3 的行之间的内容（含起始行）；读不到文件时返回空
file_section() {
  awk -v start="$2" -v stop="$3" '
    found && $0 ~ stop { exit }
    index($0, start) == 1 { found = 1 }
    found { print }
  ' "$1" 2>/dev/null || true
}

frontmatter() {
  awk '/^---[[:space:]]*$/{n++; next} n==1{print} n>=2{exit}' "$1" 2>/dev/null || true
}

need_file() {
  if [[ -r "$1" ]]; then pass; else fail "读不到：${1#"$ROOT"/}"; return 1; fi
}

EXEC="$WF/skills/exec/SKILL.md"
REVISE="$WF/skills/revise/SKILL.md"
PRD="$WF/skills/prd/SKILL.md"
DOCUP="$WF/skills/doc-update/SKILL.md"
IMPL="$WF/agents/impl-engineer.md"
REVIEWER="$WF/agents/prd-reviewer.md"

echo "[exec：信息隔离矩阵和 2b、2c 传 DESIGN.md]"
if need_file "$EXEC"; then
  in_text exec矩阵 '设计规范（项目根 `DESIGN.md`' "$(file_section "$EXEC" '**信息隔离矩阵**' '^## ')"
  for step in '**2b.' '**2c.'; do
    SEC="$(file_section "$EXEC" "$step" '^\*\*2[a-z]\.|^### ')"
    for t in '改动界面代码' '有 DESIGN.md' 'DESIGN.md 路径' '没有 DESIGN.md' '不涉及界面代码' '不传'; do
      in_text "exec ${step}" "$t" "$SEC"
    done
  done
fi

echo "[revise：3a、3b 派工带 DESIGN.md、隔离规则表、提交清单]"
if need_file "$REVISE"; then
  for step in '#### 3a.' '#### 3b.'; do
    in_text "revise ${step}" 'DESIGN.md 路径' "$(file_section "$REVISE" "$step" '^#### |^### ')"
  done
  RULES="$(file_section "$REVISE" '## Agent 隔离规则' '^## [^A]')"
  for row in '| Impl Agent |' '| Review Agent |'; do
    if printf '%s\n' "$RULES" | grep -F -- "$row" | grep -qF 'DESIGN.md'; then pass; else fail "revise 隔离规则表 ${row} 一行缺少：DESIGN.md"; fi
  done
  S4="$(file_section "$REVISE" '### 步骤 4' '^### ')"
  if printf '%s\n' "$S4" | grep -E '^5\. ' | grep -qF '本次经用户同意新建或改过的 DESIGN.md'; then pass; else fail "revise 步骤 4 第 5 条缺少：本次经用户同意新建或改过的 DESIGN.md"; fi
fi

echo "[impl-engineer：inputs 和正文]"
if need_file "$IMPL"; then
  in_text impl-engineer-inputs 'design_doc' "$(frontmatter "$IMPL" | awk '/^inputs:/{f=1;next} f&&/^[^ -]/{exit} f{print}')"
  in_text impl-engineer '{design_doc}' "$(cat "$IMPL")"
  in_text impl-engineer '按它写，不用它里面没有的值' "$(cat "$IMPL")"
fi

echo "[prd-reviewer：inputs、对照指令、产出格式]"
if need_file "$REVIEWER"; then
  in_text prd-reviewer-inputs 'design_doc' "$(frontmatter "$REVIEWER" | awk '/^inputs:/{f=1;next} f&&/^[^ -]/{exit} f{print}')"
  BODY="$(cat "$REVIEWER")"
  for t in '{design_doc}' 'DESIGN.md 对照' 'file:line' '## DESIGN.md 对照' 'DESIGN.md 违规' '设计规范为空'; do
    in_text prd-reviewer "$t" "$BODY"
  done
  in_text prd-reviewer设计规范为空 '整节不写' "$(printf '%s\n' "$BODY" | grep -F '设计规范为空')"
fi

echo "[doc-update：名单、C 类、核对条目和选项]"
if need_file "$DOCUP"; then
  in_text doc-update-description 'DESIGN.md' "$(frontmatter "$DOCUP" | grep '^description:')"
  ALL="$(cat "$DOCUP")"
  if printf '%s\n' "$ALL" | grep -F 'CONTRIBUTING.md' | grep -F 'ARCHITECTURE.md' | grep -qF 'DESIGN.md'; then pass; else fail "doc-update 名单行应同时含 CONTRIBUTING.md、ARCHITECTURE.md、DESIGN.md"; fi
  in_text doc-update-C类 'DESIGN.md 对不上' "$(file_section "$DOCUP" '## 四类发现' '^---|^## [^四]' | grep -F 'code-violation')"
  for t in 'DESIGN.md 核对' '改项目约束或 DESIGN.md' '选之前两边都不改'; do
    in_text doc-update "$t" "$ALL"
  done
fi

echo "[prd：步骤 6 搬草稿、7d、简报、不做了、步骤 10 提交清单]"
if need_file "$PRD"; then
  in_text prd步骤6 '.DESIGN.draft.md' "$(file_section "$PRD" '### 步骤 6' '^### ')"
  in_text prd步骤6 '草稿存在时一起移过去' "$(file_section "$PRD" '### 步骤 6' '^### ')"
  S7D="$(file_section "$PRD" '**7d. DESIGN.md**' '^### |^\*\*7[a-z]\.')"
  for t in '**7d. DESIGN.md**' '<预览页名>.DESIGN.draft.md' '存在' '改完后的完整文件' '写完删掉草稿'; do
    in_text prd7d "$t" "$S7D"
  done
  S9="$(file_section "$PRD" '### 步骤 9' '^### ')"
  in_text prd简报 '- DESIGN.md：' "$S9"
  QUIT="$(printf '%s\n' "$S9" | grep -F '| 不做了 |')"
  in_text prd不做了 'DESIGN.md 草稿' "$QUIT"
  in_text prd不做了 '本次新建的 DESIGN.md 删掉' "$QUIT"
  in_text prd步骤10 '7d 写入的 DESIGN.md' "$(file_section "$PRD" '### 步骤 10' '^## ')"
fi

echo "[DESIGN.md 草稿和核对的闭环细节]"
W="$ROOT/plugins/bb-spec-workflow"
PRD_MD="$W/skills/prd/SKILL.md"; DU="$W/skills/doc-update/SKILL.md"; REV="$W/skills/revise/SKILL.md"
EXEC_MD="$W/skills/exec/SKILL.md"; RVW="$W/agents/prd-reviewer.md"; IMPL="$W/agents/impl-engineer.md"
line_has() {
  local label="$1" file="$2" key="$3"; shift 3
  local L; L="$(grep -F -- "$key" "$file" 2>/dev/null | head -n1 || true)"
  if [[ -z "$L" ]]; then fail "${label} 找不到含「${key}」的行"; return; fi
  for t in "$@"; do in_text "$label" "$t" "$L"; done
}
line_has prd-7a "$PRD_MD" '**7a. PRD**' '同名的 `.DESIGN.draft.md` 草稿存在时一起改名'
line_has prd-需要修改 "$PRD_MD" '| 需要修改 |' '按 7d 再写入一次'
line_has prd-原则1 "$PRD_MD" '**先对齐再落盘，读过再实施**' '和它的 DESIGN.md 草稿'
line_has prd-自检 "$PRD_MD" '- [ ] 步骤 0~5 只在' '预览页和它的 DESIGN.md 草稿'
line_has prd-不做了 "$PRD_MD" '| 不做了 |' '撤销对 AGENTS.md / CLAUDE.md / 术语表 / DESIGN.md 的改动'
line_has du-总述 "$DU" '默认认为「代码是事实」' 'DESIGN.md 例外'
line_has du-原则1 "$DU" '**代码是事实，文档追平代码**' 'DESIGN.md 除外'
line_has du-C类 "$DU" '**code-violation**' '不按 A 类改成代码的样子' '任何和代码不一致的地方都归 C 类'
line_has du-核对 "$DU" '**DESIGN.md 核对**' '文件:行号' 'DESIGN.md 里的值'
if grep -qE '^4b\.' "$DU" 2>/dev/null; then fail "doc-update 不应有行首 4b. 这种渲染不成列表的编号"; else pass; fi
line_has 审查员第6条 "$RVW" '**DESIGN.md 对照**（设计规范不为空时）' 'file:line' '算作需要修的问题'
line_has 审查员总结 "$RVW" 'PRD 合规 N/M 条' '设计规范为空时省略这一项'
in_text impl-engineer '计划或测试要求的样式值不在 DESIGN.md 里' "$(cat "$IMPL" 2>/dev/null)"
R3A="$(file_section "$REV" '#### 3a.' '^#### ')"; R3B="$(file_section "$REV" '#### 3b.' '^#### ')"
for sec in R3A R3B; do
  for who in impl-engineer prd-reviewer; do
    L="$(printf '%s\n' "${!sec}" | grep -F "bb-spec-workflow:${who}" | head -n1 || true)"
    in_text "revise-${sec}-${who}" 'DESIGN.md 路径' "$L"
  done
done
line_has exec-矩阵 "$EXEC_MD" '| 设计规范（项目根 `DESIGN.md`' '| ❌ | ✅ | ✅ |'

summary
