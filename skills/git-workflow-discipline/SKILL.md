---
name: git-workflow-discipline
description: Git 开发流程纪律——覆盖"开始任务前的分支决策"、"阶段性本地 commit 节奏（不立即 push）"、"PR 描述六段式规范"、"按需建 issue 策略"、"合并后清理（本地分支 + 远程引用 + 远程分支）"。强制要求：禁止 main 直接提交、禁止自作主张创建 worktree、整个功能本地验证后才推送。TRIGGER when：用户开始任何非 main 分支开发任务（"做个新功能"/"改 bug"/"开个分支"），或准备 commit/push/开 PR，或 PR 合并完成需要清理时。
---

# Git 工作流纪律

适用于：所有会改动代码的开发任务的完整生命周期。

## 0. 触发与跳过

**TRIGGER**：开始改动代码的工作 / 提到开分支 / 要求 commit / push / 开 PR / PR 合并后清理。
**SKIP**：纯咨询/阅读、极小打字纠错。

---

## 1. 分支策略

- **禁止在 main 直接提交**
- **禁止自作主张创建 worktree**（用户明确要求才可以）

### 开始任务前必查

```bash
git branch --show-current
```

- **在 main** → `git pull` → 创建新分支
- **不在 main** → **必须问用户**：①基于当前分支继续/新开子分支 ②切回 main 后再开新分支。得到答复前不自行切换。

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
