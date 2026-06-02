---
name: git-push-pr
description: Use when the user wants to push local code to a remote via the PR flow. Auto-detects single / multiple repos; supports batch or selective handling; a repo dir can be passed as an argument. Before pushing, if .bb-spec/docs/spec/INDEX.md exists at the repo or project root, runs a branch-spec self-check (pre-review) — a subagent diffs the current branch vs main against the spec, the main agent fixes violations and re-reviews in a loop, then drafts a concise 6-section PR description (background / requirement / approach / result / tests / spec, under 50 lines) used directly as the PR body. TRIGGER — push it / open a PR / ship the code / self-check before a PR / review this branch against the spec. ｜ 用户想把本地代码通过 PR 流程推送到远程仓库。自动检测单 / 多仓库，支持批量或选择性处理；用户也可通过参数指定单个仓库目录。推送前若仓库根或项目根（CWD）存在 `.bb-spec/docs/spec/INDEX.md`，会自动跑一次**分支规范自查（pre-review）**——派 subagent 拿 spec 比对当前分支 vs main 的 diff，违规由主 agent 直接修复并循环复审，通过后生成一份**简洁的 6 段 PR 描述草稿**（背景 / 需求 / 方案 / 结果 / 测试 / 规范，整体不超过 50 行），直接用作创建 PR 的 body。常见触发："push 一下"、"提个 PR"、"代码推上去"、"准备发 PR"、"开 PR 之前帮我自查一下"、"对照规范看下这个分支"。
---

# 仓库提交与 PR 流程

## 概览

创建分支 → 跑测试 → 提交 → **分支规范自查 + PR 草稿**（仅当仓库或项目根存在 `.bb-spec/docs/spec/INDEX.md`）→ 推送 → 创建 PR → 处理 PR → 清理分支。

## 参数

可附带目录路径指定仓库：`/git-push-pr ./my-project`。未指定则自动检测当前目录。

---

## 1. 识别范围

- 当前目录是 git 仓库 → 单仓库处理
- 当前目录下多个 git 子目录 → 列出，询问用户选哪些
- 参数指定目录 → 只处理该目录

**Shell 变量名禁区**：禁止用 `status`、`path`、`PATH`、`SECONDS` 等保留名。

## 2. 确认分支

`git branch --show-current`。在 main/master 上 → 必须先创建新分支。已在功能分支 → 继续。

## 3. 跑全量测试

**优先级**：Makefile `test`/`tests`/`check`/`ci`/`test-all` → 项目类型推断（`go test ./...` / `bun test` / `cargo test` / `pytest`）→ 问用户。
**失败**：立即停止，报告给用户。用户明确"跳过测试"时才可略过。

## 4. 提交未暂存改动

`git status --short`。有改动 → 明确暂存相关文件（禁止 `git add .`）+ commit。不确定的文件（`.env`、凭据）必须先问。工作区干净 → 跳过。

## 4.5 分支规范自查与 PR 草稿（pre-review）

### 前置探测

两级查找 spec：

1. **仓库根**：读取仓库根 `.bb-spec.yaml` 的 `docs_dir`（默认 `.bb-spec/docs`），检查 `{docs_dir}/spec/INDEX.md`
2. **项目根（CWD）**：若仓库根未找到，再检查调用目录（即 CWD，多仓库场景下通常是外层项目根）的 `.bb-spec/docs/spec/INDEX.md`

任一位置命中 → 以该路径作为 spec 来源进入自查；两处都不存在 → 跳过整个 4.5。

### 核心原则

1. 以规范为准，不以习惯为准
2. 直修不商量（规范本身冲突或缺失时才停下问）
3. 循环到通过（最多 3 轮）
4. PR 草稿整体 ≤ 50 行

### 4.5.1 派 subagent review

`Agent`（`subagent_type: general-purpose`），prompt 包含：
- `git diff <base>...HEAD` + `git log <base>..HEAD --oneline`
- 规范来源：**仅** `.bb-spec/docs/spec/` 下内容（禁引入外部最佳实践）
- 输出格式：`## 结论 PASS|FAIL` → `## 违规项`（file:line + 违反哪条 + 建议修法）→ `## 备注`
- subagent **只读不改**

### 4.5.2 主 agent 修复

- PASS → 跳到 4.5.3
- FAIL → 逐条按建议 Edit 改代码（只改违规处）→ commit → 重新派 subagent 复审 → ≥ 3 轮仍 FAIL → 停下报告分歧

### 4.5.3 生成 PR 描述草稿（6 段，≤ 50 行）

```markdown
## 背景
## 需求
## 方案
## 结果
## 测试
## 规范
```

直接作为步骤 6 的 `--body`。

## 5. 推送到远程

`git push -u origin <branch>`。失败 → 停止报告。

## 6. 创建 PR

根据 `git remote get-url origin` 判断平台（github → `gh`，gitlab → `glab`）。
- 标题 ≤ 70 字
- body：4.5 跑过 → 用 6 段草稿；4.5 跳过 → 简短 bullet + 标注「未跑 pre-review」

## 7. 处理 PR

创建后询问用户（除非已显式声明）：

1. **自动合并**：`gh pr merge --squash --auto --delete-branch`（GitLab 用 `--auto-merge --remove-source-branch`）
2. **已合并**：查询状态校验 → MERGED 才继续清理
3. **关闭 PR**：`gh pr close --delete-branch` → 清理

### 自动合并后状态处理

- 已合并 → 步骤 8、9
- 仍 OPEN → 查 CI：全通过则等一下重查；进行中则告知用户挂起跳过清理；**CI 失败** → 取消自动合并 → 拉失败日志 → 机械性失败（lint/format/lockfile）自行修复后重设；业务性失败停下报告
- 冲突 → `git rebase origin/main`：机械性冲突自行解决 + `--force-with-lease` 重推；业务性冲突停下报告

### 已合并校验

查 PR 状态：MERGED → 清理；OPEN → 提醒用户确认；CLOSED → 提醒用户选择。

## 8. 拉取最新 main

```bash
git checkout main && git pull origin main
```

## 9. 删除功能分支（必须按顺序全部执行）

```bash
git rev-parse --abbrev-ref HEAD  # 9.1 确认在 main
git branch -D <branch>           # 9.2 删本地（用 -D，squash 后 -d 会拒绝）
# 9.3 探测远程分支是否存在再删
git ls-remote --exit-code --heads origin <branch> && git push origin --delete <branch>
git fetch -p                     # 9.4 裁剪远程引用
```

## 多仓库处理

每个仓库独立执行 2-9（含各自测试和 4.5 自查）。一个失败不影响其他。步骤 7 逐仓库分别询问。

## 禁止操作

`git push --force` / `git reset --hard` / `git checkout -- .` / 未授权合并 PR / 非 squash 策略 / 提交敏感文件
