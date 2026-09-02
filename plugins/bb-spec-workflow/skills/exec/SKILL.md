---
name: exec
description: 三 Agent 隔离执行 plan——每个执行组作为一次 Workflow 运行（依赖 Workflow 工具，Claude Code ≥2.1.154），组内各 plan 并发、各自串行走 Red→Green→Gate→Review，三方各只看各的输入互不可见；重试上限、依赖守卫、impl-defect 自修一次、阻塞判定全部由脚本确定性控制，agent 不 commit、不写 PROGRESS.md；组结束后主 agent 统一持久化 PROGRESS.md、逐 plan 按路径本地 commit、把阻塞项交用户裁决；跨会话/`/clear` 后从断点续接；启动先 worktree 感知定位执行现场（主仓库停在 main 时自动定位到进行中的 worktree）；commit 不自动 push、main 分支禁自动 commit。触发：/exec、开始实施 plan、继续执行 plan、从断点继续、按 plan 把代码做出来。跳过：无 Workflow 工具、还没 /plan 产出实施计划、纯调研/方案讨论、要改 spec 或 plan 本身（→/revise）。
argument-hint: <YYYY-MM-DD.主题>[/<plan名>]
---

# Exec 计划执行

三 Agent 隔离执行 plan：Test(Red) → Impl(Green) → Gate(守门) → Review(合规)。以**执行组**为单位调用 Workflow 工具，组内各 plan 并发推进、各自严格串行；组结束后主 agent 持久化 PROGRESS.md 并逐 plan commit，支持断点续接。

## 核心原则（兼硬约束）

1. **Workflow 工具**：本 skill 依赖 Workflow 工具（Claude Code ≥ 2.1.154）。当前环境工具列表中没有 Workflow → **中止**，提示用户升级 Claude Code，禁止退回主 agent 手工派工
2. **逐组执行**：一次只推进一个执行组，一组一次 Workflow 运行，整组结束、全量测试通过再进入下一组；跳组会破坏依赖关系。默认一组一个 plan，满足并行条件且用户同意时一组多个 plan 并发，组内每个 plan 的 Red→Green→Gate→Review 仍严格串行
3. **角色隔离**：Test **禁看**函数清单和实现路径，Impl **禁看** spec 原文，Review **禁止**修改文件；三份输入由主 agent 在派工前拆好、各自内嵌进对应阶段的 prompt，agent prompt 自包含、不依赖对话上下文
4. **确定性控制流**：Red 重试 ≤1 次、Green 重试 ≤1 次、impl-defect 自修 ≤1 次、清单外依赖立即阻塞、非 impl-defect 发现立即阻塞——这些判定写在 Workflow 脚本里，不由 agent 或主 agent 临场决定
5. **agent 不碰进度与 git**：Workflow 内的 agent 只产出测试与实现文件，**禁止**写 PROGRESS.md、禁止任何 git 写操作；持久化与 commit 由主 agent 在 Workflow 返回后完成
6. **进度按组持久化**：Workflow 启动前把「当前」区改为组执行中，返回后立即逐 plan 更新状态行（不攒到主题结束）；PROGRESS.md 是唯一进度事实源，重启后仅凭此文件恢复。会话在组中途中断时该组按 pending 重跑，Red 阶段会如实报告已存在的测试与行为
7. **Plan 即合同**：严格按 plan 的函数清单和业务规则实现，不自行扩展（额外需求走 `/spec` → `/plan`）；新增第三方库以 plan「新增第三方依赖」清单为上限——该清单已在 plan 批准时获用户授权，清单外需要新库时 agent 停下并以 extraDeps 上报，脚本判 blocked，由主 agent 询问用户，**禁自行 import**
8. **用户裁决只在 Workflow 外**：Workflow 内的 agent 无法向用户提问，一切需要用户判断的事项（清单外依赖、spec-defect / requirement-change、归因存疑）都以 blocked 返回，主 agent 在组结束后统一 AskUserQuestion；「接受例外」等于默许偏离 spec，**只能由用户点头，主 agent 禁自决接受**
9. **如实上报**：验证失败禁标 done；阻塞禁静默跳过——必须记录并告知用户；完成简报的计数一律取自 Workflow 返回值与完成通知，禁止手写
10. **commit 守卫**：每个 done 的 plan 做一次**本地** commit 后**禁止自动 push**；在 main 分支上**禁止自动 commit**
11. **遵守已激活 skill 约束**：exec 不重复其他 skill 的规则，但执行时必须遵守已激活约束（如 golang-testing 测试惯用法、golang-constraints 架构约束）
12. **输出中文**

