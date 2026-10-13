---
name: git-push
description: 推送本地代码到远程并开 PR 全流程——识别仓库→确认分支（worktree 模式自动定位目标分支）→跑全量测试→提交未暂存改动（禁 git add .）→同步基线（origin+upstream 双 remote 时先问合并对象、默认 origin/main；分支落后基线则先 rebase 再重跑测试）→若存在 AGENTS.md、本分支有新增 PRD 或本分支 commit 指向已合并 PRD 则 subagent 比对项目约束、PRD 与 commit 正文的改动说明跑分支规范自查（违规走 /revise 循环复审）+起草 6 段 PR 描述（末尾带 `Requirement:` 标记）→推送→创建 PR→清理本地与远程。触发：push 一下、提个 PR、代码推上去、准备发 PR、开 PR 前自查、对照规范看分支。跳过：未本地验证完成的功能、main/master 上无新提交。
---

# 仓库提交与 PR 流程

## 概览

确认分支（worktree 模式自动定位目标）→ 跑测试 → 提交 → **同步基线**（落后则 rebase）→ **分支规范自查 + PR 草稿**（仅当仓库根存在 `AGENTS.md`、本分支有新增 PRD 或本分支 commit 指向已合并 PRD）→ 推送 → 创建 PR → 处理 PR → 清理分支 / worktree。

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

## 4.3 同步基线（rebase）

### 合并对象确认（fork / 双 remote 场景）

`git remote` 同时存在 `origin` 与 `upstream`，且两者都有 main/master（`git ls-remote --heads <remote> main master` 探测）→ **先用 AskUserQuestion 询问 PR 合并到哪个仓库**，`origin/main` 放首位标（Recommended）；只有 origin → 直接以 origin 为合并对象，不问。选定结果记为 **base repo**，其 main/master 记为 **基线**（`origin/main` 或 `upstream/main`），本步及后续全程生效。

### 检查落后并 rebase

```bash
git fetch <base remote>
git rev-list --count HEAD..<基线>   # > 0 即基线已领先、分支落后
```

- **= 0** → 分支已基于最新基线，跳过。
- **> 0** → `git rebase <基线>`：机械性冲突（格式化、lockfile、相邻行改动）自行解决后 `git rebase --continue`；业务性冲突 → `git rebase --abort` 停下报告。rebase 完成后**重跑步骤 3 全量测试**——两批各自通过的改动叠加后仍可能失败，失败即停止报告。

## 4.5 分支规范自查与 PR 草稿（pre-review）

### 前置探测

读取 `.bb-spec.yaml` 的 `base_dir`（默认 `.bb-spec`；先找仓库根，找不到再往上级目录找——多仓库工作区的配置在工作区根），`${DOCS_DIR}` = `<base_dir>/docs`。文档仓库 = `git -C ${DOCS_DIR} rev-parse --show-toplevel`：与当前仓库相同为单仓库，不同为多仓库工作区。探测三类规范来源：

1. **项目约束**：文档仓库根（单仓库即仓库根）的 `AGENTS.md`
2. **本分支 PRD**：在文档仓库里 `git diff <基线>...HEAD --name-only -- <PRD 根>` 列出的目录中，`git cat-file -e <基线>:<PRD 根>/<目录>/OVERVIEW.md` 失败的（基线上还没有 = 本分支新增）；`<PRD 根>` 为 PRD 目录相对文档仓库根的路径
3. **已合并 PRD**：在当前仓库 `git log <基线>..HEAD --format=%B | grep '^Requirement:'` 取出的目录名（去掉 `none`）中，`git -C <文档仓库> cat-file -e <基线>:<PRD 根>/<目录>/OVERVIEW.md` 成功的——本分支在改已合并的功能，期望行为写在 commit 正文里

任一存在 → 进入自查；三者都不存在 → 跳过整个 4.5。

### 核心原则

1. 以规范为准，不以习惯为准
2. 直修不商量（规范本身冲突或缺失时才停下问）
3. 循环到通过（最多 3 轮）
4. PR 草稿整体 ≤ 50 行

### 4.5.1 派 subagent review

`Agent`（`subagent_type: bb-spec-workflow:pre-reviewer`，模型由 agent 定义指定），prompt 传入：
- `repo_path`：仓库绝对路径
- `base_branch`：比对基线分支
- `agents_md`：仓库根 AGENTS.md 路径（不存在则为空）
- `prd_dirs`：本分支新增的 PRD 目录列表（无则为空）
- `change_notes`：`git log <基线>..HEAD --format='%h %s%n%b'` 的输出
- `merged_prd_dirs`：已合并 PRD 目录列表（无则为空）
- `diff_summary`：diff 概况（commit 数、规模、审查重点）

审查指令、输出格式（`## 结论 PASS|FAIL` → `## PRD 逐条检查` → `## 违规项` → `## 备注`）、只读约束均由 agent 定义自包含。

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

