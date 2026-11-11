> 用在 /git-push 第 8 步：合并后按普通模式或 worktree 模式清理本地与远程分支。

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
