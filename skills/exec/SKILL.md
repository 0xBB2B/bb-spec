---
name: exec
description: 三 Agent 隔离执行 plan 实施计划（Test→Impl→Review），每完成一步立即持久化进度到 PROGRESS.md，支持 token 耗尽后无损续接。常见触发：用户输入 `/exec`、"开始实施"、"继续执行 plan"、"从上次断点继续"。
user-invocable: true
argument-hint: <YYYY-MM-DD.主题>[/<plan名>]
---

# Exec 计划执行

读取 plan 实施计划，以**三 Agent 隔离**方式逐步编码实现：Test Agent 写测试（Red）→ Impl Agent 写实现（Green）→ Review Agent 对照 spec 检查合规。角色隔离消除"自己写测试自己写代码"的自我偏见。

核心保证：**每步完成后持久化进度到 PROGRESS.md**，token 耗尽或中断后再次 `/exec` 可从断点无损续接。

## 核心原则

1. **逐步执行**：一次只实现一个 plan 文件，验证通过再进入下一步
2. **角色隔离**：三个 Agent 各看各的输入，互不可见
3. **进度即时持久化**：每步完成后立即更新 PROGRESS.md，不攒批
4. **Plan 即合同**：严格按 plan 文件的函数清单和业务规则实现，不自行扩展
5. **断点无损**：PROGRESS.md 是唯一进度事实源，重启后仅凭此文件恢复上下文

## Agent 定义

三个 Agent 的 prompt 模板位于插件根目录 `agents/` 下，派工前用 Read 读取对应文件填充模板变量：

| Agent | 定义文件 | 角色 |
|---|---|---|
| Test Agent | `agents/test-engineer.md` | 测试工程师：只读 spec 写测试 |
| Impl Agent | `agents/impl-engineer.md` | 实现工程师：只看测试写实现 |
| Review Agent | `agents/spec-reviewer.md` | 合规审查者：对照 spec 检查产出 |

**信息隔离矩阵**：

| 输入 | Test Agent | Impl Agent | Review Agent |
|---|---|---|---|
| spec 规则（plan「业务规则」区） | ✅ | ❌ | ✅ |
| 行为预期（plan「验证方式」区） | ✅ | ❌ | ✅ |
| 函数清单 + 文件路径 | ❌ | ✅ | ❌ |
| 协作关系 | ❌ | ✅ | ❌ |
| 项目约束（语言/框架/架构） | ✅ | ✅ | ❌ |
| 项目测试惯例 | ✅ | ❌ | ❌ |
| Test Agent 写的测试文件 | — | ✅ | ✅ |
| Impl Agent 写的代码 | — | — | ✅ |

---

## 工作流

### 步骤 0：解析参数与定位目标

```bash
cat .bb-spec/docs/plan/INDEX.md 2>/dev/null
```

**参数形式**：

| 调用方式 | 行为 |
|---|---|
| `/exec` | 自动选主题 → 询问执行范围 |
| `/exec <YYYY-MM-DD>.<主题>` | 指定主题 → 询问执行范围 |
| `/exec <YYYY-MM-DD>.<主题>/<plan名>` | 指定主题 + 单个 plan，只执行该 plan |

**主题定位**（无参数或仅指定主题时）：
- INDEX.md 不存在 → 告知用户"建议先运行 `/plan`"，终止
- 无 `进行中` 主题 → 告知用户"所有主题已完成"，终止
- 仅一个 `进行中` → 自动选中
- 多个 `进行中` → 列出，让用户选择

### 步骤 1：确定执行范围

```bash
cat .bb-spec/docs/plan/<YYYY-MM-DD>.<主题>/PROGRESS.md 2>/dev/null
```

读取 PROGRESS.md（不存在则初始化，所有步骤标 `pending`）。

**指定了单个 plan**：直接跳到该 plan 执行，不影响其他步骤状态。

**未指定单个 plan**：向用户展示进度概况（已完成 N/M 步），询问执行范围：
- **全部执行**：从第一个非 `done` 步骤开始，依次执行到最后
- **选择单个**：列出未完成步骤，让用户选择一个

### 步骤 2：执行当前步骤

