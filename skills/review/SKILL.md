---
name: review
description: 对当前分支 vs base 分支的改动做"多代理并行 + 跨模型"本地 review。默认 base = main,可用 /review <base-branch> 指定。并发 spawn 5 个 Agent(代码质量、安全视角、代码简洁性、文档同步、Codex 跨模型独立 review),汇总去重后按 BLOCKER / IMPORTANT / NIT 输出,交叉验证项标强信号。只读审视,不自动修改代码。
argument-hint: <base-branch>
user-invocable: true
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

---

## 4. 输出

### 概览

```
本地 ultrareview 完成
范围：<base>..HEAD (N commits, M 文件, +L1/-L2)
agent：代码质量 / 安全 / 简洁性 / 文档同步 / Codex
合并去重后 N 条：🔴 a(⭐a') / 🟡 b(⭐b') / 🟢 c
交叉验证强信号：<列表>
```

### 详细报告（每条）

```
### [🔴/🟡/🟢] 项N · 标题 [⭐ 交叉验证]
位置：file:lines
发现者：Agent X / Y
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

`要修哪些？（回复项编号 / "全部 BLOCKER" / "到此结束"）`

---

## 5. 硬约束

- 不修代码、不操作 git、不扩大范围（只看 base..HEAD）
- prompt 自包含（agent 看不到本对话）
- 5 agent 必须单消息并发
- Codex 不可用时降级为 4 个
- 输出中文
