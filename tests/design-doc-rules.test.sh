#!/usr/bin/env bash
# DESIGN.md 模板结构校验
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

summary
