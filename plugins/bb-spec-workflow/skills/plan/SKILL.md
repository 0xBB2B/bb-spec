---
name: plan
description: 读 spec + 项目代码结构产出函数级实施计划——启动即 EnterPlanMode 只读对齐、批准后才落盘到 .bb-spec/docs/plan/<日期>.<主题>/；启动先 worktree 感知定位 plan 现场（主仓库停在 main 时自动定位到进行中的 worktree）；过程式只到函数级，声明式产物（DDL/API 契约/配置）必须内联完整成品。触发：/plan、生成实施计划、怎么落地这些 spec。跳过：还没 spec（→/spec）、spec 无变更。
---

# Plan 实施计划生成

读取 spec + 项目代码结构，产出**自包含、分文件、函数级**的实施计划。`/spec` 输出"做什么"，`/plan` 输出"怎么做"。可引用 spec `name` 溯源，但**必须内联复述**相关规则，禁"详见 spec"式弱引用。

## 核心原则（兼反面案例）

1. **方案先对齐再落盘**：启动即 `EnterPlanMode`，全流程只读对齐，`ExitPlanMode` 批准后才落盘（❌ 一进来就写文档）
2. **一文一单元**：每份 plan 只解决一个独立实施问题（❌ 一份同涉数据库/业务/HTTP 三层）
3. **自包含可执行**：仅凭该文件 + 项目现有代码即可正确编码（❌ "先完成 plan A 才能理解本文档"）
4. **过程式代码只到函数级**：写函数名 + 文件路径 + 职责，**不写参数签名和函数体**（❌ 写参数/返回类型/实现）
5. **声明式产物写成品**：SQL DDL/迁移、API 契约（OpenAPI/proto/路由表）、配置文件等"成品即设计"的内容，**必须内联最终成品**——完整代码块、带注释（如字段 COMMENT、索引说明），exec 阶段原样落盘（❌ 把 `CREATE TABLE` 压成"两张新建表：字段 A、B、C…"的散文转述）
6. **尊重现有代码**：基于真实代码路径和命名风格，非凭空设计
7. **按关注点拆分**：一个 spec 可对应多个 plan，按实施关注点拆（❌ 一对一固定映射）
8. **单文件 ≤ 200 行**（不含 frontmatter 与声明式成品代码块），超过则拆分
9. **可断点恢复**：进度持久化到 `PROGRESS.md`，跨会话 / `/clear` 后从断点继续（❌ 执行时不读/不更新）

## 输出目录与命名

格式：`{DOCS_DIR}/plan/<YYYY-MM-DD>.<主题>/<序号>-<名称>.md`。`<主题>`：取 git 分支名（去 `feature/`、`fix/` 等前缀）；`<序号>`：两位数字（`01-`、`02-`…）表执行顺序；`<名称>`：kebab-case 关注点描述。禁扁平放在 `plan/` 根目录。

**文件体系**：

| 文件 | 职责 | 规模 |
|---|---|---|
| `plan/INDEX.md` | 主题目录 + 状态 | < 50 行 |
| `plan/<主题>/INDEX.md` | 主题内阶段分组 + plan 列表 + 依赖 | < 30 行 |
| `plan/<主题>/PROGRESS.md` | 执行断点唯一事实源，跨会话 / `/clear` 后据此恢复 | — |

## 工作流

> 步骤 0~3 在 plan 模式内（只读对齐），步骤 4~8 在 plan 模式外（落盘 + commit）。

### 步骤 0a：进入 plan 模式

**立即调用 `EnterPlanMode`**。后续 0~3 步全在只读态完成。

### 步骤 0b：定位 plan 现场 + 读取配置 + 识别 spec 变更

**先定位 plan 现场（worktree 感知）**：git-workflow 默认用 worktree 隔离开发——spec 变更随功能分支落在 `~/.bb-spec/worktrees/` 下的某棵 worktree，主仓库目录始终停在 main。`/clear` 后新会话打开的往往是主仓库目录，直接把 cwd 当 plan 现场会得到空 diff，误判「无需 plan」终止。所以读任何文件前先跑：

```bash
git branch --show-current
git worktree list --porcelain
```

