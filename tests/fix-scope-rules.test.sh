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

TEST_ENGINEER=bb-spec-workflow/agents/test-engineer.md

echo "[无关发现：exec、revise、git-push 共有]"
for f in "$EXEC" "$REVISE" "$GIT_PUSH"; do
  for t in '上面 N 条无关发现，处理哪些？' \
    '选项依次是"全部处理"（说明：在当前分支修完，进同一个 PR）、"都不处理"（说明：留在简报的待解决里）' \
    '| # | 位置 | 问题 | 不处理的后果 | 估计用时 |' \
    '**能在当前分支修的**' '**要另开需求的**' \
    '本会话里已经问过的条目不再问' '只问新的'; do
    has "$f" "$t"
  done
done

echo "[无关发现：exec、revise 共有]"
for f in "$EXEC" "$REVISE"; do
  for t in '**发现时只记不改**' '标"未验证"并写怎么验证' \
    '两段都为空 → 简报写「无关发现：无」，不弹窗' '只有「要另开需求的」有内容 → 不弹窗' \
    '不新开分支' '标明要走 `/prd`' '- 无关发现：<见下方清单 / 无>'; do
    has "$f" "$t"
  done
done

echo "[无关发现：exec]"
for t in '## 无关发现' '⑥ 输出完成简报 ⑦ 按下方「无关发现」弹窗' \
  '一次全部交 `Skill bb-spec-workflow:revise`'; do
  has "$EXEC" "$t"
done

echo "[无关发现：revise]"
for t in '### 无关发现' '**被 `/exec`、`/git-push` 调用时**' '不是用户直接输入的' \
  '本流程不弹窗' '**用户直接调用时弹一次窗**'; do
  has "$REVISE" "$t"
done

echo "[无关发现：git-push]"
for t in '## 4.6 无关发现（推送之前问一次）' '修完重跑 4.3 全量测试' '**合并之后才发现的**' \
  '进同一个 PR' '→ **无关发现一次问**' '→推送前把无关发现合成一张清单一次问→推送'; do
  has "$GIT_PUSH" "$t"
done
c46=$(grep -c -- '^## 4\.6 ' "$PL/$GIT_PUSH" 2>/dev/null || true)
c5=$(grep -c -- '^## 5\. 推送到远程$' "$PL/$GIT_PUSH" 2>/dev/null || true)
n46=$(grep -n -- '^## 4\.6 ' "$PL/$GIT_PUSH" 2>/dev/null | head -1 | cut -d: -f1 || true)
n5=$(grep -n -- '^## 5\. 推送到远程$' "$PL/$GIT_PUSH" 2>/dev/null | head -1 | cut -d: -f1 || true)
if [[ "$c46" == 1 && "$c5" == 1 && -n "$n46" && -n "$n5" && "$n46" -lt "$n5" ]]; then pass; else fail "git-push 中 ## 4.6 应在 ## 5. 推送到远程 之前（4.6 行=${n46:-无}，5 行=${n5:-无}）"; fi

echo "[无关发现：code-constraints]"
has "$CC" '记进产出报告的「无关发现」小节'
has "$CC" '由派工方收尾时合成清单一次问用户'
lacks "$CC" '提出后续单独处理'
lacks "$CC" '列清单写入产出报告，经用户批准后再清'

echo "[无关发现：子代理报告小节]"
has "$IMPL" '### 无关发现（无则写"无"）'
has "$TEST_ENGINEER" '### 无关发现（无则写"无"）'
has "$PRD_REVIEWER" '## 无关发现（无则写"无"）'

echo "[审查后补：无关发现的边界、多仓库、弹窗后的记录]"
for f in "$EXEC" "$REVISE"; do
  has "$f" '同根因位置和 Review 报告的「同类位置」不算'
  has "$f" '能在当前分支修的：修代码错误、清过期内容、改不准的文档。要另开需求的：要新增功能，或要改变已有功能的行为'
  has "$f" '用户在「其他」里填编号（如 `1,3`）时只取这几条'
  has "$f" '弹窗之后把它们补进完成简报的「待解决」'
  has "$f" '收尾把无关发现合成一张清单一次问'