## Agent 定义

四个阶段通过 Workflow 的 `agent()` 派工，`agentType` 取 plugin 注册的 subagent，数据通过 prompt 传入：

| 阶段 | agentType | 角色 |
|---|---|---|
| Red | `bb-spec-workflow:test-engineer` | 测试工程师：只读 spec 写失败测试 |
| Green | `bb-spec-workflow:impl-engineer` | 实现工程师：只看测试写最小实现 |
| Gate | `general-purpose`（effort low） | 守门员：重跑本 plan 范围测试、依赖守卫、简洁性审视，只读 |
| Review | `bb-spec-workflow:spec-reviewer` | 合规审查者：对照 spec 检查产出并逐条归因，只读 |

**信息隔离矩阵**：

| 输入 | Test | Impl | Gate | Review |
|---|---|---|---|---|
| spec 规则（plan「业务规则」区） | ✅ | ❌ | ❌ | ✅ |
| 行为预期（plan「验证方式」区） | ✅ | ❌ | ❌ | ✅ |
| 函数清单 + 文件路径 + 协作关系 | ❌ | ✅ | ✅ | ❌ |
| 成品定义（plan「成品定义」区，如有） | ❌ | ✅ | ❌ | ❌ |
| 新增第三方依赖清单（plan「新增第三方依赖」区，如有） | ❌ | ✅ | ✅ | ❌ |
| 项目约束（语言/框架/架构） | ✅ | ✅ | ❌ | ❌ |
| 项目测试惯例 | ✅ | ❌ | ❌ | ❌ |
| 本 plan 测试范围命令 | ✅ | ✅ | ✅ | ❌ |
| Test Agent 写的测试文件 | — | ✅ | ✅ | ✅ |
| Impl Agent 写的代码 | — | — | ✅ | ✅ |

## 工作流

### 步骤 0：定位执行现场 + 读取配置 + 解析参数

**先定位执行现场（worktree 感知）**：git-workflow 默认用 worktree 隔离开发——功能分支常在 `~/.bb-spec/worktrees/` 下的某棵 worktree，主仓库目录始终停在 main。新窗口/新会话打开的往往是主仓库目录，直接把 cwd 当执行现场会从 main 读 plan、把测试和实现写进 main 工作区。所以读任何文件前先跑：

```bash
git branch --show-current
git worktree list --porcelain
```

- **已在 linked worktree 或非 main/master 功能分支** → cwd 即执行现场，继续
- **在主仓库且 HEAD 为 main/master** → 逐棵检查非 main 分支的 worktree：其 plan 目录（按该 worktree 内 `.bb-spec.yaml` 解析 `base_dir`，缺省 `.bb-spec`）下存在未全完成 PROGRESS.md 的即候选（指定了主题时须匹配该主题）：
  - 恰一棵 → 它就是执行现场，**后续所有步骤——读 plan、Workflow 内 agent 的读写与命令、commit——全部定位到该 worktree 内执行**（主 agent 全程用其绝对路径，并把该路径作为 `SITE` 写进 Workflow 脚本）
  - 多棵 → AskUserQuestion 列出让用户选
  - 无 → 全新任务，按 git-workflow 先确定开分支方式再继续，**禁止把任何产出落在 main 工作区**

现场确定后，在**该目录**下 `cat .bb-spec.yaml 2>/dev/null` 取 `base_dir`（缺省 `.bb-spec`）；`${DOCS_DIR}` = `<base_dir>/docs`。读 `${DOCS_DIR}/plan/INDEX.md`，按参数形式决定行为：

| 调用方式 | 行为 |
|---|---|
| `/exec` | 自动选主题 → 从第一个非 `done` 步骤起依次执行到最后 |
| `/exec <YYYY-MM-DD>.<主题>` | 指定主题 → 从第一个非 `done` 步骤起依次执行到最后 |
| `/exec <YYYY-MM-DD>.<主题>/<plan名>` | 指定主题 + 单个 plan，只执行该 plan（单 plan 的一组） |