- **已在 linked worktree 或非 main/master 功能分支** → cwd 即 plan 现场，继续
- **在主仓库且 HEAD 为 main/master** → 逐棵检查非 main 分支的 worktree（`${DOCS_DIR}` 按该 worktree 内 `.bb-spec.yaml` 解析，缺省 `.bb-spec`）：spec 有变更（`git diff main...HEAD -- '${DOCS_DIR}/spec/'` 非空）的即候选：
  - 恰一棵 → 它就是 plan 现场，**后续所有步骤——读 spec、产出 plan、更新索引、commit——全部定位到该 worktree 内执行**（`cd` 进去或全程用其绝对路径）
  - 多棵 → AskUserQuestion 列出让用户选
  - 无 → 全新任务，按 git-workflow 先确定开分支方式再继续，**禁止把 plan 文档落在 main 工作区**

现场确定后，在**该目录**下 `cat .bb-spec.yaml 2>/dev/null` 取 `base_dir`（缺省 `.bb-spec`）；`${DOCS_DIR}` = `<base_dir>/docs`。运行 `git diff main...HEAD --name-status -- '${DOCS_DIR}/spec/'`：

- **非 git / 无 main / spec 目录不存在**：告知"建议先运行 `/spec`"，`ExitPlanMode` 终止
- **diff 空**：告知"无 spec 变更，无需 plan"，`ExitPlanMode` 终止
- **有变更**：A 读 spec 正文；M 读正文 + `git diff` 聚焦变更；D 用 `git show main:<path>` 读旧内容做清理计划。同时读 `spec/INDEX.md` 了解全局

### 步骤 1：摸清项目现状

技术栈（`go.mod` / `package.json` / `Cargo.toml`）→ 目录结构（`find` 或 codegraph）→ 可复用基础设施 → 命名风格。新项目跳过已有代码分析，按 spec 技术约束推断结构。

**代码 vs Spec 冲突检测**：步骤 0b/1 不一致时，在步骤 3 之前列冲突，每条附简报——「代码现状 vs Spec 定义」、「保留代码 / 遵循 spec 各自理由」、「**建议方向** + 一句话理由」、「**代价**：改动范围与风险」，由用户裁决。

### 步骤 2：拆分策略 + 根源质检

按层 → 按功能 → 按横切关注点拆分。宁可多拆小文件，简单 spec（< 5 函数）可合并。

呈现前自问：① 是否最优实施路径？② 是否触及根源（非绕过既有不合理设计）？③ 有无 spec 未要求的过度设计？

### 步骤 3：呈现待批方案 → ExitPlanMode

呈现：
- **拆分方案**：文件名 + 一句话描述 + 阶段分组 + 依赖
- **新增第三方依赖**（**单独成节，必列**）：每项写「库名 + 用途 + 版本策略」；版本策略写选版规则（如「最新稳定版」「最新 LTS」）而非具体版本号，具体版本号由 exec 落盘前经官方渠道查询；无新增则显式写「无」。**批准即授权**：用户批准 ExitPlanMode 即视为对该清单的明确同意（version-policy 要求的新增第三方库同意流程在此一次完成），exec 阶段引入依赖不得超出该清单
- 同时盘点已有 plan（读 `${DOCS_DIR}/plan/INDEX.md`），指出冲突 / 可复用 / 需修订项

调用 `ExitPlanMode`。批准后进入步骤 4；驳回则在 plan 模式内调整后重新呈现。

### 步骤 4：产出 plan 文档

每份含 frontmatter + 正文六块（见下方模板）。**函数清单**：函数名 + 文件路径 + 职责一句话 + 调用关系 + 外部接口依赖；**不写**参数列表、返回值、实现；命名风格与项目一致。**验证方式**：必须写出 Test Agent 可见的稳定测试契约，包括公开入口、输入、预期输出或副作用、错误场景；不得要求读取函数清单或实现路径才能写测试。**成品定义**：涉及声明式产物（SQL DDL/API 契约/配置）时增设该块，直接给出可落盘的最终内容，exec 阶段原样使用、不得改写。**新增第三方依赖**：把已批清单中归属本 plan 的依赖写入该块（库名 + 用途 + 版本策略），exec 引入新库以此为界；本 plan 无新增则省略该块。

### 步骤 5：更新索引与进度文件

