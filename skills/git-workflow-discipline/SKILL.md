---
name: git-workflow-discipline
description: Git 开发流程纪律——覆盖"开始任务前的分支决策"、"阶段性本地 commit 节奏（不立即 push）"、"PR 描述三段式规范"、"按需建 issue 策略"、"合并后清理（本地分支 + 远程引用 + 远程分支）"。强制要求：禁止 main 直接提交、禁止自作主张创建 worktree、整个功能本地验证后才推送。TRIGGER when：用户开始任何非 main 分支开发任务（"做个新功能"/"改 bug"/"开个分支"），或准备 commit/push/开 PR，或 PR 合并完成需要清理时。与 git-push-pr（用户主动调用的推送流程）互补：前者是"始终生效的行为约束"，后者是"被显式触发的执行流程"。
---

# Git 工作流纪律

适用于：**所有非纯阅读 / 纯咨询的开发任务的整个生命周期**——从决定开发新内容那一刻起，到 PR 合并清理完成为止。

> 核心理念：**Git 流程纪律不是工具，是约束。** 工具（如 `/git-push-pr`）只在被调用时执行；纪律必须在每一个会改动代码的瞬间都生效。

## 0. 触发场景

**TRIGGER**（命中任一即应应用本纪律）：

- 用户要求开始任何会改动代码、配置、文档的工作（"做个新功能"、"改 bug"、"重构 X"、"加个 Y"）
- 用户提到 "开个分支" / "切个分支" / "新建分支"
- 用户要求 commit（"提交一下"、"commit 一下"）
- 用户要求 push / 开 PR（此时除应用本纪律外，可建议用户使用 `/git-push-pr` skill 完成具体执行）
- PR / MR 合并完成后（需要清理本地与远程残留）
- 用户询问 "现在该开新分支还是继续"

**SKIP**（以下情况本纪律不适用）：

- 纯咨询 / 纯阅读 / 纯解释代码（不涉及任何文件改动）
- 单行打字纠错、单字符修复等极小改动且明确无需走流程
- 用户授权后的 `git worktree` 场景（仍需遵守 PR 描述规范、合并后清理）

---

## 1. 分支策略（开始任务前必查）

### 1.1 禁止在 main 分支直接提交

**绝对禁止**：在 `main`（或 `master`）分支上提交任何内容。

### 1.2 新内容必须隔离开发

每次新增或修改内容时，**默认通过创建新分支**进行开发。

### 1.3 禁止自作主张创建 worktree

除非用户**明确**要求使用 `git worktree`，否则一律采用新分支方式工作。

即使判断为"非 worktree 不可"的场景（如需并行多分支同时编译/运行），也必须**先向用户说明原因并征得同意**再创建 worktree。不得自作主张。

### 1.4 开始任务前的标准检查流程

任何开发任务开始前，**第一步**先用以下命令检查当前分支：

```bash
git branch --show-current
```

按以下分叉处理：

**分叉 A：当前在 `main`（或 `master`）**

- 先 `git pull` 拉取最新主干
- 再创建新分支后继续
- 避免基于过期代码开发导致后续冲突或重复劳动

```bash
git switch main
git pull
git switch -c <new-branch-name>
```

**分叉 B：当前不在 `main`**

**必须先询问用户**两种意图中的哪一种，得到明确答复前**不得**自行切换或新开分支：

1. **基于当前分支继续 / 新开子分支**——多分支并行场景：
   - 当前分支正在进行中、需要在其基础上叠加工作
   - hotfix 穿插
   - 依赖未合并的前置 PR

2. **切回 `main` 后再开新分支**——与当前分支无依赖关系的全新任务
   - 选此项时按分叉 A 流程执行：`git switch main && git pull`，再开新分支

---

## 2. 阶段性本地 commit（仅 commit，不 push）

### 2.1 节奏

每完成一个**可独立验证的子任务**，必须先 `git commit` 在**本地**保存进度：

