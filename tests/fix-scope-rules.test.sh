#!/usr/bin/env bash
# 同根因位置规则校验：revise 修问题前搜同根因位置并分三种处理、code-constraints 把它们划进必改范围、impl-engineer 表外发现只上报
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

REVISE=bb-spec-workflow/skills/revise/SKILL.md
CC=bb-spec-core/skills/code-constraints/SKILL.md
IMPL=bb-spec-workflow/agents/impl-engineer.md

echo "[revise：搜索时机、范围与三种处理]"
for t in '**同根因搜索**' '去向是转 `/prd` 的跳过' '同一个文件里的另一种缺陷不算' \
  '每个用到这段代码的代码仓库都搜' '**一起修**' '**不用修**' '**另开需求**' \
  '用 AskUserQuestion 只问这一处' '通报后直接进步骤 3'; do
  has "$REVISE" "$t"
done

echo "[revise：诊断模板]"
for t in '## 同根因位置（去向是转 /prd 时不写这一节）' '| # | 位置 | 类别 | 处理 | 理由 |' \
  '共 N 处：一起修 A 处，不用修 B 处，另开需求 C 处。' \
  '同根因位置：搜过了，没有其他位置（搜了：<函数名或关键词>）'; do
  has "$REVISE" "$t"
done

echo "[revise：授权、测试、提交、多处合并、简报]"
for t in '改它们不用另外请用户批准' '**用户一次报了多处**' '根因相同的合并成一个问题' \
  '每个位置至少一个先失败的用例' '全部改动进同一次本地 commit' \
  '（用户报的那一处和全部「一起修」位置合计）' \
  '- 同根因位置：共 N 处，修了 A 处，不用修 B 处，另开需求 C 处'; do
  has "$REVISE" "$t"
done

echo "[revise：旧用词清除]"
for t in '兄弟位点' '主位点' '多位点同类问题'; do lacks "$REVISE" "$t"; done

echo "[code-constraints：同根因位置属必改范围]"
for t in '修问题时，同根因位置属于必须改的范围' '同根因位置在清单之内，改它们不用另外批准' \
  '由派工方核实后并入本轮'; do
  has "$CC" "$t"
done

echo "[impl-engineer：表外同根因位置只上报]"
for t in '### 表外同根因位置（无则写"无"）' '不自己改，在报告「表外同根因位置」小节写明'; do
  has "$IMPL" "$t"
done

echo "[revise：搜索范围、核实与分歧处理]"
for t in '调用了出问题的那段代码，或读了出问题的那份数据，会受同一个缺陷影响' \
  '在别处独立写了同样的错误写法' '出问题的代码所在的整个仓库' \
  '搜到的每个位置都读过代码再下结论' '本轮不改它，其他位置照常修' \
  '根因不同的各自诊断、各搜各的' 'Review Agent 逐个位置给结论' \
  '主 agent 读代码核实，成立的补进步骤 2 的表' '另开需求的逐条列位置和原因'; do
  has "$REVISE" "$t"
done

echo "[revise：停下提问条件、表范围、派工与提交]"
for t in '仅三种情况停下：期望行为本身有分歧' \
  '仅三种情况停下：附「冲突分析简报」时等用户裁决方向' \
  '某个同根因位置有多种合理修法、用户看到的结果不同时，只就这一处提问' \
  '在通报诊断结果之后、进步骤 3 之前，用 AskUserQuestion 只问这一处' \
  '位置在另一个仓库、且要两边协调着改的也算' \
  '用户报的那一处不进表、不算在内' \
  '逐个位置写出受影响的行为和入口场景（不传 `文件:行号`，它看不到实现路径）' \
  '全部改动进同一次本地 commit（多仓库时每个仓库各一次）' \
  '走轻量修复、主 agent 自己改时发现表外位置'; do
  has "$REVISE" "$t"
done
for t in '为它们再派一轮 Test → Impl → Review' '合计超出轻量修复条件的改走三 Agent 流程'; do has "$REVISE" "$t"; done
lacks "$REVISE" '仅两种情况停下'

echo "[code-constraints：表外同根因位置上报]"
has "$CC" '同一个文件里的另一种缺陷不算，清单没列到的同根因位置按 R3.3 上报'

PRD_REVIEWER=bb-spec-workflow/agents/prd-reviewer.md
PRE_REVIEWER=bb-spec-workflow/agents/pre-reviewer.md
EXEC=bb-spec-workflow/skills/exec/SKILL.md
GIT_PUSH=bb-spec-workflow/skills/git-push/SKILL.md

