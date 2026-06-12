---
name: exec
description: Three-agent isolated execution of a plan (Test→Impl→Review), persisting progress to PROGRESS.md after every step, with lossless resume across sessions or after /clear. TRIGGER — /exec / start implementing / continue executing the plan / resume from the last checkpoint. ｜ 三 Agent 隔离执行 plan 实施计划（Test→Impl→Review），每完成一步立即持久化进度到 PROGRESS.md，支持跨会话 / `/clear` 后无损续接。常见触发：用户输入 `/exec`、"开始实施"、"继续执行 plan"、"从上次断点继续"。
argument-hint: <YYYY-MM-DD.主题>[/<plan名>]
---

# Exec 计划执行

三 Agent 隔离执行 plan：Test(Red) → Impl(Green) → Review(合规)，每步完成持久化到 PROGRESS.md，支持断点续接。

## 核心原则（兼硬约束）

1. **逐步执行**：一次只实现一个 plan 文件，验证通过再进入下一步；跳步会破坏依赖关系
2. **角色隔离**：三个 Agent 各看各的输入互不可见——Test **禁看**函数清单和实现路径，Impl **禁看** spec 原文，Review **禁止**修改文件
3. **三 Agent 串行**：必须 Test → Impl → Review 顺序；每个 Agent prompt 自包含，不依赖对话上下文
4. **进度即时持久化**：每步完成后立即更新 PROGRESS.md（不攒批），它是唯一进度事实源，重启后仅凭此文件恢复
5. **Plan 即合同**：严格按 plan 的函数清单和业务规则实现，不自行扩展（额外需求走 `/spec` → `/plan`）；新增第三方库以 plan「新增第三方依赖」清单为上限——该清单已在 plan 批准时获用户授权，清单外需要新库时必须停下询问用户，**禁自行 import**
6. **如实上报**：验证失败禁标 done；阻塞禁静默跳过——必须记录并告知用户
7. **commit 守卫**：每步本地 commit 后**禁止自动 push**；在 main 分支上**禁止自动 commit**
8. **遵守已激活 skill 约束**：exec 不重复其他 skill 的规则，但执行时必须遵守已激活约束（如 golang-testing 测试惯用法、golang-constraints 架构约束）
9. **输出中文**

## Agent 定义

三个 Agent 通过 plugin 注册的 `subagent_type` 派工，数据通过 `prompt` 传入：

| Agent | subagent_type | 角色 |
|---|---|---|
| Test Agent | `bb-spec-workflow:test-engineer` | 测试工程师：只读 spec 写测试 |
| Impl Agent | `bb-spec-workflow:impl-engineer` | 实现工程师：只看测试写实现 |
| Review Agent | `bb-spec-workflow:spec-reviewer` | 合规审查者：对照 spec 检查产出 |

**信息隔离矩阵**：

| 输入 | Test | Impl | Review |
|---|---|---|---|
| spec 规则（plan「业务规则」区） | ✅ | ❌ | ✅ |
| 行为预期（plan「验证方式」区） | ✅ | ❌ | ✅ |
| 函数清单 + 文件路径 | ❌ | ✅ | ❌ |
| 成品定义（plan「成品定义」区，如有） | ❌ | ✅ | ❌ |
| 新增第三方依赖清单（plan「新增第三方依赖」区，如有） | ❌ | ✅ | ❌ |
| 协作关系 | ❌ | ✅ | ❌ |
| 项目约束（语言/框架/架构） | ✅ | ✅ | ❌ |
| 项目测试惯例 | ✅ | ❌ | ❌ |
| Test Agent 写的测试文件 | — | ✅ | ✅ |
| Impl Agent 写的代码 | — | — | ✅ |

## 工作流

### 步骤 0：读取配置 + 解析参数定位目标

`cat .bb-spec.yaml 2>/dev/null` 取 `docs_dir`（缺省 `.bb-spec/docs`），记作 `${DOCS_DIR}`。读 `${DOCS_DIR}/plan/INDEX.md`，按参数形式决定行为：

| 调用方式 | 行为 |
|---|---|
| `/exec` | 自动选主题 → 询问执行范围 |
| `/exec <YYYY-MM-DD>.<主题>` | 指定主题 → 询问执行范围 |
| `/exec <YYYY-MM-DD>.<主题>/<plan名>` | 指定主题 + 单个 plan，只执行该 plan |

**主题定位**（无参数或仅指定主题时）：INDEX.md 不存在 → 告知"建议先运行 `/plan`"终止；无 `进行中` 主题 → 告知"所有主题已完成"终止；仅一个 `进行中` → 自动选中；多个 → 列出让用户选。

### 步骤 1：确定执行范围

读 `PROGRESS.md`（不存在则初始化，所有步骤标 `pending`）。

- **指定了单个 plan**：直接跳到该 plan 执行，不影响其他步骤状态
- **未指定**：展示进度概况（已完成 N/M 步），用 AskUserQuestion 询问范围——**全部执行**（从第一个非 `done` 步骤依次到最后）或**选择单个**（列出未完成步骤让用户选）

### 步骤 2：执行当前步骤

读当前步骤对应 plan `.md`，按隔离矩阵拆为三份 Agent 输入。同时扫描项目已有测试文件，提取测试惯例（框架、目录、命名风格）。