- TodoWrite 中一项标记 `completed`
- 一个功能点的 Red-Green-Refactor 闭环完成
- 一个独立 bug 的修复完成

commit message **遵循当前仓库历史风格**（先 `git log --oneline -20` 看一眼现有风格再写）。

### 2.2 仅本地 commit，禁止立即 push

**禁止**在阶段性 commit 完成后立即 `git push` 或开 PR。

**原因**：后续修改中可能发现前面的 commit 错误。本地未推送时可用 `git commit --amend` / `git rebase -i` 修正；一旦推送并合入 main，再发现错误只能另开 PR 反向修复，徒增噪音。

### 2.3 不阻塞后续任务

若任务队列中仍有进行中或待处理项，commit 后**直接继续下一阶段**，无需中断询问用户。

---

## 3. 整个功能本地验证后才推送

### 3.1 推送门槛

**仅当**满足以下所有条件后，才进入推送流程：

- 当前任务对应的功能在本地**全部修改完成**
- **所有相关测试**通过（单元测试 / 集成测试 / 端到端验证）
- 已向用户确认后续动作（push / 开 PR 的具体方式）

> 实际推送与开 PR 的执行流程，建议调用 `/git-push-pr` skill（覆盖测试、push、PR 创建、合并、清理的完整链路）。

### 3.2 多 PR 依赖关系处理

若本次工作按依赖关系拆成多个 PR：

1. **按依赖顺序逐个 push + 开 PR**
2. **前一个 PR 合并完成**（已 merged 至目标分支）后，再 `git switch` 到下一个分支、`git rebase` 到最新目标分支，然后 push + 开 PR
3. **严禁并行推送多个有依赖关系的 PR**——这会让"发现前面错误时无法本地 rebase 修正"的风险扩散到链上每一个未合并 PR

### 3.3 多 PR 无依赖关系处理

无依赖关系的多 PR（修改的模块互不影响）可并行推送，**但仍需在所有本地验证完成后**再统一开始推送。

---

## 4. PR 描述规范（三段式）

### 4.1 强制结构

所有 PR / MR 描述必须分**三段**写明上下文，**不能只写 What**。

reviewer **不跳转 issue、不读 commit** 也能完整理解本次改动。

```markdown
## 背景 (Context)
当前状态、相关模块/链路、为什么现在要做。

## 原因 (Why)
具体动因、要解决的问题或痛点、不做的代价。

## 优化方案 (How)
本 PR 实际改动点、范围边界、验证方式、影响面；如有备选方案需简述取舍。
```

### 4.2 禁止写法

- ❌ 只有一行 What（"修复登录 bug" / "重构 X 模块"）
- ❌ 仅链接到 issue 让 reviewer 自己跳转
- ❌ 仅粘贴 commit messages 拼接
- ❌ "见标题" / "代码即文档" 这类敷衍

---

## 5. 按需建 issue（默认不建）

PR 描述已承载 Context/Why/How，**单 PR 工作不再强制建 issue**。

### 5.1 仅以下场景才建

- **跨多 PR / 长周期追踪**：大重构、迁移、初始化任务拆成多个 PR，需要全局追踪节奏与范围
- **暂不实施的 bug / 想法**：发现问题但不立刻修，需要落地记录避免遗忘
- **他人报告需要 triage**：外部反馈、协作方提单等需要先收口再决定是否做

### 5.2 issue 正文同样三段式

建 issue 时正文同样按 **Context/Why/How** 三段组织。

### 5.3 CLI 命令（GitHub vs GitLab 参数名不通用）

**GitHub (gh)**：
```bash
gh issue create --title "..." --body "..." --label "..."
gh issue edit <num> --body "..."
gh issue comment <num> --body "..."
```

**GitLab (glab)**：
```bash
glab issue create --title "..." --description "..." --label "..."
glab issue update <num> --description "..."
glab issue note create <num> --message "..."
```

### 5.4 PR 与 issue 关联

建了 issue 的 PR 顶部一行写：

```
Closes #<num>
```

