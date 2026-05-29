---
name: exec
description: 三 Agent 隔离执行 plan 实施计划（Test→Impl→Review），每完成一步立即持久化进度到 PROGRESS.md，支持 token 耗尽后无损续接。常见触发：用户输入 `/exec`、"开始实施"、"继续执行 plan"、"从上次断点继续"。
user-invocable: true
argument-hint: <YYYY-MM-DD.主题>[/<plan名>]
---

# Exec 计划执行

三 Agent 隔离执行 plan：Test(Red) → Impl(Green) → Review(合规)，每步完成持久化到 PROGRESS.md，支持断点续接。

## 核心原则

1. **逐步执行**：一次只实现一个 plan 文件，验证通过再进入下一步
2. **角色隔离**：三个 Agent 各看各的输入，互不可见
3. **进度即时持久化**：每步完成后立即更新 PROGRESS.md，不攒批
4. **Plan 即合同**：严格按 plan 文件的函数清单和业务规则实现，不自行扩展
5. **断点无损**：PROGRESS.md 是唯一进度事实源，重启后仅凭此文件恢复上下文

## Agent 定义

三个 Agent 通过 plugin 注册的 `subagent_type` 派工，数据通过 `prompt` 传入：

| Agent | subagent_type | 角色 |
|---|---|---|
| Test Agent | `bb-spec:test-engineer` | 测试工程师：只读 spec 写测试 |
| Impl Agent | `bb-spec:impl-engineer` | 实现工程师：只看测试写实现 |
| Review Agent | `bb-spec:spec-reviewer` | 合规审查者：对照 spec 检查产出 |

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

## 工作流

### 步骤 0：读取项目配置 + 解析参数与定位目标

```bash
cat .bb-spec.yaml 2>/dev/null
```

有 `docs_dir` → 用其值作为基础路径；文件不存在或无该字段 → 默认 `.bb-spec/docs`。后续所有路径基于此值。

读取 `${DOCS_DIR}/plan/INDEX.md`，按参数形式决定行为：

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

读取 `PROGRESS.md`（不存在则初始化，所有步骤标 `pending`）。

**指定了单个 plan**：直接跳到该 plan 执行，不影响其他步骤状态。

**未指定单个 plan**：向用户展示进度概况（已完成 N/M 步），询问执行范围：
- **全部执行**：从第一个非 `done` 步骤开始，依次执行到最后
- **选择单个**：列出未完成步骤，让用户选择一个

### 步骤 2：执行当前步骤

读取当前步骤对应的 plan `.md` 文件，按隔离矩阵拆为三份 Agent 输入。同时扫描项目已有测试文件，提取测试惯例（框架、目录、命名风格）。

**2a. Test Agent — Red**

派 Agent（`subagent_type: "bb-spec:test-engineer"`），prompt 中传入「业务规则」+「验证方式」+ 项目测试惯例。

主 Agent 验证：
- 编译通过 + 断言失败 → ✅ Red，进入 2b
- 编译失败 → 主 Agent 修 import/类型后重跑
- 意外全 PASS → 行为已存在则跳过，测试错误则修正

**2b. Impl Agent — Green**

派 Agent（`subagent_type: "bb-spec:impl-engineer"`），prompt 中传入「函数清单 + 文件路径 + 协作关系」+ 测试文件路径。

主 Agent 验证：
- 全部通过 → 简洁性审视：代码是否用最少实现解决问题，有无 plan 未要求的抽象/防御/功能
  - 发现过度设计 → 反馈给 Impl Agent 简化后重跑测试
  - 通过 → ✅ Green，进入 2c
- 有失败 → 反馈错误给 Impl Agent 重试（最多 1 次）→ 仍失败报告用户

**2c. Review Agent — Spec 合规**

派 Agent（`subagent_type: "bb-spec:spec-reviewer"`），prompt 中传入「业务规则」+「验证方式」+ 所有变更文件路径。

主 Agent 处理：
- 全 ✅ → 通过，进入步骤 3
- 有 ❌ 或 ⚠️ → 展示给用户：**修复** / **接受**（记录到 PROGRESS.md）/ **暂停**（标 blocked）

选择"修复"时，先诊断归因再动手：

1. **归因**：对照 spec → plan → 实现 → 测试的链路，判定根因在哪层：
   - **spec-defect**：spec/plan 没有正确描述预期行为（定义层出错）
   - **impl-defect**：spec 正确但实现不符合（实现层出错）
   - **requirement-change**：用户实际需要与现有 spec 不同（需求层变化）
