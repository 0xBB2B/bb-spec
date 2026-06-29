---
name: git-push
description: 推送本地代码到远程并开 PR 全流程——识别仓库→确认分支（worktree 模式自动定位目标分支）→跑全量测试→提交未暂存改动（禁 git add .）→若存在 spec INDEX.md 则 subagent 比对 spec 跑分支规范自查（违规走 /revise 循环复审）+起草 6 段 PR 描述→推送→创建 PR→清理本地与远程。触发：push 一下、提个 PR、代码推上去、准备发 PR、开 PR 前自查、对照规范看分支。跳过：未本地验证完成的功能、main/master 上无新提交。
---

# 仓库提交与 PR 流程

## 概览

确认分支（worktree 模式自动定位目标）→ 跑测试 → 提交 → **分支规范自查 + PR 草稿**（仅当仓库或项目根存在 `.bb-spec/docs/spec/INDEX.md`）→ 推送 → 创建 PR → 处理 PR → 清理分支 / worktree。

## 参数

可附带目录路径指定仓库：`/git-push ./my-project`。未指定则自动检测当前目录。

---

## 1. 识别范围

- 当前目录是 git 仓库 → 单仓库处理
- 当前目录下多个 git 子目录 → 列出，询问用户选哪些
- 参数指定目录 → 只处理该目录

**Shell 变量名禁区**：禁止用 `status`、`path`、`PATH`、`SECONDS` 等保留名。

## 2. 确认分支（worktree 感知）

`git-workflow` 默认用 worktree 隔离开发，功能提交常落在 `~/.bb-spec/worktrees/` 下的某棵 worktree，而主仓库目录仍锁在 main。所以**先 `git worktree list` 看清上下文**，再按 `git branch --show-current` 分流：

- **当前已在功能分支**（非 main/master）→ 就地处理本分支。
- **当前在主仓库且 HEAD 为 main/master** → 不要急着新建分支，先查是否有 worktree 上的分支已领先 main：

  ```bash
  git worktree list --porcelain        # 列出所有 worktree 及其分支
  git rev-list --count main..<branch>  # 对每棵非 main 的 worktree 分支：> 0 即有待推送提交
  ```

  - **存在 ≥1 棵就绪 worktree**（领先 main）→ 这才是要推送的目标。用 **AskUserQuestion** 列出让用户选推哪棵，然后把后续步骤 3-8 全部定位到该 worktree 目录执行（`cd` 进去，或全程 `git -C <worktree>`）。
  - **无任何就绪 worktree** → 确是新任务还没开分支 → 必须先从 main 创建新分支再继续。

**worktree 模式标志**：只要最终在 linked worktree 里执行（上面任一路径定位到 worktree），就记下此标志，步骤 8 按 worktree-aware 清理。判定：

```bash
[ "$(git rev-parse --git-dir)" != "$(git rev-parse --git-common-dir)" ] && echo "linked worktree"
```

## 3. 跑全量测试

**优先级**：Makefile `test`/`tests`/`check`/`ci`/`test-all` → 项目类型推断（`go test ./...` / `bun test` / `cargo test` / `pytest`）→ 问用户。
**失败**：立即停止，报告给用户。用户明确"跳过测试"时才可略过。

## 4. 提交未暂存改动

`git status --short`。有改动 → 明确暂存相关文件（禁止 `git add .`）+ commit。不确定的文件（`.env`、凭据）必须先问。工作区干净 → 跳过。

## 4.5 分支规范自查与 PR 草稿（pre-review）

### 前置探测

两级查找 spec：

1. **仓库根**：读取仓库根 `.bb-spec.yaml` 的 `base_dir`（默认 `.bb-spec`），检查 `{base_dir}/docs/spec/INDEX.md`
2. **项目根（CWD）**：若仓库根未找到，再检查调用目录（即 CWD，多仓库场景下通常是外层项目根）的 `.bb-spec/docs/spec/INDEX.md`

任一位置命中 → 以该路径作为 spec 来源进入自查；两处都不存在 → 跳过整个 4.5。

### 核心原则

1. 以规范为准，不以习惯为准
2. 直修不商量（规范本身冲突或缺失时才停下问）
3. 循环到通过（最多 3 轮）
4. PR 草稿整体 ≤ 50 行

### 4.5.1 派 subagent review

`Agent`（`subagent_type: bb-spec-workflow:pre-reviewer`，模型由 agent 定义指定），prompt 传入：
- `repo_path`：仓库绝对路径
- `base_branch`：比对基线分支
- `spec_dir`：前置探测命中的 spec 目录
- `diff_summary`：diff 概况（commit 数、规模、审查重点）

审查指令、输出格式（`## 结论 PASS|FAIL` → `## 违规项` → `## 备注`）、只读约束均由 agent 定义自包含。

### 4.5.2 经 /revise 修复

