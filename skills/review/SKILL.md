---
name: review
description: Multi-agent parallel + cross-model local review of the changes on the current branch vs a base branch. Base defaults to main; override with /review <base-branch>. Concurrently spawns 5 agents (code quality, security, simplicity, doc sync, Codex cross-model independent review), dedupes, and outputs findings as BLOCKER / IMPORTANT / NIT with cross-validated items flagged as strong signals. Read-only — never auto-edits code. ｜ 对当前分支 vs base 分支的改动做"多代理并行 + 跨模型"本地 review。默认 base = main,可用 /review <base-branch> 指定。并发 spawn 5 个 Agent(代码质量、安全视角、代码简洁性、文档同步、Codex 跨模型独立 review),汇总去重后按 BLOCKER / IMPORTANT / NIT 输出,交叉验证项标强信号。只读审视,不自动修改代码。
argument-hint: <base-branch>
disable-model-invocation: true
---

# 本地 ultrareview

跨模型、多代理、只读的 PR 级 review 协调者。

**核心原则**：跨模型独立 / prompt 自包含 / 只读不写 / 抓重点不凑数 / 基于 `file:line` 事实。

---

## 1. 输入与前置检查

`$ARGUMENTS` = base 分支名（默认 `main`，不存在则 `master`，再不存在则提示用户）。

前置检查：确认 git 仓库 / 当前分支 ≠ base / base 存在 / 未提交改动仅警告不中止。

回显：`review 范围：<base> .. HEAD | 分支：<name> | commits：N | diff：M 文件 +L1/-L2`

### 修复主题摘要（≤ 300 字）

从 commit messages + CLAUDE.md 提取"想解决什么 / 修复策略 / 关键约束"，注入每个 agent prompt。

---

## 2. 并行派工（5 个 Agent，同一条消息并发）

每个 agent prompt 由对应定义文件（插件根目录 `agents/`）+ 本次 review 上下文（范围、主题摘要、约束清单）组合而成。派工前用 Read 读取 agent 定义，填充模板变量。

| Agent | 定义文件 | 角色 |
|---|---|---|
| Agent 1 | `agents/review-code-quality.md` | 代码质量 / 架构 / 测试覆盖 |
| Agent 2 | `agents/review-security.md` | 安全视角（攻击者视角 + POC 思路） |
| Agent 3 | `agents/review-simplicity.md` | 代码简洁性（反过度设计 + 反历史包袱） |
| Agent 4 | `agents/review-doc-sync.md` | 文档同步（代码改了文档没跟上） |
| Agent 5 | `agents/review-codex.md` | Codex 跨模型（`codex:codex-rescue`） |

Agent 1-4 为 `general-purpose`，Agent 5 为 `codex:codex-rescue`。
降级：`which codex` 失败 → 只跑 4 个 Claude agent，报告中说明。

---

## 3. 汇总与去重

- 同 `file:lines` + 相似 title → 合并
- 多 agent 指出同一问题 → **⭐ 交叉验证**（强信号，优先级提升一档）
- 严重度分歧取最高
- 按 🔴 → 🟡 → 🟢 重排，每档内交叉验证优先

### 测试缺陷类 finding 处理

当 finding 指向**测试本身**（断言写错、用例设计不合理、覆盖场景缺失）而非实现代码时：

- 在该 finding 标题后追加 `[测试缺陷]` 标签
- 处理建议表中，处理方式统一写 `走 /revise 诊断（测试层 impl-defect）`
- 若 finding 暗示 spec 对预期行为描述不清导致测试写错，处理方式写 `走 /revise 诊断（疑似 spec-defect）`

---

## 4. 质量自检（输出前强制门槛）

**核心要求**：不是个问题就给用户。汇总去重后、写最终报告前，对**每一条** finding 逐条自检三个维度，综合评分 < 80 直接进"已过滤"摘要，**只有 ≥ 80 才进入正式输出**。

### 三维评分（每项 0-100）