2. **确认**：向用户展示归因 + 证据，确认后再修
3. **按类型修复**：
   - spec-defect → 改 spec → 级联 plan → TDD 重新实现（Test→Impl→Review）
   - impl-defect → 补测试(Red) → 改实现(Green) → 重新 Review
   - requirement-change → 用户确认新需求 → 更新 spec → 级联 plan + 实现
4. **回归验证**：全量测试 + spec 合规检查

### 步骤 3：持久化进度

验证通过后**立即**更新 PROGRESS.md：当前步骤标 `done` + 填完成时间、"当前"区更新为下一步骤、清除已解决阻塞项。

PROGRESS.md 更新后，把本步骤产出做一次**本地** commit：

- 先 `git branch --show-current` 确认分支——**在 main 上则跳过自动 commit**，提示用户按 git-workflow 先建分支
- 只提交本步骤涉及的文件（实现 + 测试 + `PROGRESS.md`）
- commit message 遵循仓库历史风格（先 `git log --oneline -10`），不硬编码类型前缀
- **仅本地、不自动 push**；blocked / 未通过的步骤不 commit

### 步骤 4：循环或收尾

- **单个 plan 模式**：当前 plan 完成即停，输出完成简报
- **全部执行模式 + 还有后续步骤**：回到步骤 2，执行下一步
- **全部执行模式 + 全部完成**：
  1. 更新根 `plan/INDEX.md`，将该主题状态改为 `已完成`，填入完成时间
  2. 运行全量测试确认无回归
  3. **归档确认**：确认已删除的 spec 已从 `spec/INDEX.md` 移除；spec 文件内容与实现一致
  4. 把收尾改动（`plan/INDEX.md` 等）做一次**本地** commit（守卫同步骤 3：先确认不在 main、仅本地不 push）
  5. 输出完成简报（见下方格式）

**完成简报格式**（单个 plan 模式和全部完成均使用）：

```
## Exec 完成简报

- 主题：<YYYY-MM-DD.主题>
- 执行范围：<全部 N 步 / 单步 plan-name>
- 完成情况：成功 N 步 / 跳过 M 步 / 阻塞 K 步
- 变更文件：
  - 实现：<路径列表>
  - 测试：<路径列表>
- 测试结果：✅ 全部通过（N 个测试） / ❌ 失败列表
- Review 结论：✅ 全部合规 / ⚠️ 已接受的例外列表
- 待解决：<阻塞项 / 已接受的例外 / 无>
- 下一步：<建议操作——如"运行 /review 做最终审查""继续执行剩余步骤""无">
```

### 遇到阻塞时

在 PROGRESS.md 当前步骤标 `blocked`、"阻塞"区记录原因、告知用户等待指示。

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

**更新**（步骤 3）：只改三处——当前步骤状态行、"当前"区、"阻塞"区。不重写整个文件。

## 失败处理

| 阶段 | 失败情况 | 处理 |
|---|---|---|
| Red | 编译失败 | 主 Agent 修 import/类型，重跑 |
| Red | 意外全 PASS | 行为已存在 → 跳过；测试错误 → 修正 |
| Green | 测试不过 | 反馈错误给 Impl Agent 重试 1 次 → 仍失败报告用户 |
| Green | 过度设计 | 反馈给 Impl Agent 简化后重跑测试 |
| Review | 发现违规 | 诊断归因（spec-defect/impl-defect/requirement-change）→ 确认 → 按类型修复 |
| Review | 测试遗漏 | impl-defect → 补测试(Red) → 改实现(Green) → 重新 Review |

exec 不重复其他 skill 的规则，但执行时**必须遵守已激活的 skill 约束**（如 golang-testing 的测试惯用法、golang-constraints 的架构约束等）。

## 硬约束

- Test Agent **禁看**函数清单和实现路径
- Impl Agent **禁看** spec 原文
- Review Agent **禁止**修改文件
- Agent prompt 自包含（不依赖对话上下文）
- 三个 Agent **必须串行**（Test → Impl → Review）
- 每步本地 commit 后**禁止自动 push**；在 main 分支上**禁止自动 commit**
- 输出中文

## 反面案例

- ❌ 不读 PROGRESS.md 就开始编码——可能重复实现已完成的步骤
- ❌ 完成步骤后不更新 PROGRESS.md——中断后进度丢失
- ❌ 一次实现多个 plan 文件——跳步可能破坏依赖关系
- ❌ 自行扩展 plan 未描述的功能——额外需求走 `/spec` → `/plan`
- ❌ 验证失败就标 done——必须修复通过后才能推进
- ❌ 阻塞时静默跳过——必须记录并告知用户
- ❌ Test Agent 看到函数清单——破坏隔离，测试会按实现思路写
- ❌ Impl Agent 看到 spec 原文——应该只关注让测试通过