**2a. Test Agent — Red**：派 `bb-spec-workflow:test-engineer`，prompt 传「业务规则」+「验证方式」+ 项目测试惯例。主 Agent 验证：编译通过 + 断言失败 → ✅ Red 进 2b；编译失败 → 主 Agent 修 import/类型后重跑；意外全 PASS → 行为已存在则跳过，测试错误则修正。

**2b. Impl Agent — Green**：派 `bb-spec-workflow:impl-engineer`，prompt 传「函数清单 + 文件路径 + 协作关系 + 成品定义（如有）+ 新增第三方依赖清单（如有）」+ 测试文件路径。主 Agent 验证：全部通过 → **依赖守卫**（diff `go.mod` / `package.json` 等依赖文件，新增第三方库不得超出 plan「新增第三方依赖」清单；超出则令 Impl Agent 改用标准库 / 已有依赖重跑，确属必需时停下询问用户、同意后先补录 plan 清单再继续）+ 简洁性审视（是否用最少实现解决问题、有无 plan 未要求的抽象/防御/功能），发现过度设计则反馈 Impl Agent 简化后重跑、通过则 ✅ Green 进 2c；有失败 → 反馈错误给 Impl Agent 重试（最多 1 次）→ 仍失败报告用户。

**2c. Review Agent — Spec 合规**：派 `bb-spec-workflow:spec-reviewer`，prompt 传「业务规则」+「验证方式」+ 所有变更文件路径。主 Agent 处理：全 ✅ → 进步骤 3；有 ❌ 或 ⚠️ → 用 AskUserQuestion 让用户选 **修复** / **接受**（记录到 PROGRESS.md）/ **暂停**（标 blocked）。

选"修复"时先诊断归因再动手：

1. **归因**：对照 spec → plan → 实现 → 测试链路，判定根因——spec-defect（定义层出错）/ impl-defect（spec 正确但实现不符）/ requirement-change（用户实际需要与 spec 不同）
2. **确认**：向用户展示归因 + 证据，确认后再修
3. **按类型修复**：spec-defect → 改 spec → 级联 plan → TDD 重新实现（Test→Impl→Review）；impl-defect → 补测试(Red) → 改实现(Green) → 重新 Review；requirement-change → 用户确认新需求 → 更新 spec → 级联 plan + 实现
4. **回归验证**：全量测试 + spec 合规检查

### 步骤 3：持久化进度

验证通过后**立即**更新 PROGRESS.md：当前步骤标 `done` + 填完成时间、"当前"区更新为下一步骤、清除已解决阻塞项。

随后把本步骤产出做一次**本地** commit：先 `git branch --show-current` 确认分支（**在 main 上则跳过自动 commit**并提示按 git-workflow 先建分支）；只提交本步骤涉及文件（实现 + 测试 + `PROGRESS.md`）；message 遵循仓库历史风格（先 `git log --oneline -10`）、不硬编码类型前缀；**仅本地不自动 push**；blocked / 未通过的步骤不 commit。

### 步骤 4：循环或收尾

- **单个 plan 模式**：当前 plan 完成即停，输出完成简报
- **全部执行 + 还有后续步骤**：回步骤 2 执行下一步
- **全部执行 + 全部完成**：① 更新根 `plan/INDEX.md`，该主题状态改 `已完成` 填完成时间 ② 运行全量测试确认无回归 ③ **归档确认**：已删除的 spec 已从 `spec/INDEX.md` 移除、spec 内容与实现一致 ④ **路线图衔接**：若 `${DOCS_DIR}/plan/ROADMAP.md` 存在且当前主题对应其中某批次，把该批状态更新为 `已完成`、在完成简报里追加「**验证门**」段（列出 ROADMAP 中记录的该批验证门检查项）并提示「确认验证门通过后运行 `/plan` 生成下一批」；不存在 ROADMAP 则跳过 ⑤ 把收尾改动做一次本地 commit（守卫同步骤 3）⑥ 输出完成简报

**遇阻塞时**：在 PROGRESS.md 当前步骤标 `blocked`、"阻塞"区记录原因、告知用户等待指示。

**完成简报格式**（单个 plan 模式和全部完成均用）：

```
## Exec 完成简报
- 主题：<YYYY-MM-DD.主题>
- 执行范围：<全部 N 步 / 单步 plan-name>
- 完成情况：成功 N 步 / 跳过 M 步 / 阻塞 K 步
- 变更文件：实现<路径> / 测试<路径>
- 测试结果：✅ 全部通过（N 个测试） / ❌ 失败列表
- Review 结论：✅ 全部合规 / ⚠️ 已接受的例外列表
- 待解决：<阻塞项 / 已接受的例外 / 无>
- 验证门（仅路线图批次完成时）：<本批 ROADMAP 中记录的验证门检查项>
- 下一步：<如"运行 /review 做最终审查" / "继续执行剩余步骤" / 路线图模式："**本批与下一批上下文无关联，建议先 `/clear` 清空上下文，再运行 `/plan` 生成下一批**" / "无">
```

## PROGRESS.md 操作规范

**初始化**（步骤 1）：

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

**更新**（步骤 3）：只改三处——当前步骤状态行、"当前"区、"阻塞"区，不重写整个文件。
