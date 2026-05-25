---
name: review-doc
description: 审查 Markdown 文档，机械层（断链/术语/层级/表格列数）由脚本判定后自动修复；语义层（前后矛盾/单一真理失败/承诺与实际不符/历史包袱）并发派 2 个 agent（Claude 通读 + Codex 跨模型）只读审查，汇总去重后按 BLOCKER / IMPORTANT / NIT 输出，交叉验证项标强信号。修不修交给用户。用户通过 /review-doc <文件或目录> 触发。
argument-hint: <file-or-directory>
user-invocable: true
disable-model-invocation: true
---

# 文档审查（review-doc）

**核心原则**：机械层脚本 100% 可信自动修 / 语义层只读报告 / 跨模型独立 / 基于 `file:line` / 抓重点不凑数。

---

## 1. 输入解析

`$ARGUMENTS`：单 `.md` 文件 / 目录（递归 `**/*.md`，排除 node_modules/.git/vendor/dist/build/.next/out）/ 未提供则要求指定。

关联文档：脚本输出的 `links.referenced` 本地 `.md` 列表（只追一层，不递归）。

---

## 2. 跑机械脚本

```bash
bun run "$HOME/.claude/skills/review-doc/scripts/run-all.ts" <file1.md> <file2.md> ...
```

输出合并 JSON：`{ links, terms, structure }`。把 `links.referenced` 纳入审查范围。

---

## 3. 机械层处理

对每条机械问题判断"直接修复条件"（三者同时满足：不改业务逻辑 + 唯一合理解 + 无明显缺点）。判定细则见 [references/rules.md](references/rules.md) §一。

### 满足 → 自动修

直接 Edit：断链可唯一确定 / anchor 笔误 / 标题层级跳跃 / 表格列数修正 / 术语单一胜出拼写。

### 不满足 → 入待决策队列

多个候选 / 势均力敌 / 可能改语义 → 与语义层报告一起出。

自动修完回显：`[机械层] 自动修复 N 个 / 待决策 M 个`

---

## 4. 语义层并发审查（2 agent，同一消息并发）

每个 prompt 包含：文档清单、4 类语义问题清单（[references/rules.md](references/rules.md) §二）、"只读不改"指令。

### Agent 1 — Claude 通读（general-purpose）

4 类检查：前后矛盾 / 单一真理来源失败 / 承诺与实际不符 / 历史包袱。每条必须指出"位置 A 与位置 B 冲突在 X"。≤ 1500 字。

### Agent 2 — Codex 跨模型（codex:codex-rescue）

同样 4 类，重点：跨文档承诺一致性 / 隐蔽历史包袱 / 数值细微差异。转述 codex 原始发现。≤ 1200 字。

降级：`which codex` 失败 → 只跑 Agent 1。

---

## 5. 汇总与去重

合并三类来源：§3 待决策 + Agent 1 + Agent 2。
- 同 `file:lines` + 相似 title → 合并
- 两 agent 都点出 → **⭐ 交叉验证**
- 严重度分歧取最高
- 按 🔴 → 🟡 → 🟢 重排

**严重度**：🔴 导致错误理解/决策 / 🟡 明显风险 / 🟢 建议性清理

---

## 6. 输出报告

详细模板见 [references/report-template.md](references/report-template.md)。

### 概览

```
文档审查完成
范围：N 个文档（主 X / 关联 Y）
机械层：自动修复 A 个；待决策 B 个
语义层：K 个 agent
合并去重后 M 条：🔴 a(⭐a') / 🟡 b(⭐b') / 🟢 c
交叉验证强信号：<列表>
```

### 每条格式

```
### [🔴/🟡/🟢] 项N · 类型 · 标题 [⭐]
位置：file:lines
来源：[机械待决策] / Agent 1 / Agent 2
事实：3-5 行
影响：读者误解/决策错误
建议：≤ 3 行
```

### 处理建议表

`要修哪些？（回复项编号 / "全部 BLOCKER" / "到此结束"）`

---

## 7. 硬约束

- 机械层满足条件才自动 Edit；语义层完全只读
- 跨模型独立（Codex 不可用降级）
- prompt 自包含、并发派工
- 不扩大范围（只审指定文档 + 一层引用）
- 建议中禁止过渡式写法
- 不操作 git
- 输出中文