done
has "$EXEC" '改按下方「全部完成」收尾，只在第 ⑦ 步弹窗'
has "$REVISE" '跟在完成简报后面'
for t in '还没验证的推测标"未验证"并写怎么验证' \
  '能在当前分支修的：修代码错误、清过期内容、改不准的文档。要另开需求的：要新增功能，或要改变已有功能的行为' \
  '多仓库时把各仓库的无关发现合成一张清单，只问一次' \
  '把选中的条目一次全部传入' \
  '修完重跑 4.3 全量测试和 4.5 分支自查' \
  '重新生成 PR 草稿（含 `Requirement:` 行）' \
  '在 `/git-push` 结束时的回复里列进「待解决」' \
  '步骤 8 清理完之后' \
  '修完再运行一次 `/git-push`' \
  '4.6 的无关发现各仓库合成一张清单只问一次'; do
  has "$GIT_PUSH" "$t"
done
lacks "$GIT_PUSH" '写进最后的总结'

echo "[无关的安全 / 鲁棒性 / 性能问题也只记不改]"
has "$CC" '唯一例外是本次改动涉及的代码里的安全性 / 鲁棒性 / 性能修复'
has "$CC" '和本次问题无关的安全性 / 鲁棒性 / 性能问题同样记进「无关发现」'
lacks "$CC" '唯一例外是安全性 / 鲁棒性 / 性能修复'
for f in "$EXEC" "$REVISE" "$GIT_PUSH"; do has "$f" '无关的安全性、鲁棒性、性能问题也算'; done

echo "[复查后补：边界、断点续接、合并后的选项]"
PLAN=bb-spec-workflow/skills/plan/SKILL.md
has "$CC" '本次改动涉及的代码里的安全性 / 鲁棒性 / 性能问题按 R3.3 处理'
for f in "$EXEC" "$REVISE"; do
  has "$f" '子代理和 Review 报告「无关发现」小节里的都算'
  lacks "$f" 'Review 报告里的都算'
done
has "$EXEC" '记的同时写进 PROGRESS.md 的「无关发现」区'
has "$EXEC" '收尾删 plan 目录前先读出来'
has "$EXEC" '## 无关发现（发现一条记一条）'
has "$PLAN" '## 无关发现（发现一条记一条）'
has "$GIT_PUSH" '用户在「其他」里填编号（如 `1,3`）时只取这几条'
has "$GIT_PUSH" '下文说的简报，指 `/git-push` 结束时的那条回复'
has "$GIT_PUSH" '所有选中的条目进同一个新 PR'
has "$GIT_PUSH" '"全部处理"的说明改成"开一个新分支修完，进同一个新 PR"'
has "$GIT_PUSH" '各仓库都走到 4.6 再统一问，问完才推送'

echo "[分支自查后补]"
for f in "$EXEC" "$REVISE"; do has "$f" '用户在哪天定的'; done
has "$REVISE" '理由带那段代码的 `文件:行号`'
has "$REVISE" '要新增设计、或要改变用户原本想要的行为才能修'
has "$REVISE" '诊断阶段仅三种情况停下：期望行为本身有分歧'
has "$REVISE" '诊断阶段仅三种情况停下：附「冲突分析简报」时等用户裁决方向'
has "$REVISE" '它们也补进步骤 2 的表，处理写「不用修」'
has "$REVISE" '并由主 agent 逐个位置核对'
has "$EXEC" '只报了测试缺口、没有 ❌ 的，直接按下方「测试缺口当轮补」处理'

echo ""
echo "通过 ${PASS}，失败 ${FAIL}"
[[ "$FAIL" -eq 0 ]]
