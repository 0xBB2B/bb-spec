---
name: git-push
description: 推送本地代码到远程并开 PR 全流程——识别仓库→确认分支（worktree 模式自动定位目标分支）→提交未暂存改动（禁 git add .）→同步基线（origin+upstream 双 remote 时先问合并对象、默认 origin/main；分支落后基线则 rebase）→本机装了 ocr 则跑一次 ocr review，Claude 逐条读代码核实后按 🔴/🔶/🔷 列出建议修复项、用户勾选后交 /revise 修→在同步后的代码上跑全量测试→若存在 AGENTS.md、本分支有新增 PRD 或本分支 commit 指向已合并 PRD 则 subagent 比对项目约束、PRD 与 commit 正文的改动说明跑分支规范自查（违规走 /revise 循环复审）→起草 PR 标题（跟随仓库 commit 风格）与 6 段 PR 描述（末尾带 `Requirement:` 标记）→推送→创建 PR→squash 合并并核对基线上的 commit 说明带 `Requirement:`→清理本地与远程。触发：push 一下、提个 PR、代码推上去、准备发 PR、开 PR 前自查、对照规范看分支。跳过：未本地验证完成的功能、main/master 上无新提交。
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/*), Bash(${CLAUDE_SKILL_DIR}/scripts/*)
---

# 仓库提交与 PR 流程

## 概览

确认分支（worktree 模式自动定位目标）→ 提交 → **同步基线**（落后则 rebase）→ **ocr 审查**（仅当本机装了 ocr）→ 跑测试 → **分支规范自查**（仅当仓库根存在 `AGENTS.md`、本分支有新增 PRD 或本分支 commit 指向已合并 PRD）→ **PR 草稿** → 推送 → 创建 PR → 处理 PR（squash 合并）→ 清理分支 / worktree。

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

## 3. 提交未暂存改动

`git status --short`。有改动 → 明确暂存相关文件（禁止 `git add .`）+ commit。不确定的文件（`.env`、凭据）必须先问。工作区干净 → 跳过。rebase 要求工作区干净，所以提交必须在步骤 4 之前。

## 4. 同步基线（rebase）

### 合并对象确认（fork / 双 remote 场景）

`git remote` 同时存在 `origin` 与 `upstream`，且两者都有 main/master（`git ls-remote --heads <remote> main master` 探测）→ **先用 AskUserQuestion 询问 PR 合并到哪个仓库**，`origin/main` 放首位标（Recommended）；只有 origin → 直接以 origin 为合并对象，不问。选定结果记为 **base repo**，其 main/master 记为 **基线**（`origin/main` 或 `upstream/main`），本步及后续全程生效。

### 检查落后并 rebase

```bash
git fetch <base remote>
git rev-list --count HEAD..<基线>   # > 0 即基线已领先、分支落后
```

- **= 0** → 分支已基于最新基线，跳过。
- **> 0** → `git rebase <基线>`：机械性冲突（格式化、lockfile、相邻行改动）自行解决后 `git rebase --continue`；业务性冲突 → `git rebase --abort` 停下报告。

## 4.2 ocr 审查（仅当本机装了 ocr）

放在全量测试之前：这一步修掉的代码，接着就被 4.3 的全量测试覆盖。

`command -v ocr` 失败 → 输出「未安装 ocr，跳过第 4.2 步」，进 4.3。是否进入只看本机装没装 ocr，与 AGENTS.md、PRD 无关。

### 运行（只跑一次）

```bash
ocr review --from <基线> --to <当前分支> --format json --audience agent \
  --output <cache_dir>/ocr/<branch>.json
```

- `<基线>` 用步骤 4 选定的基线，不写死 `main`：ocr 审的是 `merge-base(from, to)..to`，rebase 之后正好是本分支自己的改动
- `<cache_dir>` 取 `${CLAUDE_PLUGIN_ROOT}/scripts/bbspec-paths.sh` 输出的 `cache_dir`；`<branch>` 中的 `/` 替换为 `__`。写入前确认 `<cache_dir>/.gitignore` 存在且内容为单行 `*`，不存在则连目录一并创建
- 用 Bash 的 `run_in_background` 运行、等完成通知：一次审查可能超过 10 分钟，前台调用会被超时掐断

| 结果 | 处理 |
|---|---|
| 退出码 1 | 报告「ocr 没跑成功：<stderr 里的原因>」，不拦推送，跳到「收尾」 |
| `status` 为 `skipped` | 报告「本分支没有 ocr 支持审查的文件」，跳到「收尾」 |
| `comments` 为空 | 报告「ocr 审了 N 个文件，没有发现问题」，跳到「收尾」 |
| `comments` 非空 | 进入核实 |

`status` 为 `partial`（部分文件超时或超预算没审完，退出码仍为 0）时照常处理 `comments`，并在总结行后注明哪些文件没审到（取自 `warnings`）。

### 核实与定级

逐条读 ocr 指向的代码（`path:start_line-end_line`）、它的调用方和相关的检查代码，判断成立与否：

- **成立**：能给出 `文件:行号` 证明问题存在，并确认现有代码没有防住
- **不成立**：拿不出代码证据，或已有防护；ocr 的原话不算证据

成立的条目定级：

- 🔴 真实场景会触发，后果是崩溃、数据错乱或安全漏洞
- 🔶 会触发，但后果有限（如单个请求失败），或只在少见条件下出现
- 🔷 几乎碰不到，或只影响可读性

### 输出

终端宽度有限，把四个详细字段塞进一张大表会每列只剩几个字宽，所以先给总表、再每条一张竖表：

```markdown
ocr 审了 N 个文件，报了 R 条。逐条读代码核实后：成立 C 条（🔴 a · 🔶 b · 🔷 c），不成立 D 条。

**建议修复**（按优先级排序）

| # | 级 | 问题 | 位置 |
|---|---|---|---|
| 1 | 🔴 | <≤ 20 字> | <文件:行号> |

**#1 🔴 <问题>** `<文件:行号>`

| 项目 | 内容 |
|---|---|
| 审查证据 | <读到的代码事实，带 文件:行号> |
| 实际后果 | <触发后会怎样> |
| 现实情况 | <触发条件、常不常见、有没有被防住>。例：<谁、做了什么、走到哪一行、出了什么事> |
| 如何修复 | <修复方向> |

**不建议修**（误报或不值得修，回复编号可拉回去修）

| # | ocr 原话 | 位置 | 不修的理由（证据） |
|---|---|---|---|
| A | <ocr 的说法> | <文件:行号> | <防护或理由，带 文件:行号>。例：<为什么碰不到> |
```

- 建议修复按 🔴 → 🔶 → 🔷 排序，编号 1、2、3…；不建议修编号 A、B、C…
- 不成立的条目为 0 时省略「不建议修」表

### 用户勾选

成立的条目为 0 → 不提问，输出总结行与「不建议修」表，进 4.3。

否则用 AskUserQuestion 问「ocr 核实后建议修 C 条（🔴 a · 🔶 b · 🔷 c），修哪些？」，选项依次为：修全部 🔴🔶（Recommended）/ 只修 🔴 / 建议项全修 / 都不修。某个选项修的范围为空（如没有 🔴 时的「只修 🔴」），或与前面某个选项相同（如没有 🔷 时的「建议项全修」），就去掉它；「都不修」始终保留，Recommended 标在剩下的第一个选项上。用户选「其他」时按输入的编号取（如 `1,3,A`，可含「不建议修」表的字母编号）。

### 修复

选「都不修」→ 进 4.3。否则用 Skill 工具调用 `revise`，把选中项一次全部传入，每条带位置、审查证据、实际后果、现实情况、如何修复；归因诊断、修复、全量测试、本地 commit 由 revise 闭环，禁止绕过 revise 直接改代码。修完不再重跑 ocr，由 4.3 全量测试与 4.5 自查把关。

### 收尾

删除本次的 `<cache_dir>/ocr/<branch>.json`（存在时），进 4.3。

## 4.3 跑全量测试

测试放在同步基线之后跑：本分支改动和基线新改动各自都能通过，叠加后仍可能失败，只有在 rebase 后的代码上测才算数，也只需测一次。

**优先级**：Makefile `test`/`tests`/`check`/`ci`/`test-all` → 项目类型推断（`go test ./...` / `bun test` / `cargo test` / `pytest`）→ 问用户。
**失败**：立即停止，报告给用户；用户修好后重跑 `/git-push`，修复由步骤 3 提交。用户明确"跳过测试"时才可略过。

## 4.5 分支规范自查与 PR 草稿（pre-review）

### 前置探测

运行 `${CLAUDE_PLUGIN_ROOT}/scripts/bbspec-paths.sh`，输出的 `docs_repo` 是文档仓库：与当前仓库相同为单仓库，不同为多仓库工作区。再运行 `${CLAUDE_PLUGIN_ROOT}/scripts/branch-prds.sh <基线>`。探测三类规范来源：

1. **项目约束**：文档仓库根（单仓库即仓库根）的 `AGENTS.md`
2. **本分支 PRD**：`branch-prds.sh` 输出的 `new=` 行（基线上还没有 = 本分支新增）
3. **已合并 PRD**：`branch-prds.sh` 输出的 `merged=` 行，即本分支 commit 的 `Requirement:` 指向、基线上已有的 PRD——本分支在改已合并的功能，期望行为写在 commit 正文里

任一存在 → 进入自查；三者都不存在 → 跳过 4.5.1、4.5.2，直接进 4.5.3 写 PR 草稿。

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
- `prd_dirs`：`new=` 目录的完整路径（`prd_dir`/<目录名>，无则为空）
- `change_notes`：`git log <基线>..HEAD --format='%h %s%n%b'` 的输出
- `merged_prd_dirs`：`merged=` 目录的完整路径（`prd_dir`/<目录名>，无则为空）
- `diff_summary`：diff 概况（commit 数、规模、审查重点）

审查指令、输出格式（`## 结论 PASS|FAIL` → `## PRD 逐条检查` → `## 违规项` → `## 备注`）、只读约束均由 agent 定义自包含。

### 4.5.2 经 /revise 修复

- PASS → 跳到 4.5.3
- FAIL → 用 Skill 工具调用 `revise`，把本轮全部违规项（file:line + 违反哪条 + 建议修法）作为参数传入；归因诊断、修复、全量测试、本地 commit 由 revise 闭环，禁止绕过 revise 直接改代码 → revise 完成后重新派 subagent 复审 → ≥ 3 轮仍 FAIL → 停下报告分歧

### 4.5.3 生成 PR 标题与描述草稿（6 段，≤ 50 行）

squash 合并后，基线上只留一个 commit：标题就是 PR 标题，正文就是 PR 描述，分支上各个 commit 的说明都不进基线。所以：

- **标题**：≤ 70 字，跟随基线上的 commit 风格（先 `git log --oneline -20 <基线>`）。基线用 `feat(scope): …` / `fix(scope): …` 这类格式时，标题必须是这个格式；破坏性变更在冒号前加 `!`，并在描述末尾写 `BREAKING CHANGE:` 行
- **描述**：写分支最终做成了什么，中途推翻的做法不写。分支 commit 正文里写了改前 / 改后 / 为什么的，按最终结果汇总进「需求」「方案」「结果」

```markdown
## 背景
## 需求
## 方案
## 结果
## 测试
## 规范

BREAKING CHANGE: <影响范围与迁移办法；不是破坏性变更时删掉这一行>
Requirement: <目录名，多个用逗号分隔；没有写 none>
```

「规范」段写本次涉及的 PRD 目录与相关项目约束（无则写"无"）；跳过了 4.5.1、4.5.2 时注明「未跑分支规范自查」。

最后一行 `Requirement:` 标记必须保留，目录名取 4.5 前置探测里 `branch-prds.sh` 输出的全部 `new=` 与 `merged=` 目录名，用逗号分隔；一个都没有写 `none`。分支在改已合并的功能时，commit 里写的是已合并 PRD 的目录名，squash 后基线上只剩这一行，漏写就查不回那份 PRD。多仓库工作区每个仓库的 PR 都带，代码仓库的 PR 写文档仓库里的 PRD 目录名。

标题与描述直接作为步骤 6 的 `--title`、`--body`。

## 5. 推送到远程

`git push -u origin <branch>`；分支此前已推过且步骤 4 做过 rebase → `git push --force-with-lease origin <branch>`。失败 → 停止报告。

## 6. 创建 PR

根据 `git remote get-url origin` 判断平台（github → `gh`，gitlab → `glab`）。合并对象沿用步骤 4 选定的 base repo：

- **base 为 origin** → `gh pr create` 显式带 `--repo <origin 的 owner/repo>`。fork 的 clone 里 gh 默认把 PR 开到 parent 仓库（upstream），不显式指定会开错地方。
- **base 为 upstream** → `--repo <upstream 的 owner/repo>`；且步骤 7 所有 `gh pr view/merge/close` 同样显式带该 `--repo`，步骤 8 的 `git pull` 源换成 `upstream main`（拉完可再 `git push origin main` 同步 fork）。GitLab 对应 `glab mr create --target-project`。

### 创建

- 标题、body 用 4.5.3 的草稿
- PR 创建后提醒用户核对仓库合并设置：只允许 squash 合并，平台默认的 squash 说明用 PR 标题和描述。有人在网页上点合并时用的是这个默认说明，设成别的 `Requirement:` 行会丢：
  - GitHub：Settings → General → Pull Requests 只勾「Allow squash merging」，取消「Allow merge commits」和「Allow rebase merging」，「Allow squash merging」的默认说明选「Default to pull request title and description」；Settings → Rules → Rulesets 里作用于主分支的规则集，「Require a pull request before merging」的「Allowed merge methods」也只留 Squash——两处都放行 squash 才能合并
  - GitLab：Settings → Merge requests 的 Merge method 选「Fast-forward merge」（选 Merge commit 会在 squash commit 之外再多一个合并 commit），「Squash commits when merging」选「Require」，「Squash commit message template」填 `%{title}`、空一行、`%{description}`

## 7. 处理 PR

**worktree 模式铁律**：步骤 2 标记为 worktree 模式时，本步所有 `gh pr merge` / `gh pr close` **一律去掉 `--delete-branch`**（GitLab：`--remove-source-branch`）。原因：gh 在合并/关闭成功后会立即试图删本地分支，但分支被 worktree 占用必失败（gh 报非零退出码——而服务端合并实际已完成）。本地与远程分支删除统一交给步骤 8 在 `worktree remove` 之后做。

合并时把 4.5.3 的标题和描述显式传给平台：不传时平台用仓库默认的 squash 说明，可能只有标题，`Requirement:` 行就丢了。选自动合并时，先把描述写进 `<cache_dir>/pr/<branch>.md`（`<cache_dir>` 与 `<branch>` 的取法、`.gitignore` 的检查同 4.2），GitLab 另写一份 `<branch>.squash.md`，内容为标题、空一行、描述。

创建后用 AskUserQuestion 让用户选（除非已显式声明）：

1. **自动合并**：`gh pr merge <n> --squash --subject "<PR 标题> (#<n>)" --body-file <描述文件> --auto --delete-branch`（GitLab：`glab mr merge <n> --squash --squash-message "$(cat <squash 说明文件>)" --auto-merge --remove-source-branch`；worktree 模式去掉删分支 flag）
2. **已合并**：直接进入「合并结果核验」
3. **关闭 PR**：`gh pr close --delete-branch` → 清理（worktree 模式同样去 `--delete-branch`；GitLab：`glab mr close <n>`，它没有删分支的参数，分支由步骤 8 删）

**`--auto` 被拒**（仓库未开启 auto-merge，报 `Auto merge is not allowed` / `enablePullRequestAutoMerge`）→ 降级为不带 `--auto` 的 `gh pr merge <n> --squash --subject "<PR 标题> (#<n>)" --body-file <描述文件> --delete-branch` 重试（worktree 模式同样去 `--delete-branch`）。GitLab 不降级重试：MR 没有流水线时 glab 本来就直接合并；glab 报 `Cannot perform merge action` 说明流水线失败或被取消，按「未合并排查」的 CI 失败处理。用 `--auto-merge=false` 重试会在项目没开「Pipelines must succeed」时把 CI 失败的 MR 直接合并。

### 合并结果核验（唯一完成判据，所有合并路径必经）

**铁律：合并是否完成，只认 `${CLAUDE_SKILL_DIR}/scripts/pr-status.sh <n> <base remote>` 输出的 `state=merged`。`gh pr merge` / `glab mr merge` 的 stdout 与退出码一律不作数**——它可能只表示「已加入自动合并队列」，也可能在 auto 不可用时报错而根本没合并。脚本按 remote 地址选 gh / glab，把两边的状态归成同一套值，输出 `state`、`merge_commit`、`blocker` 三行。执行任何合并动作后，**必须**运行它再下结论：

- `state=merged` → 进入「核对 squash 说明」
- `state=open` → **尚未合并：禁止进入清理、禁止宣告完成**，按下方「未合并排查」处理后重试合并并重新核验
- `state=closed`（未合并）→ 提醒用户选择

### 未合并排查（state=open）

按同一次输出的 `blocker` 处理：

- **`conflict`**（有冲突，GitLab 也包括要求先 rebase）→ `git rebase <基线>`（步骤 4 选定）：机械性冲突自行解决 + `--force-with-lease` 重推；业务性冲突停下报告。重推后平台异步重算能否合并，需等 `blocker` 不再是 `computing` / `conflict` 再重试合并
- **`computing`**（平台还在计算，常见于刚 push / rebase 后）→ 短暂轮询后重查，勿据此误判为冲突
- **`ci_running`** → 告知用户挂起、跳过清理
- **`ci_failed`** → 取消自动合并 → 拉失败日志 → 机械性失败（lint/format/lockfile）自行修复后重设；业务性失败停下报告
- **`none`**（平台认为可以合并）→ 自动合并还在排队时等它完成；不在排队就重试合并
- **`other:<原始状态>`**（如 GitHub 的 `BEHIND`、`UNSTABLE`，GitLab 的 `not_approved`、`draft_status`）→ 把原始状态报告给用户，停下等处理
- **合并方式被拒**（`gh pr merge` 报不允许 squash 合并）→ 仓库常规设置和主分支规则集都限制合并方式，任一处不放行 squash 都会被拒。分别查 `gh repo view <owner>/<repo> --json squashMergeAllowed` 与 `gh api repos/<owner>/<repo>/rules/branches/<基线分支名> --jq '.[] | select(.type=="pull_request") | .parameters.allowed_merge_methods'`，把不放行的那处报给用户；改仓库设置须经用户同意，改完重试合并

### 核对 squash 说明

合并进基线的 commit 取 `pr-status.sh` 输出的 `merge_commit`。`git fetch <base remote>` 后读 `git log -1 --format=%B <哈希> | grep '^Requirement:'`：

- 有 → 进步骤 8
- 没有 → 告诉用户「合并进基线的 commit 说明里没有 `Requirement:` 行，以后查代码历史时这次改动连不回 PRD」，请用户按步骤 6 的设置提醒检查平台设置；不拦清理，进步骤 8
- 取不到哈希 → 报告「没能核对 squash 说明」，进步骤 8

核对完删除步骤 7 写的描述文件（存在时）。

## 8. 合并后清理（按步骤 2 的模式分流）

### 普通模式（直接切分支）

```bash
git checkout main && git pull origin main
git rev-parse --abbrev-ref HEAD   # 确认在 main
git branch -D <branch>            # 用 -D：squash 合并在基线上生成新 commit，分支上的 commit 不在基线里，-d 会拒绝
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

每个仓库独立执行 2-8（含各自 4.2 ocr 审查、测试和 4.5 自查）。一个失败不影响其他。步骤 7 逐仓库分别询问。

## 禁止操作

`git push --force` / `git reset --hard` / `git checkout -- .` / 未授权合并 PR / 非 squash 策略（rebase 或 merge commit）/ 提交敏感文件