echo "[prd-reviewer：同类位置搜索与报告]"
for t in '7. **同类位置**' '都要在变更文件之外搜整个仓库' '同类位置：已搜，无' \
  '代码纪律违规和 DESIGN.md 对照的问题不搜' '只列出，不修改' '  - 同类位置：' \
  '并附上变更文件之外的同类位置' '**不修改任何文件、不操作 git**'; do
  has "$PRD_REVIEWER" "$t"
done

echo "[pre-reviewer：测试缺口]"
for t in '找到实现、找不到测试 = 测试缺口' '不计入违规，不影响 PASS|FAIL' '## 测试缺口（无则写"无"）'; do
  has "$PRE_REVIEWER" "$t"
done

echo "[exec：同类位置核实与测试缺口当轮补]"
for t in '**同类位置**：Review 报告里每条问题下的「同类位置」' '**测试缺口当轮补**' \
  '补出来的测试直接通过算补完' '这 N 条测试缺口当轮补不了，怎么办？' \
  '选项依次是"不补"（说明：简报里记下没补和原因）、"换个办法补"（说明：你告诉我用什么办法测）' \
  '除此之外「待解决」里不留测试缺口' '- 同类位置：<核实成立并已修 N 处' \
  '给 Test Agent 传受影响的行为和入口场景，不传 `文件:行号`' \
  '同类位置和测试缺口跟着上面 impl-defect 的那一次自修一起做，不另算次数'; do
  has "$EXEC" "$t"
done

echo "[revise：Review 结果处理与测试缺口]"
for t in '> **处理 Review 结果**' '成立的补进步骤 2 的「同根因位置」表' \
  '这 N 条测试缺口当轮补不了，怎么办？' \
  '选项依次是"不补"（说明：简报里记下没补和原因）、"换个办法补"（说明：你告诉我用什么办法测）' \
  '除此之外「待解决」里不留测试缺口' '给 test-engineer 传受影响的行为和入口场景，不传 `文件:行号`'; do
  has "$REVISE" "$t"
done

echo "[git-push：测试缺口分流]"
for t in 'PASS 且「测试缺口」为无 → 跳到 4.5.3' 'PASS 但有测试缺口' '和全部测试缺口作为参数传入'; do
  has "$GIT_PUSH" "$t"
done

echo "[审查后补：exec 的自修次数、并行范围与回归]"
for t in 'Review 只报了测试缺口、没有 ❌ 时，直接按本段补，不进归因' \
  '按 impl-defect 在这一次自修里改实现' \
  '同类位置落在同组其他 plan 的目录里时，等那个 plan 做完再修' \
  '和这次为同类位置、测试缺口新加或改过用例的测试文件' \
  '修复后回归再加上这次新加或改过用例的测试文件' \
  '那个 plan 被标 blocked 的，这个位置记为本 plan 的阻塞项' \
  '补测试时每个位置至少一个用例' \
  '不成立的在完成简报「同类位置」一行写明位置和理由' \
  '⚠️「实现合规但测试未覆盖」和「遗漏」一节的条目' \
  '把这几条交 Review Agent 复查'; do
  has "$EXEC" "$t"
done
lacks "$EXEC" '改实现直到通过'

echo "[审查后补：revise 的测试缺口来源与不成立位置的去处]"
for t in '以及 `/git-push` 分支自查传来的「测试缺口」' \
  '按 impl-defect 改实现直到通过' \
  '把这几条交 prd-reviewer 复查' \
  'Review 报的同类位置核实不成立的算进「不用修」' \
  '不成立的写进完成简报「同根因位置」一行的「不用修」' \
  '⚠️「实现合规但测试未覆盖」和「遗漏」一节的条目' \
  '**传进来的只有测试缺口**' \
  '直接按步骤 3「处理 Review 结果」补测试'; do
  has "$REVISE" "$t"
done
lacks "$REVISE" '不成立的同类位置（位置 + 理由）'

echo "[审查后补：git-push 读测试缺口一节；prd-reviewer 两类位置]"
has "$GIT_PUSH" '`## 违规项` → `## 测试缺口` → `## 备注`'
has "$GIT_PUSH" '测试缺口交 /revise 补上'
has "$PRD_REVIEWER" '调用了出问题的那段代码、会受同一缺陷影响的位置；别处独立写的同样错误写法'
has "$PRD_REVIEWER" '  - 同类位置：写法同上一条'

echo ""
echo "通过 ${PASS}，失败 ${FAIL}"
[[ "$FAIL" -eq 0 ]]