- **主题 INDEX.md**：每条 `- [<name>](<文件名>) — <description>`；`## <阶段>` 分组；依赖标 `[依赖: <name>]`
- **根 INDEX.md**：表格 主题|概述|状态|完成时间；已完成主题仅作历史审计，AI 未经允许不得读取
- **PROGRESS.md**：所有步骤初始标 `pending`

### 步骤 6：自检

- [ ] 步骤 0a~3 全程在 plan 模式内，未提前落盘？拆分质检 3 项全过？
- [ ] 每份 plan ≤ 200 行（成品代码块除外），函数清单无参数和实现，验证方式含 Test Agent 可见的稳定测试契约，声明式产物已内联成品而非散文转述，无"详见 spec"式引用？
- [ ] 新增第三方依赖已在待批方案中单独成节（无则写「无」）并获批，已批项逐条落入对应 plan 文档？
- [ ] 索引 / PROGRESS 已同步？

### 步骤 7：本地 commit

先 `git branch --show-current` 确认分支（**在 main 上则跳过自动 commit**，提示按 git-workflow 先建分支）；只提交本次涉及文件（plan 文档 + 索引 + PROGRESS）；message 遵循仓库历史风格（先 `git log --oneline -10`），不硬编码类型前缀；**仅本地不自动 push**。

### 步骤 8：完成简报

```
## Plan 完成简报
- 主题：<YYYY-MM-DD.主题>
- 产出：N 份 plan，分 M 个阶段
- 文件清单：<序号>-<名称>.md — <一句话描述>
- Spec 变更覆盖：<已覆盖全部 / 未覆盖项列表>
- 待解决：<问题列表 / 无>
- 下一步：运行 `/exec <主题>` 开始实施（plan↔exec 上下文强关联，建议同窗口）
```

## 模板

**单文档模板**：

```markdown
---
name: <kebab-case，与文件名一致>
description: <一句话概括，≤ 80 字>
---
# <实施单元标题>
## 目标
<一句话：完成后系统具备什么能力>
## 业务规则（来源：spec）
<内联复述 spec 规则 3-10 行，标 spec name 溯源但内容自包含>
## 涉及文件
<路径，每行标"新建"或"修改">
## 成品定义（仅声明式产物时存在）
<SQL DDL / API 契约 / 配置的最终成品：完整代码块 + 注释，exec 原样落盘>
## 新增第三方依赖（仅本 plan 引入新库时存在）
| 库名 | 用途 | 版本策略 |
|---|---|---|
| `<module/pkg>` | 一句话 | 最新稳定版 / 最新 LTS |
## 函数清单
### <文件路径>
| 函数名 | 职责 |
|---|---|
| `FuncA` | 一句话 |
## 协作关系
<函数调用关系 + 外部依赖（DB/MQ/第三方 API）>
## 验证方式
- 测试入口：<公开命令/API/Hook/页面操作/包级可调用入口；不写内部实现路径>
- 测试输入：<参数、请求、文件、环境或前置数据>
- 预期结果：<输出、状态变化、副作用或错误响应>
- [ ] <验证项>
```

**根 INDEX.md**：

```markdown
# Plan 索引
| 主题 | 概述 | 状态 | 完成时间 |
|---|---|---|---|
| [<主题-A>](YYYY-MM-DD.<主题-A>/INDEX.md) | <基础设施> | 进行中 | — |
| [<主题-B>](YYYY-MM-DD.<主题-B>/INDEX.md) | <领域> | 已完成 | YYYY-MM-DD |
```

**主题 INDEX.md** + **PROGRESS.md**：

```markdown
# <主题名> 实施计划
## 阶段 1：基础设施
- [project-bootstrap](01-project-bootstrap.md) — 脚手架与基础依赖
## 阶段 2：核心业务
- [domain-types](02-domain-types.md) — 领域模型 [依赖: project-bootstrap]
```

```markdown
# 执行进度
| 序号 | Plan | 状态 | 完成时间 |
|---|---|---|---|
| 01 | project-bootstrap | done | 2026-05-25 |
| 02 | domain-types | in-progress | — |
## 当前
正在执行 `02-domain-types.md`：函数清单 3/5。
## 阻塞
（无）
```