读取当前步骤对应的 plan `.md` 文件，按隔离矩阵拆为三份 Agent 输入。同时扫描项目已有测试文件，提取测试惯例（框架、目录、命名风格）。

**2a. Test Agent — Red**

读取 `test-engineer` agent 定义，填入「业务规则」+「验证方式」+ 项目测试惯例，派 `general-purpose` Agent。

主 Agent 验证：
- 编译通过 + 断言失败 → ✅ Red，进入 2b
- 编译失败 → 主 Agent 修 import/类型后重跑
- 意外全 PASS → 行为已存在则跳过，测试错误则修正

**2b. Impl Agent — Green**

读取 `impl-engineer` agent 定义，填入「函数清单 + 文件路径 + 协作关系」+ 测试文件路径，派 `general-purpose` Agent。

主 Agent 验证：
- 全部通过 → ✅ Green，进入 2c
- 有失败 → 反馈错误给 Impl Agent 重试（最多 1 次）→ 仍失败报告用户

**2c. Review Agent — Spec 合规**

读取 `spec-reviewer` agent 定义，填入「业务规则」+「验证方式」+ 所有变更文件路径，派 `general-purpose` Agent。

主 Agent 处理：
- 全 ✅ → 通过，进入步骤 3
- 有 ❌ 或 ⚠️ → 展示给用户：**修复**（先改测试→FAIL→改实现→PASS）/ **接受**（记录到 PROGRESS.md）/ **暂停**（标 blocked）

### 步骤 3：持久化进度

验证通过后**立即**更新 PROGRESS.md：

1. 当前步骤状态改为 `done`，填入完成时间
2. "当前"区更新为下一步骤信息（或"全部完成"）
3. 清除已解决的阻塞项

### 步骤 4：循环或收尾

- **单个 plan 模式**：当前 plan 完成即停，向用户汇报结果
- **全部执行模式 + 还有后续步骤**：回到步骤 2，执行下一步
- **全部执行模式 + 全部完成**：
  1. 更新根 `plan/INDEX.md`，将该主题状态改为 `已完成`，填入完成时间
  2. 运行全量测试确认无回归
  3. **归档确认**：确认已删除的 spec 已从 `spec/INDEX.md` 移除；spec 文件内容与实现一致
  4. 向用户汇报完成情况

### 遇到阻塞时

无法继续（缺少依赖、需求不明确、外部服务不可用等）：

1. 在 PROGRESS.md 当前步骤标记 `blocked`
2. 在"阻塞"区记录原因
3. 告知用户具体阻塞原因，等待指示

---

## PROGRESS.md 操作规范

**初始化**（步骤 1 创建时）：

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

**更新**（步骤 3 每次写入）：只改变三处——当前步骤状态行、"当前"区、"阻塞"区。不重写整个文件。

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

## 与其他 skill 的协作

exec 不重复其他 skill 的规则，但执行时**必须遵守已激活的 skill 约束**：

| 场景 | 行为 |
|---|---|
| 项目有语言测试 skill（如 golang-testing） | 测试代码遵循该语言惯用法 |
| 项目有编码约束 skill（如 golang-constraints） | 遵守架构与编码约束 |

---

## 硬约束

- Test Agent **禁看**函数清单和实现路径
- Impl Agent **禁看** spec 原文
- Review Agent **禁止**修改文件
- Agent prompt 自包含（不依赖对话上下文）
- 三个 Agent **必须串行**（Test → Impl → Review）
- 输出中文

---

## 反面案例

- ❌ 不读 PROGRESS.md 就开始编码——可能重复实现已完成的步骤
- ❌ 完成步骤后不更新 PROGRESS.md——中断后进度丢失
- ❌ 一次实现多个 plan 文件——跳步可能破坏依赖关系
- ❌ 自行扩展 plan 未描述的功能——额外需求走 `/spec` → `/plan`
- ❌ 验证失败就标 done——必须修复通过后才能推进
- ❌ 阻塞时静默跳过——必须记录并告知用户
- ❌ Test Agent 看到函数清单——破坏隔离，测试会按实现思路写
- ❌ Impl Agent 看到 spec 原文——应该只关注让测试通过