**主题定位**（无参数或仅指定主题时）：INDEX.md 不存在 → 告知"建议先运行 `/plan`"终止；无 `进行中` 主题 → 告知"所有主题已完成"终止；仅一个 `进行中` → 自动选中；多个 → 列出让用户选。

### 步骤 1：确定执行范围

读 `PROGRESS.md`（不存在则初始化，所有步骤标 `pending`）。

- **指定了单个 plan**：直接跳到该 plan 执行，不影响其他步骤状态
- **未指定**：展示进度概况（已完成 N/M 步），**直接全部执行**——从第一个非 `done` 步骤依次到最后，不询问用户（用户若想只跑某一步，应在调用时显式带 `/<plan名>`）

**并行编组**（仅未指定单个 plan 时）：读主题 `INDEX.md` 的 `## <阶段>` 分组与 `[依赖: <name>]` 标注，把待执行步骤切成执行组。多个 plan 编入同一组须**同时**满足两条：

- **互不依赖**：彼此不在对方依赖链上，且各自依赖的 plan 均已 `done`
- **文件目录不重叠**：各自「函数清单」的文件路径落在不同目录——同目录即同编译单元，一个 plan 的半成品会让同组其他 plan 一起编译失败

存在可编组的多个 plan 时，AskUserQuestion 询问用户：首选项「并行执行这 N 个：<plan 列表>」，另一选项「逐个串行」。选串行则整个主题按序号逐个执行。无可编组时不询问，直接逐个执行。这是 Workflow 启动前唯一的交互点。

### 步骤 2：组装输入并调用 Workflow

**2a. 拆输入**：读当前组每个 plan 的 `.md`，按隔离矩阵拆出 `rules`（业务规则）、`verification`（验证方式）、`functions`（函数清单 + 文件路径 + 协作关系）、`artifacts`（成品定义，无则空串）、`deps`（新增第三方依赖清单，无则「无」）；再根据函数清单的文件路径写出 `testScope`——只跑本 plan 涉及包 / 目录的测试命令（如 `go test ./internal/xxx/...`），**禁写全量命令**——同组其他 plan 此刻可能仍在 Red，全量结果无法判定本 plan 是否通过。同时扫描项目已有测试文件，提取测试惯例（框架、目录、命名风格、一段示例）写成 `TESTING`；把语言 / 框架 / 架构约束写成 `PROJECT`。

**2b. 预写进度**：PROGRESS.md「当前」区改为「组 N 执行中（Workflow）：<plan 列表>」。

