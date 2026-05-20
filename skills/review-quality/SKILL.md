---
name: review-quality
description: 对任意仓库做整体质量审视：主对话快速抽取项目档案摘要，并发派 5 个 Agent（架构&测试 / 错处&命名&依赖 / 文档&反包袱 / 项目特定约束 / Codex 跨模型）只读审视，汇总去重后按 BLOCKER / IMPORTANT / NIT 输出，交叉验证项标强信号。只输出报告与处理建议，不修改任何文件、不操作 git。用户通过 /review-quality [路径] 触发，未传路径则审当前工作目录。
argument-hint: <path>
user-invocable: true
disable-model-invocation: true
---

# 仓库质量审视技能（review-quality）

你是一个克制、跨模型、以证据为中心的多代理质量审视协调者。职责是：

1. 计算审视范围（目标目录）
2. 主对话快速抽取"项目档案摘要"（CLAUDE.md / README / doc / 语言栈 / 测试入口 / 关键约束）
3. 并发 spawn 5 个独立 Agent（架构&测试 / 错处&命名&依赖 / 文档&反包袱 / 项目特定约束 / Codex 跨模型），每个 prompt 自包含
4. 汇总 + 去重 + 标注交叉验证强信号 + 按严重度分级
5. 只输出报告与处理建议，不替用户决定下一步

**核心原则**：

- **只读不写**：本 skill 不调 Edit/Write、不操作 git；agent 也不允许；最终修复由用户在报告后另行触发
- **跨模型独立**：Claude 与 Codex/GPT-5.5 各跑一份，catch 单模型盲点
- **prompt 自包含**：每个 agent 收到的 prompt 必须能脱离本对话独立理解
- **抓重点不凑数**：宁可少报，不可滥报；不为凑数列轻微措辞差异
- **基于事实**：每条发现必须指向 `file:line`

---

## 1. 输入解析与范围确认

`$ARGUMENTS` 为审视范围：

- **传入目录**：在该目录下做审视
- **未传**：默认当前工作目录
- **路径不存在 / 是文件而非目录**：提示用户改传有效目录，不要猜测

回显一句话给用户：

```text
审视范围：<path>
本轮：主对话快速抽项目档案摘要 → 并发派 5 个 Agent（含 Codex 跨模型）只读审视 → 输出报告与处理建议（不修代码、不操作 git）
```

---

## 2. 项目档案抽取（主对话直接做，不派 subagent）

由主对话快速完成，**不再产出独立 yaml 档案**，直接合成一段 ≤500 字的"项目档案摘要"，内联到每个 agent 的 prompt。

### 2.1 收集顺序（命中即用，避免无关读取）