若 PR 合入**非默认分支**（关键字不会自动触发关闭），由 Agent 在合并完成后**主动关闭**：

```bash
# GitHub
gh issue close <num> --comment "..."

# GitLab
glab issue close <num>
```

并在对话中**回报已关闭**，不把这一步推给用户（除非用户明确说"我自己关"）。

---

## 6. 合并后清理（必做，不可省）

每次 PR / MR 合并完成后，**Agent 必须立即执行清理**，避免本地与远端分支列表随时间膨胀。

> ⚠️ 如果用户通过 `/git-push-pr` 完成的推送与合并，该 skill 的步骤 8、9 已完成本节清理工作，无需重复执行。**仅当用户绕过 `/git-push-pr` 直接合并时**，按下列步骤手工清理。

### 6.1 标准清理流程

```bash
# 1. 切回主干并同步最新代码
git switch main
git pull

# 2. 同步远端引用并清理本地已失效的 remote-tracking 分支
git fetch --prune

# 3. 删除已合并的本地分支
git branch -d <branch>     # 优先用 -d（保留安全检查）
# 若 squash/rebase merge 让 git 检测不到合并关系导致 -d 拒绝：
gh pr view <num> --json state -q .state          # GitHub 确认已 merged
glab mr view <num> --output json | jq -r .state  # GitLab 确认已 merged
git branch -D <branch>     # 确认后强删

# 4. 远程分支若 PR 平台未配置自动删除，手动删除
git push origin --delete <branch>
```

### 6.2 平台自动删除分支配置

部分仓库已开启"合并后自动删除源分支"，此时步骤 4 不需要执行：

- **GitHub**：仓库设置 → "Automatically delete head branches"
- **GitLab**：项目设置 → "Delete source branch when merge request is accepted by default"

未开启的仓库需手动执行步骤 4。

### 6.3 清理目的

保持 `git branch` / `git branch -r` 输出始终反映**进行中的工作**，避免历史分支堆积形成认知噪音与误操作风险。

---

## 7. 与 git-push-pr skill 的边界

| 场景 | 本 skill（纪律） | git-push-pr（流程） |
|---|---|---|
| 用户开始新任务 | ✅ 检查分支、决定起点 | ❌ |
| 阶段性 commit | ✅ 节奏控制（不 push） | ❌ |
| 准备推送 + 开 PR | ✅ 提醒"先本地验证完整功能" | ✅ 用户主动 `/git-push-pr` 执行 |
| PR 描述规范 | ✅ 强制三段式 | ⚠️ 仅生成简短描述（应由本 skill 补全） |
| PR 合并 / 关闭 | ❌ | ✅ 执行合并操作 |
| 合并后清理 | ✅ 兜底（用户绕过流程时） | ✅ 内置清理 |

**协作原则**：本 skill 是"心智模型"，`git-push-pr` 是"执行手册"。用户主动调用 `/git-push-pr` 时，按其流程执行；其他所有时候，按本 skill 的纪律行事。

---

## 8. 自检清单

任务的不同阶段对照以下清单：

**开始任务前**：
- [ ] 已用 `git branch --show-current` 检查当前分支
- [ ] 当前在 main → 已 pull 后再开新分支
- [ ] 当前不在 main → 已询问用户两种意图

**开发过程中**：
- [ ] 每完成一个可验证子任务就本地 commit
- [ ] commit message 遵循仓库历史风格
- [ ] **没有**在阶段性 commit 后立即 push

**准备推送时**：
- [ ] 整个功能本地完成
- [ ] 所有测试通过
- [ ] 已与用户确认推送方式（建议引导用户调用 `/git-push-pr`）

**写 PR 描述时**：
- [ ] 包含 Context / Why / How 三段
- [ ] reviewer 不跳转 issue 也能看懂

**PR 合并后**：
- [ ] 已切回 main 并 pull
- [ ] 已执行 `git fetch --prune`
- [ ] 已删除本地分支
- [ ] 已删除远程分支（若平台未自动删除）
