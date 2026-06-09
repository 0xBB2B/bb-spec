---
name: plan
description: Read the specs under .bb-spec/docs/spec/, combine them with the project's existing code structure, and produce a self-contained step-by-step implementation plan under .bb-spec/docs/plan/<YYYY-MM-DD>.<topic>/. Auto-enters Claude Code plan mode on invocation to align the split/roadmap read-only before writing files. Auto-detects requirement scale and switches into batched-roadmap mode (a multi-batch ROADMAP with dependency arrows and verification gates, lazily expanding one batch at a time) for project bootstrap or other large-scale spec drops. TRIGGER — /plan / generate an implementation plan / how to land these specs / 分批实施 / 路线图. ｜ 读取 `.bb-spec/docs/spec/` 中的规格说明，结合项目现有代码结构，在 `.bb-spec/docs/plan/<YYYY-MM-DD>.<主题>/` 下产出自包含的分步实施计划；调用时自动进入 Claude Code 的 plan 模式，先在只读态对齐拆分/分批方案，批准后才落盘。自动识别需求规模：冷启动 / 多领域 / 大批 spec 涌入时切到「分批路线图」模式，产出含依赖链和验证门的 ROADMAP，懒生成（一次只展开一批 topic），该批 exec 验证门通过后再下一批。常见触发：用户输入 `/plan`、"生成实施计划"、"怎么落地这些 spec"、"分批实施"、"路线图"。
---

# Plan 实施计划生成

读取 spec + 项目代码结构，产出**自包含、分文件、函数级**的实施计划。`/spec` 输出"做什么"，`/plan` 输出"怎么做"。可引用 spec `name` 溯源，但**必须内联复述**相关规则，禁"详见 spec"式弱引用。

## 核心原则（兼反面案例）

1. **方案先对齐再落盘**：启动即 `EnterPlanMode`，全流程只读对齐，`ExitPlanMode` 批准后才落盘（❌ 一进来就写文档）
2. **规模分流**：按变更规模走「单 topic」或「分批路线图」，不让单 topic 塞多领域（❌ 账号+计费+审核全堆一起）
3. **懒生成**：分批模式一次只展开**当前批**，其余批次仅 ROADMAP 占位（❌ 一次性写全所有批，后续批是空中楼阁）
4. **一文一单元**：每份 plan 只解决一个独立实施问题（❌ 一份同涉数据库/业务/HTTP 三层）
5. **自包含可执行**：仅凭该文件 + 项目现有代码即可正确编码（❌ "先完成 plan A 才能理解本文档"）
6. **函数级详细**：写函数名 + 文件路径 + 职责，**不写参数签名和函数体**（❌ 写参数/返回类型/实现）
7. **尊重现有代码**：基于真实代码路径和命名风格，非凭空设计
8. **按关注点拆分**：一个 spec 可对应多个 plan，按实施关注点拆（❌ 一对一固定映射）
9. **单文件 ≤ 200 行**（不含 frontmatter），超过则拆分
10. **可断点恢复**：进度持久化到 `PROGRESS.md`，token 耗尽后从断点继续（❌ 执行时不读/不更新）

## 输出目录与命名

格式：`{DOCS_DIR}/plan/<YYYY-MM-DD>.<主题>/<序号>-<名称>.md`。`<主题>`：单 topic 取 git 分支名（去 `feature/`、`fix/` 等前缀），分批模式取批次领域名（kebab-case、与 spec 子目录同名）；`<序号>`：两位数字（`01-`、`02-`…）表执行顺序；`<名称>`：kebab-case 关注点描述。禁扁平放在 `plan/` 根目录。

**文件体系**（ROADMAP 仅分批模式产生）：

| 文件 | 何时存在 | 职责 | 规模 |
|---|---|---|---|
| `plan/ROADMAP.md` | 仅分批模式 | 批次切分 + 依赖 + 验证门 + 状态 + 执行总链路 | < 80 行 |
| `plan/INDEX.md` | 始终 | 主题目录 + 状态（分批模式增「所属批次」列） | < 50 行 |
| `plan/<主题>/INDEX.md` | 始终 | 主题内阶段分组 + plan 列表 + 依赖 | < 30 行 |
| `plan/<主题>/PROGRESS.md` | 始终 | 执行断点唯一事实源，token 耗尽后据此恢复 | — |

