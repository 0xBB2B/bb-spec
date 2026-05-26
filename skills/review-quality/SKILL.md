---
name: review-quality
description: 对任意仓库做整体质量审视：主对话快速抽取项目档案摘要，并发派 5 个 Agent（架构&测试 / 错处&命名&依赖 / 文档&反包袱 / 项目特定约束 / Codex 跨模型）只读审视，汇总去重后按 BLOCKER / IMPORTANT / NIT 输出，交叉验证项标强信号。只输出报告与处理建议，不修改任何文件、不操作 git。用户通过 /review-quality [路径] 触发，未传路径则审当前工作目录。
argument-hint: <path>
user-invocable: true
disable-model-invocation: true
---

# 仓库质量审视

跨模型、多代理、只读的整仓质量审视协调者。

**核心原则**：只读不写 / 跨模型独立 / prompt 自包含 / 抓重点不凑数 / 基于 `file:line` 事实。

---

## 1. 输入与范围

`$ARGUMENTS` = 目录（默认 CWD）。路径不存在或是文件 → 提示用户。

回显：`审视范围：<path> | 本轮：抽项目档案 → 并发 5 agent → 输出报告`

---

## 2. 项目档案摘要（主对话直接做，≤ 500 字）

收集顺序：CLAUDE.md → README → doc/docs/ → ADR → lint 配置 → 语言栈/构建 → 测试入口（**不执行**测试）。

摘要格式：
```
[范围] 绝对路径
[语言栈] go / ts / ...
[构建&测试入口] make test / bun test / ...
[规范源] CLAUDE.md / .golangci.yml ...
[关键约束]（≤ 10 条，每条附来源 file:line）
[项目地图]（≤ 8 项，dir → 职责）
```

---

## 3. 并行派工（5 Agent，同一消息并发）

每个 prompt 包含：目标目录、项目档案摘要、本维度检查清单、统一输出格式、"不修改文件"指令。

### Agent 1 — 架构 & 测试覆盖（general-purpose）

分层约束是否遵守、handler/service/repository 越权、关键逻辑是否有用例、monkey-patch 风格、无断言测试、长期 skip 测试。≤ 1500 字。

### Agent 2 — 错误处理 & 命名 & 依赖（general-purpose）

`_ = err` / panic 业务错误 / 多层重复包装 / 日志含敏感信息 / stutter 命名 / 函数超 80 行 / 嵌套 > 4 / 标准库能解决却引第三方 / 已知 CVE。≤ 1500 字。

### Agent 3 — 文档同步 & 反历史包袱（general-purpose）

文档与代码事实一致性 / 已删功能残留文档 / 死代码 / 过渡式实现 / 反向依赖描述 / 无负责人 TODO / 已完成迁移指南。禁止给过渡式建议。≤ 1500 字。

### Agent 4 — 项目特定约束（general-purpose）

从档案摘要"关键约束"逐条转为可执行检查动作注入 prompt。项目约束违规默认提升一级。≤ 1500 字。

### Agent 5 — Codex 跨模型（codex:codex-rescue）

读取 `agents/review-codex.md` 定义，填入目标目录和项目档案摘要。
降级：`which codex` 失败 → 4 个 agent，报告中说明。

---

## 4. 汇总与去重

- 同 `file:lines` + 相似 title → 合并
- 多 agent 指出 → **⭐ 交叉验证**（优先级提升一档）
- 严重度分歧取最高
- 按 🔴 → 🟡 → 🟢 重排

**严重度判定**：🔴 明确正确性/安全问题或违反硬约束 / 🟡 明显风险或违反建议性规范 / 🟢 可读性建议

---

## 5. 输出

### 概览

```
仓库质量审视完成
范围：<path>
agent：架构&测试 / 错处&命名&依赖 / 文档&反包袱 / 项目约束 / Codex
合并去重后 N 条：🔴 a(⭐a') / 🟡 b(⭐b') / 🟢 c
交叉验证强信号：<列表>
```

### 详细报告（每条）

```
### [🔴/🟡/🟢] 项N · 标题 [⭐ 交叉验证]
位置：file:lines
发现者：Agent X / Y
违反约束：约束原文 + 来源
事实：3-5 行
影响：正确性/安全/可维护性/可读性
建议：≤ 3 行
```

### 处理建议表

| 优先 | 项 | 处理方式 |
|---|---|---|
| 立即 | 项 N | 主对话触发修复 |
| 跟进 | 项 K | 列 followup issue |
| RA | 项 L | 项目档案补 Risk Accept |

`要修哪些？（回复项编号 / "全部 BLOCKER" / "到此结束"）`

---

## 6. 硬约束

- 不修代码、不操作 git、不扩大范围
- prompt 自包含（agent 看不到本对话）
- 5 agent 单消息并发
- Codex 不可用降级为 4 个
- 建议中禁止过渡式写法
- 输出中文
