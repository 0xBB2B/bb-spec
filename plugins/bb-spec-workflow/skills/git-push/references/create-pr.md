> 用在 /git-push 第 6 步：按平台和合并对象创建 PR，并提醒核对仓库合并设置。

根据 `git remote get-url origin` 判断平台（github → `gh`，gitlab → `glab`）。合并对象沿用步骤 4 选定的 base repo：

- **base 为 origin** → `gh pr create` 显式带 `--repo <origin 的 owner/repo>`。fork 的 clone 里 gh 默认把 PR 开到 parent 仓库（upstream），不显式指定会开错地方。
- **base 为 upstream** → `--repo <upstream 的 owner/repo>`；且步骤 7 所有 `gh pr view/merge/close` 同样显式带该 `--repo`，步骤 8 的 `git pull` 源换成 `upstream main`（拉完可再 `git push origin main` 同步 fork）。GitLab 对应 `glab mr create --target-project`。

### 创建

- 标题、body 用 4.5.3 的草稿
- PR 创建后提醒用户核对仓库合并设置：只允许 squash 合并，平台默认的 squash 说明用 PR 标题和描述。有人在网页上点合并时用的是这个默认说明，设成别的 `Requirement:` 行会丢：
  - GitHub：Settings → General → Pull Requests 只勾「Allow squash merging」，取消「Allow merge commits」和「Allow rebase merging」，「Allow squash merging」的默认说明选「Default to pull request title and description」；Settings → Rules → Rulesets 里作用于主分支的规则集，「Require a pull request before merging」的「Allowed merge methods」也只留 Squash——两处都放行 squash 才能合并
  - GitLab：Settings → Merge requests 的 Merge method 选「Fast-forward merge」（选 Merge commit 会在 squash commit 之外再多一个合并 commit），「Squash commits when merging」选「Require」，「Squash commit message template」填 `%{title}`、空一行、`%{description}`