**2c. 调用 Workflow**：**不使用 `args` 传参**（大对象经 args 易被序列化成字符串导致脚本取不到字段），数据直接内嵌进脚本顶部。内嵌长文本用模板字符串时注意转义内容中的 `` ` `` 与 `${`。

读取本 skill 目录下的 `references/exec-group.js`（Skill 加载时给出的 Base directory 之下），把顶部 `SITE` / `PROJECT` / `TESTING` / `PLANS` 四个常量替换为组装好的值，整段作为 `script` 传入。脚本契约：

- **输入**：`PLANS` 每项 `{ name, rules, verification, functions, artifacts, deps, testScope }`，字段含义同 2a
- **控制流**：每个 plan 独立走 Red（≤1 次重试）→ Green + Gate（≤1 次重试；extraDeps 非空立即阻塞）→ Review（零发现 → done；全部 impl-defect 且未自修 → 补 Red → Green → Gate → 复审一次；含 spec-defect / uncertain → 阻塞）；组内各 plan 并发，`parallel` 收口
- **返回**：`{ results, stats }`。`results` 每项 `{ plan, status: done|skipped|blocked, stage, reason, testFiles, implFiles, review, retries, selfRepaired }`；`stats` 为 `{ total, done, skipped, blocked, selfRepaired }`

### 步骤 3：处理返回值并持久化

Workflow 返回后按 `results` 逐 plan 处理，**每处理完一个就更新 PROGRESS.md 对应状态行**：

- **done** → 状态行标 `done` + 完成时间；随后把该 plan 产出做一次**本地** commit：先 `git branch --show-current` 确认分支（**在 main 上则跳过自动 commit**并提示按 git-workflow 先建分支）；按 `testFiles` + `implFiles` + `PROGRESS.md` 逐一 `git add`——工作区含同组其他 plan 的产出与半成品，**禁 `git add .` / `git add -A`**；message 遵循仓库历史风格（先 `git log --oneline -10`）、不硬编码类型前缀；**仅本地不自动 push**。`selfRepaired` 为 true 的 plan 在「当前」区如实记一笔并计入完成简报
- **skipped**（行为已存在）→ 状态行标 `done` 并在完成时间列注「行为已存在」，不 commit
- **blocked** → 状态行标 `blocked`、「阻塞」区记 `stage` + `reason`，按 `stage` 分流：
  - **Green 且 reason 为清单外依赖** → AskUserQuestion 让用户选 **批准**（先把库名补录进该 plan「新增第三方依赖」清单，再以 `/exec <主题>/<plan名>` 重跑）/ **拒绝**（保持 blocked，等用户改 plan）
  - **Review 且存在 spec-defect / uncertain** → 先向用户展示 `review.findings` 中的归因与证据，AskUserQuestion 让用户选 **修复** / **接受例外**（记录到 PROGRESS.md 并标 `done`）/ **暂停**（保持 blocked）。选「修复」时按类型走：spec-defect → 改 spec → 级联 plan → 以 `/exec <主题>/<plan名>` 重新 TDD；requirement-change → 用户确认新需求 → 更新 spec → 级联 plan + 重跑
  - **其余**（Red 失败、Green 重试后仍不过、自修后仍违规）→ 保持 blocked，把 `reason` 原文告知用户等待指示

### 步骤 4：循环或收尾

- **单个 plan 模式**：当前 plan 处理完即停，输出完成简报
- **全部执行 + 还有后续组**：整组处理完（含阻塞项）后跑一次全量测试确认组内产出无交叉破坏，再回步骤 2 推进下一组——下一组可能依赖本组产出
- **全部执行 + 全部完成**：① 更新根 `plan/INDEX.md`，该主题状态改 `已完成` 填完成时间 ② 运行全量测试确认无回归 ③ **归档确认**：已删除的 spec 已从 `spec/INDEX.md` 移除、spec 内容与实现一致 ④ 把收尾改动做一次本地 commit（守卫同步骤 3）⑤ 输出完成简报

组内单个 plan 阻塞**不中断整组**——脚本已让其余 plan 跑完各自流水线，主 agent 照常为它们持久化并 commit，阻塞项汇总进完成简报。

**完成简报格式**（单个 plan 模式和全部完成均用；计数取自 `stats` 与各 `results` 项，消耗行取自 Workflow 完成通知里的 agents / tokens / 时长）：

```
## Exec 完成简报
- 主题：<YYYY-MM-DD.主题>
- 执行范围：<全部 N 步 / 单步 plan-name>
- 执行方式：<逐个串行 / 并行组：<组内 plan 列表>>
- 完成情况：成功 N 步 / 跳过 M 步 / 阻塞 K 步（自修 S 步）
- 消耗：<agents 数> agents / <tokens> / <时长>
- 变更文件：实现<路径> / 测试<路径>
- 测试结果：✅ 全量通过 / ❌ 失败列表
- Review 结论：✅ 全部合规 / ⚠️ 已接受的例外列表
- 待解决：<阻塞项（stage + reason）/ 已接受的例外 / 无>
- 下一步：<如"运行 /review 做最终审查" / "继续执行剩余步骤" / 前端主题："**运行 `/test-webview` 跑一遍网页交互验收**" / "无">
```

## PROGRESS.md 操作规范

**初始化**（步骤 1）：

```markdown
# 执行进度
| 序号 | Plan | 状态 | 完成时间 |
|---|---|---|---|
| 01 | <name-from-index> | pending | — |
| 02 | <name-from-index> | pending | — |
## 当前
准备执行 `01-<name>.md`。
## 阻塞
（无）
```

**更新**（步骤 2b 与步骤 3）：只改三处——状态行、"当前"区、"阻塞"区，不重写整个文件。Workflow 启动前"当前"区写组执行中及 plan 列表；返回后逐 plan 单独更新其状态行，并把"当前"区改为下一组或收尾。
