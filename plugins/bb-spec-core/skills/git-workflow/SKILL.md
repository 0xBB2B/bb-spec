---
name: git-workflow
description: Git workflow discipline — branch decisions before a task, an incremental local-commit rhythm (no immediate push), the six-section PR description, on-demand issue creation, and post-merge cleanup (local branch + remote ref + remote branch). Enforces no direct commits to main, branching directly off a clean main while spinning up an isolated git worktree (kept outside the repo, under ../ or ~/.worktree/) whenever in-flight work already exists, and pushing only after the whole feature is locally verified. TRIGGER when the user starts any non-main branch task (build a feature / fix a bug / open a branch), prepares to commit/push/open a PR, or cleans up after a merge. ｜ Git 开发流程纪律——覆盖"开始任务前的分支决策"、"阶段性本地 commit 节奏（不立即 push）"、"PR 描述六段式规范"、"按需建 issue 策略"、"合并后清理（本地分支 + 远程引用 + 远程分支）"。强制要求：禁止 main 直接提交、main 干净时直接开分支、已有在途工作（不在 main 或工作区有未提交改动）时从 main 新建隔离 worktree（置于 ../ 或 ~/.worktree/ 下）、整个功能本地验证后才推送。TRIGGER when：用户开始任何非 main 分支开发任务（"做个新功能"/"改 bug"/"开个分支"），或准备 commit/push/开 PR，或 PR 合并完成需要清理时。
user-invocable: false
---

# Git 工作流纪律

适用于：所有会改动代码的开发任务的完整生命周期。

## 0. 触发与跳过

**TRIGGER**：开始改动代码的工作 / 提到开分支 / 要求 commit / push / 开 PR / PR 合并后清理。
**SKIP**：纯咨询/阅读、极小打字纠错。

---

## 1. 分支策略

- **禁止在 main 直接提交**
- **worktree 仅用于隔离在途工作**：当手上已有进行中的任务时，新任务从 main 拉一棵 worktree 并行，互不打断。工作树必须与当前 repo 物理隔离：放在仓库**同级目录**（如 `../<repo>-<branch>`）或集中到 `~/.worktree/` 下统一管理，**禁止嵌套在当前 repo 工作目录内**（避免污染主仓库、被误 add / commit）

### 开始任务前必查

```bash
git branch --show-current        # 当前在哪个分支
git status --short               # 工作区是否有未提交改动
```

按"是否会干扰在途工作"决定开分支方式：

- **在 main 且工作区干净**（没有在途工作）→ `git pull` → 直接从 main 创建新分支开始工作，**无需 worktree**

  ```bash
  git pull && git switch -c <branch>
  ```

- **不在 main，或工作区有未提交改动**（已有在途工作）→ 为保证多任务互不干扰 → **从 main 新建 worktree** 再工作，不切换、不打断、不污染当前分支

  ```bash
  git worktree add ~/.worktree/<repo>-<branch> -b <branch> main
  ```

  - **例外**：若本次就是要**延续当前分支的同一任务**（不是开新活儿）→ 直接在当前分支继续，不新建 worktree。无法判断是延续还是新任务时，用 AskUserQuestion 让用户选：「延续当前分支」（同一任务接着干）/「从 main 新建 worktree」（开新活儿、隔离并行）。

### 多 repo 工作区（go.work / pnpm-workspace / Cargo / Gradle composite 等）

当项目由**多个 repo 组成、且构建靠相对路径跨 repo 引用**（如 `go.work` 的 `./service-a`、`pnpm-workspace.yaml`、Cargo workspace 的 `path = "../lib"`、Gradle composite build）时：

- **禁止只对单个成员 repo 拉 worktree**——会打散工作区的相对布局，`./service-b` 这类引用指空，整个 workspace 解析失败。
- **禁止用整目录复制替代 worktree**——放弃隔离与一键清理、磁盘翻倍、副本易 drift。
- 正确做法：**建一个统一父目录（普通目录、非 repo），对每个参与 workspace 的成员 repo 各拉一棵 worktree 到该父目录下，复原原有相对布局**。每个 repo 仍是真 worktree（改动可追踪、可独立 commit/push、与主仓库共享对象、`git worktree remove` 一键清理）。

  ```bash
  mkdir -p ~/.worktree/<project>-<branch>
  git -C <repo-root>/service-a worktree add ~/.worktree/<project>-<branch>/service-a -b <branch> main
  git -C <repo-root>/service-b worktree add ~/.worktree/<project>-<branch>/service-b -b <branch> main
  ```

- **工作区根文件**（`go.work` / `pnpm-workspace.yaml` 等）位于非 repo 的容器层、不被任何 git 跟踪，拉 worktree 时不会自动带过来——**需手动放一份到统一父目录**（相对路径原样可用，无需改）。
- 清理对称：各成员 repo 各自 `git worktree remove`，统一父目录手动删。

---

## 2. 阶段性本地 commit

- 每完成一个可独立验证的子任务 → `git commit`（本地）
- commit message 遵循仓库历史风格（先 `git log --oneline -20` 看一眼）
- **禁止阶段性 commit 后立即 push**（本地未推时可 amend/rebase 修正）
- 任务队列还有待办 → commit 后直接继续，不中断询问

---

## 3. 推送门槛

**仅当**满足所有条件才进入推送：功能本地全部完成 + 所有测试通过 + 用户确认。

### 多 PR 依赖关系

有依赖 → 按顺序逐个 push + 开 PR，前一个合并后再推下一个。
无依赖 → 可并行推送，但仍需本地验证完成后统一开始。

---

## 4. PR 描述（六段式，整体 ≤ 50 行）

```markdown
## 背景
当前状态、相关模块、为什么现在做。

## 需求
具体动因、要解决的问题、不做的代价。

## 方案
实际改动点、范围边界、影响面。

## 结果
改动后的行为变化、用户可感知的差异。

## 测试
验证方式、覆盖场景。

## 规范
遵循或涉及的规范（无 spec 时写"无"）。
```

reviewer 不跳转 issue 也能完整理解。禁止：只一行 What / 仅链接 issue / 仅粘贴 commit。

---

## 5. 按需建 issue（默认不建）

**建的场景**：跨多 PR 长周期追踪 / 暂不实施的 bug 记录 / 外部 triage。
issue 正文包含背景、需求、方案。PR 关联 issue 时顶部写 `Closes #<num>`。

---

## 6. 合并后清理

```bash
git checkout main && git pull origin main
git rev-parse --abbrev-ref HEAD           # 确认在 main
git branch -D <branch>                    # squash merge 后 -d 会拒绝
# 探测远程分支是否存在再删
git ls-remote --exit-code --heads origin <branch> && git push origin --delete <branch>
git fetch -p                              # 裁剪远程引用
```