- PASS → 跳到 4.5.3
- FAIL → 用 Skill 工具调用 `revise`，把本轮全部违规项（file:line + 违反哪条 + 建议修法）作为参数传入；归因诊断、修复、全量测试、本地 commit 由 revise 闭环，禁止绕过 revise 直接改代码 → revise 完成后重新派 subagent 复审 → ≥ 3 轮仍 FAIL → 停下报告分歧

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

**worktree 模式铁律**：步骤 2 标记为 worktree 模式时，本步所有 `gh pr merge` / `gh pr close` **一律去掉 `--delete-branch`**（GitLab：`--remove-source-branch`）。原因：gh 在合并/关闭成功后会立即试图删本地分支，但分支被 worktree 占用必失败（gh 报非零退出码——而服务端合并实际已完成）。本地与远程分支删除统一交给步骤 8 在 `worktree remove` 之后做。

创建后用 AskUserQuestion 让用户选（除非已显式声明）：

1. **自动合并**：`gh pr merge <n> --squash --auto --delete-branch`（GitLab：`--auto-merge --remove-source-branch`；worktree 模式去掉删分支 flag）
2. **已合并**：直接进入「合并结果核验」
3. **关闭 PR**：`gh pr close --delete-branch` → 清理（worktree 模式同样去 `--delete-branch`）

**`--auto` 被拒**（仓库未开启 auto-merge，报 `Auto merge is not allowed` / `enablePullRequestAutoMerge`）→ 降级为不带 `--auto` 的 `gh pr merge <n> --squash --delete-branch` 重试（worktree 模式同样去 `--delete-branch`）。

### 合并结果核验（唯一完成判据，所有合并路径必经）

**铁律：合并是否完成，只认 `gh pr view <n> --json state,mergedAt` 的 `state == "MERGED"`。`gh pr merge` 的 stdout 与退出码一律不作数**——它可能只表示「已加入自动合并队列」，也可能在 auto 不可用时报错而根本没合并。执行任何合并动作后，**必须**查询此状态再下结论：

- `state == "MERGED"`（`mergedAt` 非空）→ 进入步骤 8、9 清理
- `state == "OPEN"` → **尚未合并：禁止进入清理、禁止宣告完成**，按下方「未合并排查」处理后重试合并并重新核验
- `state == "CLOSED"`（未合并）→ 提醒用户选择

### 未合并排查（state 仍为 OPEN）

查 `gh pr view <n> --json mergeable,mergeStateStatus,statusCheckRollup`：

- **冲突**（`mergeable == CONFLICTING` / `mergeStateStatus == DIRTY`）→ `git rebase origin/main`：机械性冲突自行解决 + `--force-with-lease` 重推；业务性冲突停下报告。重推后 GitHub 异步重算 mergeability，需等其不再是 `UNKNOWN`/`CONFLICTING` 再重试合并
- **`mergeable == UNKNOWN`**（GitHub 仍在计算，常见于刚 push / rebase 后）→ 短暂轮询后重查，勿据此误判为冲突
- **必需检查未过**：CI 进行中 → 告知用户挂起、跳过清理；**CI 失败** → 取消自动合并 → 拉失败日志 → 机械性失败（lint/format/lockfile）自行修复后重设；业务性失败停下报告

## 8. 合并后清理（按步骤 2 的模式分流）

### 普通模式（直接切分支）

```bash
git checkout main && git pull origin main
git rev-parse --abbrev-ref HEAD   # 确认在 main
git branch -D <branch>            # 用 -D，squash 后 -d 会拒绝
# 探测远程分支是否存在再删
git ls-remote --exit-code --heads origin <branch> && git push origin --delete <branch>
git fetch -p                      # 裁剪远程引用
```

### worktree 模式

主仓库本就停在 main，**禁止在 worktree 内 `git checkout main`**（该分支被主仓库占用，会报错）。改为先回主仓库、移除 worktree、再删分支：

```bash
WT="$(git rev-parse --show-toplevel)"           # 当前 worktree 路径（移除前先取）
cd "$(git rev-parse --git-common-dir)/.." && pwd # 回到主仓库根（已在 main）
git pull origin main
git worktree remove "$WT"                        # 有未提交改动会拒绝——此时应已 commit+push
git branch -D <branch>                           # worktree 移除后才能删其分支
# 探测远程分支是否存在再删
git ls-remote --exit-code --heads origin <branch> && git push origin --delete <branch>
git fetch -p && git worktree prune               # 裁剪远程引用 + worktree 元数据
```

## 多仓库处理

每个仓库独立执行 2-8（含各自测试和 4.5 自查）。一个失败不影响其他。步骤 7 逐仓库分别询问。

## 禁止操作

`git push --force` / `git reset --hard` / `git checkout -- .` / 未授权合并 PR / 非 squash 策略 / 提交敏感文件