Requirement: <本分支 PRD 目录名>
```

「规范」段写本次涉及的 PRD 目录与相关项目约束（无则写"无"）。最后一行 `Requirement:` 标记必须保留：本分支有新增 PRD 写其目录名（多个用逗号分隔），没有写 `none`；多仓库工作区每个仓库的 PR 都带，代码仓库的 PR 写文档仓库里本次 PRD 的目录名。直接作为步骤 6 的 `--body`。

## 5. 推送到远程

`git push -u origin <branch>`；分支此前已推过且 4.3 做过 rebase → `git push --force-with-lease origin <branch>`。失败 → 停止报告。

## 6. 创建 PR

根据 `git remote get-url origin` 判断平台（github → `gh`，gitlab → `glab`）。合并对象沿用步骤 4.3 选定的 base repo：

- **base 为 origin** → `gh pr create` 显式带 `--repo <origin 的 owner/repo>`。fork 的 clone 里 gh 默认把 PR 开到 parent 仓库（upstream），不显式指定会开错地方。
- **base 为 upstream** → `--repo <upstream 的 owner/repo>`；且步骤 7 所有 `gh pr view/merge/close` 同样显式带该 `--repo`，步骤 8 的 `git pull` 源换成 `upstream main`（拉完可再 `git push origin main` 同步 fork）。GitLab 对应 `glab mr create --target-project`。

### 创建

- 标题 ≤ 70 字
- body：4.5 跑过 → 用 6 段草稿；4.5 跳过 → 简短 bullet + 标注「未跑 pre-review」；两种情况末尾都带一行 `Requirement: <本分支 PRD 目录名 / none>`
- PR 创建后提醒用户核对仓库合并设置，只允许 rebase 合并，这样每个 commit 连同自己的 `Requirement:` 行原样进入主分支，代码才能经 git 精确反查回 PRD：
  - GitHub：Settings → General → Pull Requests 只勾「Allow rebase merging」，取消「Allow merge commits」和「Allow squash merging」
  - GitLab：Settings → Merge requests 的 Merge method 选「Fast-forward merge」，「Squash commits when merging」选「Do not allow」

## 7. 处理 PR

**worktree 模式铁律**：步骤 2 标记为 worktree 模式时，本步所有 `gh pr merge` / `gh pr close` **一律去掉 `--delete-branch`**（GitLab：`--remove-source-branch`）。原因：gh 在合并/关闭成功后会立即试图删本地分支，但分支被 worktree 占用必失败（gh 报非零退出码——而服务端合并实际已完成）。本地与远程分支删除统一交给步骤 8 在 `worktree remove` 之后做。

创建后用 AskUserQuestion 让用户选（除非已显式声明）：

1. **自动合并**：`gh pr merge <n> --rebase --auto --delete-branch`（GitLab：`glab mr merge <n> --rebase --auto-merge --remove-source-branch`；worktree 模式去掉删分支 flag）
2. **已合并**：直接进入「合并结果核验」
3. **关闭 PR**：`gh pr close --delete-branch` → 清理（worktree 模式同样去 `--delete-branch`）

**`--auto` 被拒**（仓库未开启 auto-merge，报 `Auto merge is not allowed` / `enablePullRequestAutoMerge`）→ 降级为不带 `--auto` 的 `gh pr merge <n> --rebase --delete-branch` 重试（worktree 模式同样去 `--delete-branch`）。

### 合并结果核验（唯一完成判据，所有合并路径必经）

**铁律：合并是否完成，只认 `gh pr view <n> --json state,mergedAt` 的 `state == "MERGED"`。`gh pr merge` 的 stdout 与退出码一律不作数**——它可能只表示「已加入自动合并队列」，也可能在 auto 不可用时报错而根本没合并。执行任何合并动作后，**必须**查询此状态再下结论：

- `state == "MERGED"`（`mergedAt` 非空）→ 进入步骤 8、9 清理
- `state == "OPEN"` → **尚未合并：禁止进入清理、禁止宣告完成**，按下方「未合并排查」处理后重试合并并重新核验
- `state == "CLOSED"`（未合并）→ 提醒用户选择

### 未合并排查（state 仍为 OPEN）

查 `gh pr view <n> --json mergeable,mergeStateStatus,statusCheckRollup`：

- **冲突**（`mergeable == CONFLICTING` / `mergeStateStatus == DIRTY`）→ `git rebase <基线>`（4.3 选定）：机械性冲突自行解决 + `--force-with-lease` 重推；业务性冲突停下报告。重推后 GitHub 异步重算 mergeability，需等其不再是 `UNKNOWN`/`CONFLICTING` 再重试合并
- **`mergeable == UNKNOWN`**（GitHub 仍在计算，常见于刚 push / rebase 后）→ 短暂轮询后重查，勿据此误判为冲突
- **必需检查未过**：CI 进行中 → 告知用户挂起、跳过清理；**CI 失败** → 取消自动合并 → 拉失败日志 → 机械性失败（lint/format/lockfile）自行修复后重设；业务性失败停下报告

## 8. 合并后清理（按步骤 2 的模式分流）

### 普通模式（直接切分支）

```bash
git checkout main && git pull origin main
git rev-parse --abbrev-ref HEAD   # 确认在 main
git branch -D <branch>            # 用 -D：GitHub 的 rebase 合并会重新生成提交哈希，-d 会拒绝
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

`git push --force` / `git reset --hard` / `git checkout -- .` / 未授权合并 PR / 非 rebase 策略（squash 或 merge commit）/ 提交敏感文件