| 维度 | 含义 | 评分锚点 |
|---|---|---|
| **重要性 (importance)** | 这个问题真的重要吗？用户 / 业务 / 维护者会受影响吗？ | 90+：会直接影响线上行为或核心可维护性；70-89：明显改善质量但非紧迫；< 70：风格 / 偏好 / 凑数 |
| **根源性 (root_cause)** | 指出的是根源还是表层症状？修复建议会触根因吗？ | 90+：精确定位根因且建议是根本修复；70-89：定位准确但建议偏缓解；< 70：只描述症状或建议是绕过 / 加防御补丁 |
| **不修风险 (risk_if_unfixed)** | 不修复会引发安全 / 正确性 / 重大可维护性塌方吗？ | 90+：不修必然出事（数据损坏、安全漏洞、线上故障）；70-89：在特定场景下会触发问题；< 70：基本无后果，纯洁癖 |

### 综合评分公式

```
综合 = 0.3 × 重要性 + 0.3 × 根源性 + 0.4 × 不修风险
```

**门槛**：综合 ≥ 80 才进入正式输出（第 5 节）。

### 严重度与评分一致性校验

评分完成后，对照原严重度标签做一次反向校验：

- **🔴 但综合 < 80** → 严重度虚高，**降级**到 🟡 重新评分；仍 < 80 则丢入"已过滤"
- **🟢 但综合 ≥ 90** → 严重度偏低，**升级**到 🟡 后输出
- **⭐ 交叉验证** 项目：不修风险维度 +5 分（多 agent 共识本身就是信号）

### 已过滤摘要（透明化）

被过滤项不彻底隐藏，在最终报告末尾以**单行列表**呈现，让用户可质询：

```
已过滤 N 条低价值发现（综合 < 80，未展开）：
- [原 🟡] 命名 stutter（重要性 60 / 根源 85 / 风险 30 → 综合 55）
- [原 🟢] 注释少一个句号（重要性 20 / 根源 90 / 风险 10 → 综合 36）
- ...
```

用户回复 `展开过滤项` / `展开第 N 项` 才给完整内容。

---

## 5. 输出

### 概览

```
本地 ultrareview 完成
范围：<base>..HEAD (N commits, M 文件, +L1/-L2)
agent：代码质量 / 安全 / 简洁性 / 文档同步 / Codex
合并去重后 N 条 → 自检过滤后保留 M 条（过滤 N-M 条低价值发现）
保留分布：🔴 a(⭐a') / 🟡 b(⭐b') / 🟢 c
交叉验证强信号：<列表>
```

### 详细报告（每条，仅综合 ≥ 80 的进入这里）

```
### [🔴/🟡/🟢] 项N · 标题 [⭐ 交叉验证]
位置：file:lines
发现者：Agent X / Y
自检：重要性 X / 根源 Y / 风险 Z → 综合 W
事实：3-5 行
影响：正确性/安全/可维护性/可读性
建议：≤ 3 行
```

### 处理建议表

| 优先 | 项 | 处理方式 |
|---|---|---|
| 立即 | 项 N | 当前 PR 加 commit |
| 跟进 | 项 K | 列 followup issue |
| RA | 项 L | PR 描述加 Risk Accept |

`接下来怎么办？回复以下任一项：`
`  · 项目编号（如 "1 3 5"）→ 只修这几个`
`  · "全修红色" → 一次性修掉所有严重项（🔴）`
`  · "展开过滤项" → 看看刚才被判定不重要、藏起来的那些，怕我漏判`
`  · "结束" → 看完了，不修了`

---

## 6. 硬约束

- 不修代码、不操作 git、不扩大范围（只看 base..HEAD）
- prompt 自包含（agent 看不到本对话）
- 5 agent 必须单消息并发
- Codex 不可用时降级为 4 个
- **自检过滤强制执行**：综合 < 80 不进正式报告，只入"已过滤"摘要；不得跳过自检直接输出
- 输出中文
