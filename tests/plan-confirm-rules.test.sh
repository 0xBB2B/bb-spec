#!/usr/bin/env bash
# plan 技术变更确认规则校验：有技术变更先简报再弹窗确认、没有则先 commit 再运行 /exec；impl-engineer 把数据格式列入成品定义
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." >/dev/null && pwd)"
WF="$ROOT/plugins/bb-spec-workflow"
PASS=0
FAIL=0

source "$(dirname "$0")/lib/md.sh"

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

has() {
  local file="$1" text="$2"
  if grep -qF -- "$text" "$WF/$file" 2>/dev/null; then pass; else fail "${file} 缺少：${text}"; fi
}

lacks() {
  local file="$1" text="$2"
  local rc=0
  grep -qF -- "$text" "$WF/$file" 2>/dev/null || rc=$?
  case "$rc" in
    0) fail "${file} 不应含：${text}" ;;
    1) pass ;;
    *) fail "读不到 ${WF}/${file}" ;;
  esac
}

PLAN=skills/plan/SKILL.md
IMPL=agents/impl-engineer.md

echo "[plan：技术变更判定与确认流程]"
for t in '**技术变更**指 plan 新增或修改以下四类东西之一' \
  '- 数据格式：程序读写的文件格式、消息格式等' \
  '不按 plan 有没有「成品定义」段判断' \
  '### 步骤 7：判定技术变更' \
  '### 步骤 8：技术变更清单 + 弹窗确认' \
  '### 步骤 9：本地 commit + 自动执行' \
  '- 技术变更清单（N 项，/exec 会照成品定义原样写进项目）：' \
  '- 下一步：请按上面 N 项的 文件:行号 打开 plan 阅读成品定义，在弹窗里确认' \
  'header 写「技术变更」' \
  '我已阅读上面技术变更清单（N 项）指向的成品定义，plan 通过并开始执行吗？' \
  '| 已阅读，通过并执行（标推荐） | 提交 plan，然后自动跑 /exec → /doc-update；表、接口、数据格式、配置照 plan 里的成品定义原样写进项目 | 进步骤 9 |' \
  '| 需要修改 | 告诉我哪一项要改，改完重新自检、重新列清单、重新弹窗确认 |' \
  '选项 1 的说明开头换成「提交 PRD 改动和 plan」' \
  '所以先改 PRD、再改 plan。' \
  '「本轮修改：」' \
  '「PRD 改动：<PRD 文件完整路径>」' \
  '用户选「已阅读，通过并执行」之前，不 commit plan、不运行' \
  '- 技术变更清单：无' \
  '「✓ 已 commit plan：<commit 号> <标题>」' \
  '「✓ 已 commit PRD 改动和 plan（同一个 commit）：<commit 号> <标题>」' \
  '**有技术变更先确认**' \
  '数据格式（程序读写的文件格式、消息格式等）' \
  '声明式产物（SQL DDL/API 契约/数据格式/配置）' \
  '<SQL DDL / API 契约 / 数据格式 / 配置的最终成品' \
  '写 plan 前要引入新技术时单独弹窗问用户'; do
  has "$PLAN" "$t"
done
for t in '**产出即执行**' '唯一停顿点是需要引入新技术' '只在需要引入新技术时停下问用户' \
  '### 步骤 8：简报 + 自动执行' '### 步骤 7：本地 commit' '- 文件清单：<序号>-<名称>.md — <一句话描述>'; do
  lacks "$PLAN" "$t"
done

echo "[plan：修改循环的边界和清单格式]"
for t in 'description: <一句话概括，≤ 80 字>' \
  '这次确认流程里改过本分支 PRD、改动还没提交时，选项 1 的说明开头换成「提交 PRD 改动和 plan」' \
  '用户最终不要这项新技术 → 回到本节第 1 步' \
  '改完后没有技术变更了，清单写一行「技术变更清单：无」' \
  '只重新取清单和行号，不按步骤 7 的分流走' \
  '1. [<类别>] <名字> — 新增' \
  '「第 N 项 <名字> — <改了什么>」' \
  '用户在「其他」里直接写意见时，按「需要修改」处理' \
  '新技术已在步骤 3 单独确认，不算技术变更' \
  '「下一步」写「请在弹窗里确认」，弹窗问题写「plan 通过并开始执行吗？」'; do
  has "$PLAN" "$t"