## 工作流

> 步骤 0~4 在 plan 模式内（只读对齐），步骤 5~9 在 plan 模式外（落盘 + commit）。

### 步骤 0a：进入 plan 模式

**立即调用 `EnterPlanMode`**。后续 0~4 步全在只读态完成。

### 步骤 0b：读取配置 + 识别 spec 变更

`cat .bb-spec.yaml 2>/dev/null` 取 `docs_dir`（缺省 `.bb-spec/docs`），记 `${DOCS_DIR}`。运行 `git diff main...HEAD --name-status -- '${DOCS_DIR}/spec/'`：

- **非 git / 无 main / spec 目录不存在**：告知"建议先运行 `/spec`"，`ExitPlanMode` 终止
- **diff 空 + 无 ROADMAP**：告知"无 spec 变更，无需 plan"，`ExitPlanMode` 终止
- **diff 空 + 有 ROADMAP 且有未完成批次**：进入「分批续作」（步骤 2b）
- **有变更**：A 读 spec 正文；M 读正文 + `git diff` 聚焦变更；D 用 `git show main:<path>` 读旧内容做清理计划。同时读 `spec/INDEX.md` 了解全局

### 步骤 1：摸清项目现状

技术栈（`go.mod` / `package.json` / `Cargo.toml`）→ 目录结构（`find` 或 codegraph）→ 可复用基础设施 → 命名风格。新项目跳过已有代码分析，按 spec 技术约束推断结构。

**代码 vs Spec 冲突检测**：步骤 0b/1 不一致时，在步骤 4 之前列冲突，每条附简报——「代码现状 vs Spec 定义」、「保留代码 / 遵循 spec 各自理由」、「**建议方向** + 一句话理由」、「**代价**：改动范围与风险」，由用户裁决。

### 步骤 2a：规模分流

综合**领域数**（涉及多少 `spec/<领域>/` 子目录）、**spec 文件总数**、**是否冷启动**、**跨领域依赖**给出分流结论 + 理由，由用户确认（可强制覆盖）：

| 路径 | 触发条件（启发式） | 产出 |
|---|---|---|
| 单 topic | 领域 ≤ 1，或聚焦单一关注点，或非冷启动小变更 | 一个 topic 目录 + 阶段分组 |
| 分批路线图 | 多领域 + 大批 spec（冷启动），或跨领域依赖链显著 | `ROADMAP.md` + 仅展开当前批 |

不达标默认走单 topic。

### 步骤 2b：分批 / 续作

**首次分批**：设计批次切分——每批的领域、所含 spec、依赖关系、**验证门**、执行总链路（如 `B0 → B1 → {B2,B3 并行} → B4 → …`）。验证门必须是**可观察行为**（端到端用例 / 健康指标 / 关键链路打通），禁「代码写完」「测试通过」等过程指标。**当前批 = 依赖已满足且未完成的最前批次**。

**分批续作**：读 ROADMAP，按依赖关系定位下一个可生成的批次（依赖批次均 `已完成`）；多候选可并行时列出让用户选。

### 步骤 3：拆分策略 + 根源质检

**当前批 / 单 topic** 内按层 → 按功能 → 按横切关注点拆分。宁可多拆小文件，简单 spec（< 5 函数）可合并。

呈现前自问：① 是否最优实施路径？② 是否触及根源（非绕过既有不合理设计）？③ 有无 spec 未要求的过度设计？④ 分批切分是否合理（粒度、依赖、验证门可观察性）？

### 步骤 4：呈现待批方案 → ExitPlanMode

呈现：
- **单 topic**：拆分方案（文件名 + 一句话描述 + 阶段分组 + 依赖）
- **分批**：ROADMAP（批次表 + 依赖 + 验证门 + 总链路）+ 当前批拆分方案；其余批次仅占位
- 同时盘点已有 plan（读 `${DOCS_DIR}/plan/INDEX.md`），指出冲突 / 可复用 / 需修订项