1. **规范源**：目标目录及上一级 `CLAUDE.md`；其它 AI 规则文件 `AGENTS.md` / `.cursor/rules/*` / `.cursorrules` / `.github/copilot-instructions.md`
2. **README**：`README.md` / `README*.md`
3. **doc/ 或 docs/**：只读 `.md` / `.mdx` / `.rst`，深度 ≤ 2，挑架构 / 规范 / 约定相关
4. **ADR**：`doc/decisions/` / `docs/adr/` / `decisions/`（如有）
5. **lint / format 配置**：`.golangci.yml` / `.eslintrc*` / `pyproject.toml` / `rustfmt.toml`
6. **语言栈与构建系统**（只看根目录与一层子目录）：`go.mod` / `package.json` / `Cargo.toml` / `pyproject.toml` / `pom.xml` / `build.gradle*` 等
7. **测试入口**：`Makefile` 中的 `test*` 目标 / `package.json scripts.test*` / 文档显式给出的测试命令（**不实际执行**测试）

### 2.2 项目档案摘要格式（≤500 字，主对话生成）

```text
[范围] <绝对路径>
[语言栈] go / ts / ...（主在前）
[构建&测试入口] make test / bun test / ...
[规范源] CLAUDE.md(根) / doc/architecture.md / .golangci.yml ...
[关键约束]（每条附来源 file:line，挑硬约束，不超过 10 条）
- <约束 1> [来源 path:line]
- <约束 2> [来源 path:line]
- ...
[项目地图]（≤ 8 项，dir → 职责猜测）
- internal/svc/order → 订单领域 service
- internal/data → repository 层
- ...
```

**重要**：约束清单每条都要附"来源 file:line"，不能凭空抽出；超过 10 条只挑最关键的。

> 若目标目录信息极少（无 CLAUDE.md、无 doc/、无 README），档案摘要可短到 200 字以内，明确告知 agent "项目档案稀疏，按通用规范审视"。

---

## 3. 并行派工（单消息多 tool call，并发上限 5）

**关键纪律**：5 个 Agent 必须在**同一条消息内并发发起**，不要串行。

每个 agent 的 prompt 都必须包含：

- 审视范围（目标目录绝对路径）
- §2 抽出的项目档案摘要
- 本维度的检查清单（**主对话从 `references/dimensions.md` 抽取对应小节，转写为可执行的搜索/检查动作**，不要让 agent 自己去读 dimensions.md）
- 统一输出格式（见 §3.6）
- 一句"只报真正影响维护、正确性、安全或可读性的问题；轻微措辞差异不报"
- 一句"不要修改任何文件，仅做 review 报告"

### 3.1 Agent 1 — 架构 & 测试覆盖

`subagent_type: general-purpose`

检查维度（参照 [references/dimensions.md](references/dimensions.md) §1 + §2）：

- 项目档案中的架构 / 分层约束是否被遵守
- handler / 控制层是否写业务规则、直接访问数据层
- service 是否写原始 SQL / 协议层细节 / 框架对象
- repository 是否承载业务规则
- 跨服务 / 跨模块调用是否走声明的边界
- 关键 service / 核心纯函数 / 错误分支 / 边界条件是否有用例
- monkey-patch 风格替换（`var fnName = realFn`）
- 仅断言"被调用一次"或没断言的测试
- 长期 skip 的测试 / 反向修改业务语义让自己通过的测试

长度上限：≤ 1500 字

### 3.2 Agent 2 — 错误处理 & 命名 & 依赖

`subagent_type: general-purpose`

检查维度（参照 [references/dimensions.md](references/dimensions.md) §3 + §4 + §5）：

- 项目档案中的错误处理 / 日志 / 命名 / 依赖约束是否被遵守
- `_ = err` 显式忽略 / `panic` 处理常规业务错误 / 同一错误多层重复包装
- 跨服务边界错误码是否按项目约定透传
- 日志含敏感信息 / 业务非阻断错误用 ERROR 级别
- 类型 / 方法名 stutter / 单字母变量超出短生命周期 / 函数超 80-100 行 / 嵌套 > 4 / 魔法数字
- 标准库已能解决却引入第三方 / 同一功能引入两套库 / 已废弃依赖 / 已知 CVE
- 直接 import 内部包的违规

长度上限：≤ 1500 字

### 3.3 Agent 3 — 文档同步 & 反历史包袱

`subagent_type: general-purpose`

检查维度（参照 [references/dimensions.md](references/dimensions.md) §6 + 全局 CLAUDE.md「反历史包袱」原则）：

**文档同步**：

- README / 架构文档 / API 文档 / GoDoc 与代码事实一致性
- 文档示例 / 命令 / 路径 / 字段名是否与代码一致
- 已删除功能是否仍在文档中描述
- API 错误码是否与代码一致

**反历史包袱**（代码 / 注释 / 文档 / 流程四层）：

- 已弃用 / 已移除功能的残留（死代码、孤立分支、unused import / wrapper / shim）
- "保留原 X 以兼容..." 类过渡式实现，且旧路径已无调用方
- v1/v2 并存但 v1 早无引用的双轨实现
- 无负责人无时间表的 TODO
- 反向依赖描述（"原本是 X，现在是 Y"，去掉对照部分语义仍完整）
- 迁移指南章节但迁移早已完成
- CI/CD / 配置中针对已下线环境的残留

**判断准则**：

- 反向依赖描述：把"旧版/历史"对照部分去掉，若语义仍完整且更直接 → 该对照即包袱
- 必要历史说明（CVE 补丁说明、合规审计记录、协议向后兼容注释）→ 不算包袱
- 有明确时间表 / owner 的灰度 → 不算包袱；无时间表无负责人 → 包袱

**禁止建议**：不要给"加注释标记 deprecated"、"新旧并列保留"、"暂时保留待后续处理"这种过渡式建议；**直接清理或不动，二选一**。

长度上限：≤ 1500 字

### 3.4 Agent 4 — 项目特定约束

`subagent_type: general-purpose`

这是该 skill 适配所有仓库的关键。主对话从 §2 的"关键约束"清单中**逐条转换为可执行检查动作**，注入到本 agent 的 prompt。

转换示例（参照 [references/dimensions.md](references/dimensions.md) §7）：

| 原文约束 | 转化后的检查项 |
|---|---|
| 金额/积分统一 ×100 整数存储 | 搜索 `float64`/`float32` 在 `price`/`amount`/`balance` 等命名上的出现 |
| UNIQUE KEY 必须与 deleted 列联合 | 搜索 migrations 中的 `UNIQUE KEY`，检查是否含 deleted |
| 业务非阻断错误用 WARN | 搜索 `slog.Error` / `log.Error`，检查上下文是否系统级阻断 |
| 禁止 npm/yarn/pnpm，统一 bun | 检查 lock 文件类型 + CI 脚本中的包管理器命令 |

**优先级**：项目特定约束的违规默认提升一级（项目自己强调的硬约束，违反通常是 BLOCKER / IMPORTANT）。

如果项目档案中关键约束 > 15 条，本 agent 的 prompt 拆成两批分别派工（即变为 Agent 4a / 4b），保持并发上限 5 内（必要时与 Agent 5 错开批次）。

长度上限：≤ 1500 字（每个分批）

### 3.5 Agent 5 — Codex 跨模型独立审视

`subagent_type: codex:codex-rescue`（走 Codex CLI / GPT-5.5）

prompt 必须包含：

- 同样的范围 / 项目档案摘要 / 关键约束
- 显式说明："用 codex CLI 启动一次 GPT-5.5 review，目标是找单模型（Claude）易遗漏的盲点"
- 检查维度：
  1. 整体架构是否合理（是否触及问题根源，还是仅缓解症状）
  2. 关键设计取舍是否在代码注释 / commit message 里说清楚
  3. 语言习惯（Go idiom / TS 风格 / 等）、并发安全、可观测性是否 production grade
  4. 测试覆盖完整性（不重复 Agent 1，从跨模型视角看）
  5. 跨模型盲点：Claude 在这类设计上的常见偏好（过度防御、注释泛滥、idiom 偏离）
- 操作：转述 codex 原始发现，**不要重新编辑或加自己观点**
- 输出格式同其它 agent

长度上限：≤ 1200 字

> **降级策略**：派工前用 `which codex` 探测；失败则只派 4 个 Claude agent，并在最终报告中说明缺失了 Codex 那一份。

### 3.6 统一输出格式（每个 agent 强制）

```text
🔴 BLOCKER / 🟡 IMPORTANT / 🟢 NIT
- file:line · 问题简述 → 建议改法（≤2 行）
  违反约束：<约束原文 + 来源 file:line / 或"通用规范">
  影响：<具体落到正确性 / 安全 / 可维护性 / 可读性 哪一项>
```

**严重度判定**：

- 🔴 **BLOCKER**：明确正确性 / 安全问题；明确违反 CLAUDE.md 中"必须 / 禁止"硬约束
- 🟡 **IMPORTANT**：明显风险或明显违反建议性规范，维护时大概率踩坑
- 🟢 **NIT**：可读性 / 一致性建议；无明显风险

---

## 4. 汇总与去重

收到所有 agent 报告后：

### 4.1 去重规则

- 同一 `file:lines` + 相似 title → 合并为一条
- 不同 agent 都点出同一问题 → 合并后**标记 ⭐ 交叉验证**（强信号，优先级提升一档考虑）
- agent 严重度有分歧时，以**最高**为准，但备注中说明分歧
- fuzzy match 阈值偏严，避免误合不同问题

### 4.2 重排

按 🔴 → 🟡 → 🟢，每档内按"是否交叉验证"再排，重新编号 `1, 2, ...`。

---

## 5. 输出报告

### 5.1 概览

```text
仓库质量审视完成

范围：<path>
跑了 N 个 agent：架构&测试 / 错处&命名&依赖 / 文档&反包袱 / 项目特定约束 / Codex 跨模型
（Codex 不可用时显式说明：本次缺失 Codex 跨模型那一份）

合并去重后共 N 条：
- 🔴 BLOCKER：a 条（其中 ⭐ 交叉验证 a' 条）
- 🟡 IMPORTANT：b 条（其中 ⭐ 交叉验证 b' 条）
- 🟢 NIT：c 条

交叉验证强信号（独立 agent 同时指出）：
- <项 1 简述>
- <项 2 简述>
```

### 5.2 详细报告

按严重度分组，每条按以下格式：

```text
### [🔴/🟡/🟢] <项 N> · <one-line 标题>  [⭐ 交叉验证（可选）]

**位置**：`file:lines`
**发现者**：Agent 1 / Agent 4 / ...（列出哪些 agent 点了）
**违反约束**：<约束原文 + 来源 file:line / 或"通用规范">
**事实**：<3-5 行说明>
**影响**：<正确性 / 安全 / 可维护性 / 可读性 哪一项>
**建议**：<修法摘要，≤ 3 行>
```

### 5.3 处理建议表（最后一段）

按"立即修 / 跟进 issue / Risk Accept" 三类给出**建议**（不替用户决定）：

```text
建议处理顺序：

| 优先 | 项 | 处理方式 |
| --- | --- | --- |
| 立即 | <项 N>, <项 M> | 主对话单独触发修复 |
| 跟进 | <项 K> | 列 followup issue |
| RA | <项 L> | 项目档案补充 Risk Accept 备注 |

要修哪些？（回复项编号 / "全部 BLOCKER" / "到此结束"）
```

---

## 6. 跨章节硬约束

- **基于事实**：每条问题必须指向 `file:line`；推断必须显式标注"推断"
- **只读不写**：本 skill 仅 review，不调 Edit/Write、不操作 git；agent 也不允许；用户决定后续如何修复
- **跨模型独立**：必须包含 codex:codex-rescue 这个 agent；不可用时降级为 4 个 Claude agent 并显式告知
- **prompt 自包含**：agent 看不到本对话，所有上下文必须显式传入
- **并发派工**：所有 agent 必须单消息并发，不串行；并发上限 5
- **不扩大范围**：只审目标目录内的文件
- **抓重点不凑数**：宁可少报，不可滥报
- **方案不引入历史包袱**：Agent 3 的建议中禁止过渡式写法
- **语言**：所有输出使用中文

---

## 7. 实现要点（给执行 skill 的 AI 看）

- **§2 串行 → §3 并行**：先把档案摘要抽好，再单消息并发派 agent
- **prompt 大小控制**：项目档案摘要 ≤ 500 字，每个 agent 只塞与本维度相关的"关键约束"子集，避免吞超长 prompt
- **dimensions.md 用法**：主对话读它、抽取对应维度小节、转写为可执行检查动作后注入 prompt；**agent 不读 dimensions.md**
- **codex 不可用降级**：Bash 跑 `which codex` 探测；失败则少派一个 agent，在报告中说明
- **不调 web**：本 skill 默认不联网
- **交叉验证识别**：merge 时按 `file:lines` + 模糊 title 匹配，阈值偏严
- **不创建分支 / 不 commit / 不 push**：本 skill 完全只读
- **报告完成态**：最后让用户决定后续动作，本 skill 在此终止；不要主动开始修复

---

## 8. 退出条件

- **正常完成**：输出报告 + 处理建议表 + 等待用户回复
- **用户回复"全部 BLOCKER"或"按推荐执行"**：本 skill 退出，把后续修复交给主对话
- **用户回复"到此结束"**：静默退出
- **agent 失败**：即便部分 agent 失败，只要至少 1 个成功也输出可用部分，在报告中说明缺失了哪些 agent

---

## 9. 与 local-ultrareview 的区别

| 项 | review-quality | local-ultrareview |
| --- | --- | --- |
| 范围 | 整个目标目录 | base..HEAD 改动 |
| Agent 数 | 5（含 Codex） | 4（含 Codex） |
| 项目特定约束 | 独立 Agent，从档案摘要逐条转检查动作 | 不专设；约束作为通用 prompt 的一部分 |
| 跨模型 | 是 | 是 |
| 修复 | 不修，只输出报告 | 不修，只输出报告 |
| 适用 | 项目体检 / 整仓质量审视 | PR / 分支评审 |

整仓体检用 review-quality，PR 评审用 local-ultrareview。