done
for t in '6. 改完后没有技术变更了 → 进步骤 9' '本轮改过 PRD 时'; do lacks "$PLAN" "$t"; done
n="$(grep -c '^description: 读本分支 PRD' "$WF/$PLAN" 2>/dev/null || true)"
if [[ "$n" == 1 ]]; then pass; else fail "plan/SKILL.md 里技能描述应只出现 1 次（frontmatter），实际 ${n} 次"; fi

echo "[plan：按节断言，提交和调用 /exec 只在步骤 9，确认只在步骤 8]"
S7="$(md_section "$WF/$PLAN" '### 步骤 7：判定技术变更')"
S8="$(md_section "$WF/$PLAN" '### 步骤 8：技术变更清单 + 弹窗确认')"
S9="$(md_section "$WF/$PLAN" '### 步骤 9：本地 commit + 自动执行')"

sec_has() {
  local name="$1" body="$2" text="$3"
  if [[ -z "$body" ]]; then fail "${name} 截不到"; return; fi
  if grep -qF -- "$text" <<<"$body"; then pass; else fail "${name} 缺少：${text}"; fi
}

sec_lacks() {
  local name="$1" body="$2" text="$3"
  if [[ -z "$body" ]]; then fail "${name} 截不到"; return; fi
  if grep -qF -- "$text" <<<"$body"; then fail "${name} 不应含：${text}"; else pass; fi
}

for t in 'Skill bb-spec-workflow:exec' 'git commit' 'git add' 'git branch --show-current'; do
  sec_lacks "步骤 7" "$S7" "$t"
done
for t in '没有技术变更 → 跳过步骤 8，进步骤 9' '有技术变更 → 进步骤 8'; do
  sec_has "步骤 7" "$S7" "$t"
done
for t in '这一步不 commit plan、不运行' \
  '用户选「已阅读，通过并执行」之前，不 commit plan、不运行' \
  '重新输出简报、重新弹窗' 'header 写「技术变更」'; do
  sec_has "步骤 8" "$S8" "$t"
done
for t in 'git branch --show-current' '仅本地不自动 push' 'Skill bb-spec-workflow:exec' 'git commit' 'git add'; do
  sec_lacks "步骤 8" "$S8" "$t"
done
for t in 'git branch --show-current' '仅本地不自动 push' 'Skill bb-spec-workflow:exec' '- 技术变更清单：无'; do
  sec_has "步骤 9" "$S9" "$t"
done

sec_line() {
  grep -nF -- "$2" <<<"$1" | head -1 | cut -d: -f1 || true
}

sec_order() {
  local name="$1" body="$2"; shift 2
  local prev=0 cur t
  for t in "$@"; do
    cur="$(sec_line "$body" "$t")"
    if [[ -z "$cur" ]]; then fail "${name} 找不到：${t}"; return; fi
    if (( cur <= prev )); then fail "${name} 顺序不对：${t}（第 ${cur} 行）应在上一项之后"; return; fi
    prev="$cur"
  done
  pass
}

sec_order "步骤 8" "$S8" '## Plan 完成简报' 'header 写「技术变更」'
sec_order "步骤 9" "$S9" 'git branch --show-current' '- 技术变更清单：无' '直接调用 `Skill bb-spec-workflow:exec`'

echo "[impl-engineer：成品定义含数据格式]"
has "$IMPL" '（SQL DDL/API 契约/数据格式/配置的最终内容）'
lacks "$IMPL" '（SQL DDL/API 契约/配置的最终内容）'

echo ""
echo "通过 ${PASS}，失败 ${FAIL}"
[[ "$FAIL" -eq 0 ]]
