---
name: tdd-pipeline
description: 三 Agent TDD 管道——Test Agent 只读 spec 写测试（Red）、Impl Agent 只看测试和函数清单写实现（Green）、Review Agent 对照 spec 检查合规性。基于 plan 文件驱动，每步完成后持久化进度到 PROGRESS.md。常见触发：用户输入 `/tdd-pipeline`、"三 agent 模式执行"、"测试和实现分开写"。
user-invocable: true
argument-hint: <YYYY-MM-DD.主题>[/<plan名>]
---

# TDD Pipeline：三 Agent 隔离执行

三个独立 Agent 串行协作：**Test Agent 写测试 → Impl Agent 写实现 → Review Agent 检查合规**。角色隔离消除单 Agent "自己写测试自己写代码"的自我偏见——写测试的不知道实现方案，写实现的只管让测试通过，审查的只看 spec 合规性。

## 核心原则

1. **角色隔离**：每个 Agent 只看自己需要的输入，互不可见
2. **Test-first 真隔离**：Test Agent 只看 spec 规则和行为预期，不看函数清单和实现路径
3. **实现只管绿灯**：Impl Agent 看 plan 函数清单 + 测试文件，目标是让测试全绿
4. **Review 独立性**：Review Agent 没参与编写，只对照 spec 检查最终产出
5. **进度持久化**：与 `/exec` 共享 PROGRESS.md 格式，支持断点恢复

## 与 exec 的关系

使用同一套 plan 目录和 PROGRESS.md。区别：exec = 单 Agent 自律 TDD；tdd-pipeline = 三 Agent 他律 TDD。同一 plan 步骤不要混用。

## Agent 定义

三个 Agent 的完整 prompt 模板位于插件根目录 `agents/` 下，派工前用 Read 工具读取对应文件：

| Agent | 定义文件 | 角色 |
|---|---|---|
| Test Agent | `agents/test-engineer.md` | 测试工程师：只读 spec 写测试 |
| Impl Agent | `agents/impl-engineer.md` | 实现工程师：只看测试写实现 |
| Review Agent | `agents/spec-reviewer.md` | 合规审查者：对照 spec 检查产出 |

---

## 信息隔离矩阵

| 输入 | Test Agent | Impl Agent | Review Agent |
|---|---|---|---|
| spec 规则（plan「业务规则」区） | ✅ | ❌ | ✅ |
| 行为预期（plan「验证方式」区） | ✅ | ❌ | ✅ |
| 函数清单 + 文件路径 | ❌ | ✅ | ❌ |
| 协作关系 | ❌ | ✅ | ❌ |
| 项目测试惯例 | ✅ | ❌ | ❌ |
| Test Agent 写的测试文件 | — | ✅ | ✅ |
| Impl Agent 写的代码 | — | — | ✅ |

**关键隔离**：Test Agent 不看函数清单（防止按实现思路写测试）；Impl Agent 不看 spec 原文（迫使它只关注让测试通过）。

---

## 工作流

### 步骤 0：定位 plan 与恢复进度

与 `/exec` 一致：读 `plan/INDEX.md` → 定位主题 → 读 PROGRESS.md → 从首个非 `done` 步骤开始。

| 调用方式 | 行为 |
|---|---|
| `/tdd-pipeline` | 自动选主题 → 询问范围 |
| `/tdd-pipeline <YYYY-MM-DD>.<主题>` | 指定主题 → 询问范围 |
| `/tdd-pipeline <YYYY-MM-DD>.<主题>/<plan名>` | 指定单个 plan |

### 步骤 1：读取 plan 并准备三份输入

读取当前步骤的 plan `.md` 文件，按隔离矩阵拆为三份 Agent 输入。同时扫描项目已有测试文件，提取测试惯例（框架、目录、命名风格）。

### 步骤 2：Test Agent — Red

读取 `test-engineer` agent 定义，用 plan 中提取的「业务规则」和「验证方式」填充模板变量，派一个 `general-purpose` Agent。

**主 Agent 验证**：
- 编译通过 + 断言失败 → ✅ Red，进入步骤 3
- 编译失败 → 主 Agent 修 import/类型问题后重跑
- 意外全 PASS → 行为已存在则标注跳过，测试错误则修正后重跑

### 步骤 3：Impl Agent — Green

读取 `impl-engineer` agent 定义，用 plan 中提取的「函数清单 + 文件路径 + 协作关系」和步骤 2 产出的测试文件路径填充模板变量，派一个 `general-purpose` Agent。

**主 Agent 验证**：
- 全部通过 → ✅ Green，进入步骤 4
- 有失败 → 将失败信息反馈 Impl Agent 重试（最多 1 次）→ 仍失败则报告用户

### 步骤 4：Review Agent — Spec 合规检查

读取 `spec-reviewer` agent 定义，用 plan 中提取的「业务规则」和「验证方式」以及步骤 2-3 产出的所有变更文件路径填充模板变量，派一个 `general-purpose` Agent。

**主 Agent 处理**：
- 全 ✅ → 通过，进入步骤 5
- 有 ❌ 或 ⚠️ → 展示给用户，选择：
  - **修复**：主 Agent 修（先改测试 → 确认 FAIL → 改实现 → 确认 PASS）
  - **接受**：记录到 PROGRESS.md 备注
  - **暂停**：标 blocked

### 步骤 5：持久化进度

与 `/exec` 一致：更新 PROGRESS.md 状态为 `done`，填入完成时间。

### 步骤 6：循环或收尾

与 `/exec` 一致。全部完成时额外跑全量测试确认无回归。

---

## 失败处理

| 阶段 | 失败情况 | 处理 |
|---|---|---|
| Red | 编译失败 | 主 Agent 修 import/类型，重跑 |
| Red | 意外全 PASS | 行为已存在 → 跳过；测试错误 → 修正 |
| Green | 测试不过 | 反馈错误给 Impl Agent 重试 1 次 → 仍失败报告用户 |
| Review | 发现违规 | 展示用户：修复 / 接受 / 暂停 |
| Review | 测试遗漏 | 展示用户：补测试 / 接受 |

---

## 硬约束

- Test Agent **禁看**函数清单和实现路径
- Impl Agent **禁看** spec 原文
- Review Agent **禁止**修改文件
- Agent prompt 自包含（不依赖对话上下文）
- 三个 Agent **必须串行**（Test → Impl → Review）
- PROGRESS.md 格式与 `/exec` 兼容
- 输出中文
