---
name: git-workflow
description: Git 开发流程纪律——禁 main 直接提交；新任务前扫工作区根，有 workspace 标记走多 repo 工作区，否则 `question` 工具 询问 worktree（默认）或切分支；worktree 一律落 `~/.bb-spec/worktrees/` 下、禁嵌套当前 repo / 禁放 sibling 目录；本地 commit 不立即 push、整功能验证完才推；合并后清理本地+远程。触发：开始改代码、提到开分支、要求 commit/push/开 PR、PR 合并后清理。跳过：纯咨询/阅读、极小打字纠错。
---

# Git 工作流纪律

适用于：所有会改动代码的开发任务的完整生命周期。

## 路径选择（进文档第一步必看）

开任务前先扫一眼**工作区根目录**，按下表分流，不要凭"看着像普通仓库"就默认单仓路径：

| 检测信号（根目录存在以下任一） | 走哪条 |
|---|---|
| `go.work` / `pnpm-workspace.yaml`（或 `package.json` 含 `workspaces` 字段）/ `Cargo.toml` 含 `[workspace]` / `settings.gradle(.kts)` 含 `includeBuild` | → **§1「多 repo 工作区」**：统一父目录 + 各成员 repo 各拉 worktree + 根文件手拷，**禁止只对单个成员 repo 拉 worktree** |
| 其他（普通单仓） | → **§1「开新任务一律询问开分支方式」**：单仓 worktree 或直接切分支，按 `question` 工具 走 |

> 判断时机：在执行"开始任务前必查"那两条 `git` 命令**之前**就先扫一眼根目录信号，分流错了后面整个 §1 都会跑偏。

---

## 0. 触发与跳过

**TRIGGER**：开始改动代码的工作 / 提到开分支 / 要求 commit / push / 开 PR / PR 合并后清理。
**SKIP**：纯咨询/阅读、极小打字纠错。

---

## 1. 分支策略

- **禁止在 main 直接提交**
- **worktree 用于隔离并行工作**：从 main 拉一棵 worktree，与当前分支互不打断。工作树必须与当前 repo 物理隔离：统一集中到 `~/.bb-spec/worktrees/` 下管理，**禁止嵌套在当前 repo 工作目录内**（避免污染主仓库、被误 add / commit）

### 开始任务前必查

```bash
git branch --show-current        # 当前在哪个分支
git status --short               # 工作区是否有未提交改动
```

### 开新任务一律询问开分支方式

开任何新任务前，用 **`question` 工具** 让用户选开分支方式，**默认 worktree**：

- **worktree（默认）** → 从 main 新建隔离 worktree 并行，不切换、不打断、不污染当前分支

  ```bash
  git worktree add ~/.bb-spec/worktrees/<repo>-<branch> -b <branch> main
  ```

- **直接切分支** → 在当前 repo 直接从 main 创建新分支开始工作（要求当前工作区干净）

  ```bash
  git pull && git switch -c <branch>
  ```

**唯一例外（不问）**：本次是**延续当前分支的同一任务**（不是开新活儿）→ 直接在当前分支继续，既不新建 worktree 也不切分支。无法判断是延续还是新任务时，照常 `question` 工具 询问。

### 多 repo 工作区（go.work / pnpm-workspace / Cargo / Gradle composite 等）

当项目由**多个 repo 组成、且构建靠相对路径跨 repo 引用**（如 `go.work` 的 `./service-a`、`pnpm-workspace.yaml`、Cargo workspace 的 `path = "../lib"`、Gradle composite build）时：

- **禁止只对单个成员 repo 拉 worktree**——会打散工作区的相对布局，`./service-b` 这类引用指空，整个 workspace 解析失败。
- **禁止用整目录复制替代 worktree**——放弃隔离与一键清理、磁盘翻倍、副本易 drift。
- 正确做法：**建一个统一父目录（普通目录、非 repo），对每个参与 workspace 的成员 repo 各拉一棵 worktree 到该父目录下，复原原有相对布局**。每个 repo 仍是真 worktree（改动可追踪、可独立 commit/push、与主仓库共享对象、`git worktree remove` 一键清理）。

  ```bash
  mkdir -p ~/.bb-spec/worktrees/<project>-<branch>
  git -C <repo-root>/service-a worktree add ~/.bb-spec/worktrees/<project>-<branch>/service-a -b <branch> main
  git -C <repo-root>/service-b worktree add ~/.bb-spec/worktrees/<project>-<branch>/service-b -b <branch> main
  ```

- **工作区根文件**（`go.work` / `pnpm-workspace.yaml` 等）位于非 repo 的容器层、不被任何 git 跟踪，拉 worktree 时不会自动带过来——**需手动放一份到统一父目录**（相对路径原样可用，无需改）。
- 清理对称：各成员 repo 各自 `git worktree remove`，统一父目录手动删。
- **依然要 `question` 工具**：多 repo 场景的询问点不是"worktree vs 直接切分支"（工作区根本身不是 repo、无法直接切），而是 **① 本次任务涉及哪些成员 repo**（避免给无关 repo 拉空分支）**② 分支名**。问完再按确认范围执行上面的 `worktree add`。

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

## 6. 合并后清理（按开分支方式分流）

判定当前是否在 linked worktree：

```bash
[ "$(git rev-parse --git-dir)" != "$(git rev-parse --git-common-dir)" ] && echo "linked worktree"
```

### 直接切分支模式

```bash
git checkout main && git pull origin main
git rev-parse --abbrev-ref HEAD           # 确认在 main
git branch -D <branch>                    # squash merge 后 -d 会拒绝
# 探测远程分支是否存在再删
git ls-remote --exit-code --heads origin <branch> && git push origin --delete <branch>
git fetch -p                              # 裁剪远程引用
```

### worktree 模式

主仓库本就停在 main，**禁止在 worktree 内 `git checkout main`**（该分支被主仓库占用，会报错）。改为先回主仓库、移除 worktree、再删分支：

```bash
WT="$(git rev-parse --show-toplevel)"            # 当前 worktree 路径（移除前先取）
cd "$(git rev-parse --git-common-dir)/.." && pwd # 回到主仓库根（已在 main）
git pull origin main
git worktree remove "$WT"                        # 有未提交改动会拒绝——此时应已 commit+push
git branch -D <branch>                           # worktree 移除后才能删其分支
git ls-remote --exit-code --heads origin <branch> && git push origin --delete <branch>
git fetch -p && git worktree prune               # 裁剪远程引用 + worktree 元数据
```
