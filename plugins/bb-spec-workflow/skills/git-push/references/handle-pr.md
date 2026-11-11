> 用在 /git-push 第 7 步：选合并方式、合并结果核验、未合并排查、核对 squash 说明。

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