调用 `ExitPlanMode`。批准后进入步骤 5；驳回则在 plan 模式内调整后重新呈现。

### 步骤 5：产出 plan 文档

每份含 frontmatter + 正文六块（见下方模板）。**函数清单**：函数名 + 文件路径 + 职责一句话 + 调用关系 + 外部接口依赖；**不写**参数列表、返回值、实现；命名风格与项目一致。

**分批模式下只产出当前批的 plan 文件**，其余批次留空待后续 `/plan` 懒生成。

### 步骤 6：更新索引、ROADMAP 与进度文件

- **主题 INDEX.md**：每条 `- [<name>](<文件名>) — <description>`；`## <阶段>` 分组；依赖标 `[依赖: <name>]`
- **根 INDEX.md**：表格 主题|概述|状态|完成时间（分批模式加「所属批次」列）；已完成主题仅作历史审计，AI 未经允许不得读取
- **ROADMAP.md**（分批）：首次写全部批次表 + 总链路；续作仅把当前批状态 `待生成 → 生成中`。**PROGRESS.md**：所有步骤初始标 `pending`

### 步骤 7：自检

- [ ] 步骤 0a~4 全程在 plan 模式内，未提前落盘？
- [ ] 规模分流结论已用户确认？拆分质检 4 项全过？
- [ ] 每份 plan ≤ 200 行，函数清单无参数和实现，无"详见 spec"式引用？
- [ ] 索引 / ROADMAP / PROGRESS 已同步？
- [ ] 分批模式下**只**展开了当前批？

### 步骤 8：本地 commit

先 `git branch --show-current` 确认分支（**在 main 上则跳过自动 commit**，提示按 git-workflow 先建分支）；只提交本次涉及文件（plan 文档 + ROADMAP + 索引 + PROGRESS）；message 遵循仓库历史风格（先 `git log --oneline -10`），不硬编码类型前缀；**仅本地不自动 push**。

### 步骤 9：完成简报

```
## Plan 完成简报
- 模式：单 topic / 分批路线图（当前批 X / 总 N 批）
- 主题：<YYYY-MM-DD.主题>
- 产出：N 份 plan，分 M 个阶段
- 文件清单：<序号>-<名称>.md — <一句话描述>
- Spec 变更覆盖：<已覆盖全部 / 未覆盖项列表>
- 验证门（仅分批）：<本批 exec 完成后必须达成的可观察能力>
- 待解决：<问题列表 / 无>
- 下一步：运行 `/exec <主题>` 开始实施（plan↔exec 上下文强关联，建议同窗口）；本批 exec 完成且验证门通过后，**先 `/clear` 再 `/plan`** 生成下一批（跨批状态全外置在 ROADMAP/INDEX/PROGRESS 与落地代码，无需上下文延续）
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
## 函数清单
### <文件路径>
| 函数名 | 职责 |
|---|---|
| `FuncA` | 一句话 |
## 协作关系
<函数调用关系 + 外部依赖（DB/MQ/第三方 API）>
## 验证方式
- [ ] <验证项>
```

**ROADMAP.md**（仅分批模式；验证门必须是可观察能力——用例跑通 / 健康检查 / 链路打通，禁「代码写完」「测试通过」等过程指标）：

```markdown
# <项目/主需求> 分批路线图
| 批次 | 领域 | spec 数 | 依赖 | 验证门 | 状态 |
|---|---|---|---|---|---|
| B0 | <基础设施> | N | — | <核心服务起来且健康检查通过> | 生成中 |
| B1 | <领域 A> | N | B0 | <核心用例端到端跑通> | 待生成 |
**执行总链路**：B0 → B1 → {B2, B3 可并行} → …
```

**根 INDEX.md**（分批模式带「所属批次」列，单 topic 模式可省）：

```markdown
# Plan 索引
| 主题 | 所属批次 | 概述 | 状态 | 完成时间 |
|---|---|---|---|---|
| [tooling-platform](2026-06-09.tooling-platform/INDEX.md) | B0 | 基础设施 | 进行中 | — |
| [auth-refactor](2026-05-15.auth-refactor/INDEX.md) | — | 认证重构 | 已完成 | 2026-05-20 |
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
