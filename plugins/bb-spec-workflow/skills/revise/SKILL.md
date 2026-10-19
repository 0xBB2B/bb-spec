---
name: revise
description: 产出修订（诊断→定向修正→回归验证）——对 PRD→plan→exec 偏差做根因归类：prd-defect / impl-defect / requirement-change；先读代码确认现状、经 git 标记查回相关 PRD 再归因；改代码必先 Red 测试、最小影响只改必须改的层；需求变了（prd-defect / requirement-change）只在本分支 PRD 上改，相关 PRD 已合并或没有 PRD 时退出转 /prd 新开一份；bug、安全、鲁棒性修复留在本流程，修订原因与决策写进 commit 正文；完成后自动 /doc-update 收尾模式；启动先 worktree 感知定位修复现场（主仓库停在 main 时自动定位到进行中的 worktree）。触发：/revise、有 bug、结果不对、和预期不符、产出需要优化、review 发现违规需修复。跳过：纯新增需求、改已合并功能或老代码的行为（→/prd）、还没有 PRD/代码可对照。
argument-hint: <问题或优化诉求描述>
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/*)
---

# 产出修订（Revise）：诊断 → 定向修正 → 回归验证

对 PRD→plan→exec 流水线产出与预期的偏差做**根因归类 → 定向修正 → 回归验证**，覆盖修 bug、产出优化、需求变更三类场景。所有 review 发现问题需修正时，统一走此流程。

> 仅处理"对既有产出的修正"。与对错无关的**纯新增需求**走 `/prd`，不进本流程。用户要的行为变了（再小也算，例如把超时从 120 秒改成 600 秒、把按钮文字从'提交'改成'保存'），而相关 PRD 已合并或没有 PRD 时，同样走 `/prd` 新开一份，让这次的取舍写进新 PRD 的决策记录。

## 核心原则（兼硬约束）

1. **先读代码再诊断**：现状以代码为准；诊断前必须读出问题相关的实现与测试，给出 `文件:行号`，禁止凭 PRD 或函数名推断现状
2. **先诊断再修正**：禁止跳过归因直接改代码；诊断结果必须向用户通报（不阻断——通报后直接进入步骤 3），仅当期望行为本身有分歧、需附「冲突分析简报」时停下等用户裁决
3. **三类归因**：每个问题必须归入 prd-defect / impl-defect / requirement-change 之一
4. **TDD 修正**：涉及代码修改时必须先有失败测试（Red）再改实现（Green），测试须能暴露 bug
5. **PRD 改不改看是否合并**：本分支新增的 PRD 可改（判定：`${CLAUDE_PLUGIN_ROOT}/scripts/branch-prds.sh <基线分支>` 输出的 `new=` 行里有它；不在 `new=` 里的都已合并）；已合并的 PRD 冻结不改——需求层的问题（prd-defect / requirement-change）退出转 `/prd`；只有 impl-defect 留在本流程，期望行为以用户确认为准，修订原因写进 commit 正文，`git log -L` 会把它和代码一起找出来
6. **修正闭环**：修正后必须验证——全量测试通过 + 期望行为合规 + 文档同步
7. **决策必须落盘**：修订过程中定下的取舍——步骤 0 带入的讨论结论、冲突分析简报的裁决、3c 的确认问答——写明选了什么、否掉了哪些做法及理由、由谁在哪天定的；改了本分支 PRD 时记进它的「决策记录」；没改 PRD 时（impl-defect）写进 commit 正文的「决策」段，这是它唯一的记录处
8. **最小影响**：只改必须改的层，不借修正之名扩展功能或重构（额外需求走 `/prd`）
9. **plan 只在执行期间存在**：`/exec` 完成后会删除整个 plan 主题目录，`${DOCS_DIR}/plan/` 下 `PROGRESS.md` 含非 `done` 行、且未登记在根 `plan/INDEX.md`（旧版本留下的索引）里的才是进行中的 plan，允许原地修正以保证断点续接；找不到对应 plan 说明已完成，修复由本流程直接驱动、不新建 plan
10. **三 Agent 串行强制派发**：涉及代码修改时必须按 Test → Impl → Review 顺序派 `bb-spec-workflow:test-engineer` / `bb-spec-workflow:impl-engineer` / `bb-spec-workflow:prd-reviewer` 三个 subagent，**禁止主 agent 自己写测试、写实现、做合规检查**；唯一例外是「轻量修复判断」（见步骤 3）通过且用户同意后允许主 agent 直接 TDD 修复
11. **Agent 隔离同 exec**：Test 不看实现，Impl 不看 PRD，Review 只读不写
12. **输出中文**

## 三类归因

| 类型 | 含义 | 修复起点 |
|---|---|---|
| **prd-defect** | PRD 或 plan 没有正确描述用户要的行为（写错、写漏、互相矛盾） | 本分支 PRD → 改 PRD（含决策记录）→ 级联 plan → TDD；已合并 PRD → 退出转 `/prd` 新开一份 |
| **impl-defect** | 期望行为描述正确，实现不符合 | 补测试(Red) → 改实现(Green) → 验证；修订原因与决策写进 commit 正文 |
| **requirement-change** | 用户现在要的行为与当初的需求不同（再小也算，例如把超时从 120 秒改成 600 秒、把按钮文字从'提交'改成'保存'） | 本分支 PRD → 确认新行为、改 PRD（含决策记录）→ 级联 plan → TDD；已合并 PRD 或没有 PRD → 退出转 `/prd` 新开一份 |

安全、鲁棒性问题（出错时崩溃、泄露、报错看不懂等 PRD 没写到的故障处理）：用户要的"别出错"没变，归 impl-defect，PRD 已合并也留在本流程；本分支 PRD 写了相关行为的，按步骤 4 第 2 条同步改。

---

## 工作流

### 步骤 0：收集问题信息

**有参数**（`$ARGUMENTS` 非空）：直接使用用户传入的问题/优化描述。
**无参数**：向用户提问（一次 2-3 个）——预期行为是什么？实际行为是什么？在哪个场景/功能下出现？

**带入之前的讨论**：同一会话里调用本流程之前已经讨论过这个问题（质疑、候选方案、用户的选择）时，把结论一并带入——选了什么、否掉了哪些做法及理由、用户在哪天定的。后面写 PRD 决策记录或 commit 正文「决策」段都以它为依据，禁止只凭 `$ARGUMENTS` 一句话重新概括。

**多位点同类问题**（输入含主位点 + 兄弟位点）：视为**一个**问题一次修完——按主位点归因，兄弟位点沿用同一归因；Test Agent 的输入列出全部位点、每个位点至少一个用例；Impl Agent 的函数清单覆盖全部位点；Review Agent 逐位点核对。禁止只修主位点、把兄弟位点留给下一轮。轻量修复判断的「≤ 1 个文件 ≤ 10 行」按全部位点合计。

### 步骤 1：定位修复现场 + 读取配置 + 定位关联资产

**先定位修复现场（worktree 感知）**：主仓库目录常年停在 main，进行中的功能分支可能在 `~/.bb-spec/worktrees/` 下的某棵 worktree 里。读任何资产前先跑 `git branch --show-current` + `git worktree list --porcelain`：

- **已在 linked worktree 或非 main/master 功能分支** → cwd 即修复现场，继续
- **在主仓库且 HEAD 为 main/master**，且问题指向某棵 worktree 上进行中的工作（其 plan PROGRESS.md 未全完成，或分支领先 main）→ 后续读资产、修代码、跑测试、commit **全部定位到该 worktree 内执行**（`cd` 进去或全程用其绝对路径）；多棵候选 → AskUserQuestion 让用户选
- **问题针对 main 上已合入的代码** → 属新修复任务，按 git-workflow 先确定开分支方式再动手，**禁止直接在 main 工作区改代码**

现场确定后，在**该目录**下运行 `${CLAUDE_PLUGIN_ROOT}/scripts/bbspec-paths.sh`，`${DOCS_DIR}` 取输出的 `docs_dir`。读项目根 `AGENTS.md`，按下表定位四层资产并全部读取：

| 资产 | 定位方式 | 目的 |
|---|---|---|
| 实现代码 | 有 `ARCHITECTURE.md` 先按模块地图定位；再按问题描述的功能名搜 `${DOCS_DIR}/prd/*/OVERVIEW.md` 的 `features:` → 在各代码仓库里 `git log --grep "Requirement: <目录名>" --name-only`；或 codegraph / grep | 确认"实际做了什么"（附 `文件:行号`） |
| 测试文件 | 测试目录 + 命名惯例 | 确认"验了什么" |
| 相关 PRD | 在函数所在仓库里对出问题的函数跑表格下方的命令（按函数名 no match 时改用行号范围 `-L <起始行>,<结束行>:<文件>`），读最新那个 commit 的 `Requirement` 行指向的 PRD 与 commit 正文（squash 合并的 commit 可能有多行，逐个读）；无标记的 commit 是接入 bb-spec 之前的老代码，没有对应 PRD | 确认"当初要的行为与为什么" |
| plan 文件 | 进行中主题的 INDEX.md（无进行中 plan 则跳过） | 确认"怎么做"的设计 |

查相关 PRD 的命令（列出改过该函数的 commit 和各自的 `Requirement` 行，最新的在前）：

```bash
git log -L :<函数>:<文件> -s --format='%h %s%n%b' | grep -e '^[0-9a-f]\{7,40\} ' -e '^Requirement:'
```

建立完整链路：**PRD 要什么 → plan 怎么做 → 代码做了什么 → 测试验了什么**。

**流程归属判定**（进步骤 2 前必做）：**满足以下任一条件应退出 revise，转 `/prd`**：

- 需要先拆解、协商或定义新协议才能落地（如"做快 auth 流程"、"打通 X 服务可观测性"、跨服务通信契约调整）
- 新增或删除子需求、改目标或非目标，或变更面横跨多个功能且涉及新设计决策
- 跨 ≥ 2 个 repo 且**不止是被动跟随的机械级联**（proto 字段改名后 consumer 跟着改属机械级联，反之属协调式）

判定退出时必须停下，提示用户改走 `/prd`，禁继续 revise 流程。

### 步骤 2：诊断归因

找不到相关 PRD（老代码）→ 先判断用户要的行为是不是代码本来就该有的：是（代码出错、安全、鲁棒性问题）→ 期望行为以用户确认为准，跳过下面第 1、2 步，从第 3 步开始；不是（要改设计、加新行为）→ requirement-change，按下方「按归因分流」转 `/prd`。

```
1. 相关 PRD 是否正确描述了用户要的行为？
   ├─ 否 → PRD 当初就写错 / 写漏 / 互相矛盾？
   │   ├─ 是 → prd-defect
   │   └─ 否（用户现在要的变了）→ requirement-change
   └─ 是 →
2. plan 是否正确翻译了 PRD？（plan 已删除则跳过）
   ├─ 否 → prd-defect
   └─ 是 →
3. 实现是否符合 PRD？
   ├─ 否 → impl-defect
   └─ 是 →
4. 测试是否覆盖了出问题的场景？
   ├─ 否（测试遗漏）→ impl-defect
   └─ 是（测试断言有误）→ impl-defect
```

**向用户通报诊断结果**（不阻断——展示后直接进入步骤 3；仅当附「冲突分析简报」时停下等用户裁决方向）：

```
## 诊断结果
- 归因：<prd-defect / impl-defect / requirement-change>
- 证据：
  - PRD 要求：<原文 + 目录名，标明本分支 / 已合并；找不到写「无，以用户确认为准」>
  - plan 说：<原文 / 已删除>
  - 代码做了：<实际行为 + 文件:行号>
  - 测试验了：<覆盖情况>
- 结论：<一句话说明哪层出了什么问题>
- 影响范围：<受影响的文件/功能列表>
- 去向：<留在 /revise / 转 /prd — 一句话原因>
```

**按归因分流**：归因为 prd-defect 且相关 PRD 已合并，或归因为 requirement-change 且相关 PRD 已合并或没有 PRD → 通报诊断结果后**停下**，提示用户改走 `/prd` 新开一份 PRD（功能名沿用原 PRD 的 `features:`），并附上诊断结果与步骤 0 带入的讨论结论，供 `/prd` 澄清时直接使用；禁继续本流程。其余情况进入步骤 3。

**冲突分析简报**（代码行为与 PRD 存在可争议分歧时附上；明确的实现 bug 无需此简报）：

```
## 冲突分析：<一句话描述>
| | 代码现状 | PRD 要求 |
|---|---|---|
| 行为 | <代码实际做了什么> | <PRD 要求做什么> |
- 保留代码：<理由——如已上线验证、覆盖了 PRD 遗漏的边界>
- 遵循 PRD：<理由——如更贴合业务意图、更安全、当前代码是历史妥协>
- **建议**：<推荐方向> — <一句话理由>
- **代价**：<选该方向的改动范围与风险>
确认修复方向后开始修复？
```

用户裁决为「保留代码」等于 PRD 写错（prd-defect）：PRD 已合并时同样按「按归因分流」停下转 `/prd`。

### 步骤 3：按类型修复

> **强制派发**：所有涉及代码修改的修复路径（除下方「轻量修复判断」通过外）**必须**通过 `Agent` 工具派 `bb-spec-workflow:test-engineer` → `bb-spec-workflow:impl-engineer` → `bb-spec-workflow:prd-reviewer` 三个 subagent 串行完成，**禁止主 agent 直接动手写测试或实现代码**。主 agent 仅做：拆分输入、按隔离矩阵传 prompt、验证每步产物、衔接下一步。

> **多 repo 派发节律**（修复涉及 ≥ 2 个 repo 时适用）：以「单 repo 的 PRD/code/test 链路」为最小派发单元，按 repo 顺序逐个走完整 Test→Impl→Review 循环，**禁止把多 repo 路径塞进一个 subagent**。全部完成后才进入步骤 4 回归验证。

**轻量修复判断**：**同时满足全部条件**时可向用户提议跳过 3-Agent 隔离直接修——归因为 impl-defect + 改动 ≤ 1 个文件 ≤ 10 行 + 修复逻辑显而易见（拼写错误、off-by-one、条件取反）。

提议话术：`"这个修复只改 <文件>，约 <N> 行，是否跳过 3-Agent 隔离直接修？"`
- 同意 → 主 agent 直接 TDD 修复（仍须先补失败测试再改实现），跳过 Agent 派发；**修代码前必须调用 `Skill code-constraints` 加载代码纪律约束并严格遵守**
- 拒绝或未回应 → 走标准流程

不满足上述条件时，**禁止提议跳过，直接走标准流程**。

下文「期望行为」指：本分支 PRD 的约束与验收；PRD 已合并或找不到相关 PRD 时，指用户在步骤 2 确认的正确行为。

#### 3a. prd-defect

> 仅本分支 PRD；已合并 PRD 的 prd-defect 已在步骤 2 转 `/prd`。

1. 编辑本分支 PRD 修正约束 / 验收 / 用例，保持约束与验收一一对应，并在「决策记录」记一条：改了什么、为什么、否掉了哪些做法
2. **检查 plan 影响**：有进行中的 plan 用到这条约束 → 原地修正其业务规则 / 验证方式，`done` 的步骤改回 `pending`；没有 → 跳过
3. **TDD 修复实现（强制三 Agent 派发）**：
   - 派 `bb-spec-workflow:test-engineer`，prompt 传「期望行为 + 验证预期 + 项目测试惯例」→ 主 agent 验证 Red
   - 派 `bb-spec-workflow:impl-engineer`，prompt 传「函数清单 + 文件路径 + 测试文件路径 + 项目约束」→ 主 agent 验证 Green
   - 派 `bb-spec-workflow:prd-reviewer`，prompt 传「期望行为 + 验证预期 + AGENTS.md 项目级约束（如有）+ 所有变更文件路径」→ 主 agent 处理 review 结果

#### 3b. impl-defect（强制三 Agent 派发）

1. 派 `bb-spec-workflow:test-engineer`，prompt 传「被违反的期望行为 + 验证预期 + 项目测试惯例」→ 主 agent 验证测试能暴露 bug（Red）
2. 派 `bb-spec-workflow:impl-engineer`，prompt 传「函数清单 + 文件路径 + 测试文件 + 项目约束」→ 主 agent 验证 Green
3. 派 `bb-spec-workflow:prd-reviewer`，prompt 传「期望行为 + 验证预期 + AGENTS.md 项目级约束（如有）+ 所有变更文件路径」→ 主 agent 处理 review 结果

#### 3c. requirement-change

> 仅本分支 PRD；PRD 已合并或没有 PRD 时已在步骤 2 转 `/prd`。

1. **确认新行为**：与用户对话明确新的期望行为（一次 2-3 个关键问题）；超出流程归属判定的范围 → 退出转 `/prd`
2. **改本分支 PRD**：同步改约束 / 验收 / 用例，并在「决策记录」记一条：新行为是什么、为什么改、否掉了哪些做法
3. **级联修复**：按 3a 步骤 2-3 执行

### 步骤 4：回归验证

1. **全量测试**：运行项目全量测试，确认无回归
2. **期望行为合规**：检查修复是否引入新的违规；修复改变了本分支 PRD 描述的任一行为而 PRD 未同步，说明归因漏判，回到 3a 补改 PRD 后才允许 commit
3. **文档同步**：调用 `Skill bb-spec-workflow:doc-update`，参数 `--tail`，让本分支 PRD 与 README、AGENTS.md 等文档追平代码；已合并的 PRD 不碰
4. **本地 commit**：先 `git branch --show-current` 确认分支（**在 main 上则跳过**并提示按 git-workflow 先建分支），只提交本次涉及文件（PRD / plan / 实现 / 测试 + doc-update 收尾改动；多仓库时各仓库分别提交，每个 commit 都带标记），message 遵循仓库历史风格（先 `git log --oneline -10`）、不硬编码类型前缀；**正文写清修订原因（改前什么行为、改后什么行为、为什么改）**；本次没改 PRD 而有取舍时再写「决策」段（改了 PRD 的取舍记在它的「决策记录」里，commit 正文写一份就重复了）：选了什么、否掉了哪些做法及理由、由谁在哪天定的（按核心原则 7 收集）；末尾单独一行带 `Requirement: <相关 PRD 目录名>`（修已合并功能写原需求目录；找不到相关 PRD 写 `none`）；**仅本地、不自动 push**

### 步骤 5：完成简报

```
## 修订完成简报
- 归因：<prd-defect / impl-defect / requirement-change>
- 根因：<一句话>
- 修改文件：PRD / plan / 实现 / 测试（各列路径，无则省略）
- 测试结果：✅ 全部通过 / ❌ 仍有失败（列出）
- 回归检查：✅ 无回归 / ⚠️ <说明>
- 待解决：<残留问题列表，无则"无">
- 下一步：<如"运行 /git-push 开 PR" / "无">
```

---

## Agent 隔离规则

修复阶段复用 exec 的三 Agent 隔离，信息边界不变：

| Agent | 可见 | 不可见 |
|---|---|---|
| Test Agent | 期望行为 + 验证预期 + 项目测试惯例 | 函数清单、实现路径、现有实现代码 |
| Impl Agent | 函数清单 + 文件路径 + 成品定义（如有）+ 测试文件 + 项目约束 | PRD 原文 |
| Review Agent | 期望行为 + 验证预期 + AGENTS.md 项目级约束（如有）+ 所有变更文件 | 不修改任何文件 |
