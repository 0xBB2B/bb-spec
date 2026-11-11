---
name: git-push
description: 推送本地代码到远程并开 PR 全流程——识别仓库→确认分支（worktree 模式自动定位目标分支）→提交未暂存改动（禁 git add .）→同步基线（origin+upstream 双 remote 时先问合并对象、默认 origin/main；分支落后基线则 rebase）→本机装了 ocr 则跑一次 ocr review，Claude 逐条读代码核实后按 🔴/🔶/🔷 列出建议修复项、用户勾选后交 /revise 修→在同步后的代码上跑全量测试→若存在 AGENTS.md、本分支有新增 PRD 或本分支 commit 指向已合并 PRD 则 subagent 比对项目约束、PRD 与 commit 正文的改动说明跑分支规范自查（违规走 /revise 循环复审，测试缺口交 /revise 补上）→起草 PR 标题（跟随仓库 commit 风格）与 6 段 PR 描述（末尾带 `Requirement:` 标记）→推送前把无关发现合成一张清单一次问→推送→创建 PR→squash 合并并核对基线上的 commit 说明带 `Requirement:`→清理本地与远程。触发：push 一下、提个 PR、代码推上去、准备发 PR、开 PR 前自查、对照规范看分支。跳过：未本地验证完成的功能、main/master 上无新提交。
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/*), Bash(${CLAUDE_SKILL_DIR}/scripts/*)
---

# 仓库提交与 PR 流程

## 概览

确认分支（worktree 模式自动定位目标）→ 提交 → **同步基线**（落后则 rebase）→ **ocr 审查**（仅当本机装了 ocr）→ 跑测试 → **分支规范自查**（仅当仓库根存在 `AGENTS.md`、本分支有新增 PRD 或本分支 commit 指向已合并 PRD）→ **PR 草稿** → **无关发现一次问** → 推送 → 创建 PR → 处理 PR（squash 合并）→ 清理分支 / worktree。

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

本机装了 ocr 时，在全量测试之前对本分支改动跑一次 ocr 审查，逐条读代码核实、分 🔴/🔶/🔷 列出，用户勾选要修的后交 `/revise` 修；没装 ocr 就跳过。

走到这一步先读 `references/ocr-review.md`（相对本 skill 目录）。

### 运行（只跑一次）

```bash
ocr review --from <基线> --to <当前分支> --format json --audience agent \
  --output <cache_dir>/ocr/<branch>.json
```

- `<基线>` 用步骤 4 选定的基线，不写死 `main`：ocr 审的是 `merge-base(from, to)..to`，rebase 之后正好是本分支自己的改动
- `<cache_dir>` 取 `${CLAUDE_PLUGIN_ROOT}/scripts/bbspec-paths.sh` 输出的 `cache_dir`；`<branch>` 中的 `/` 替换为 `__`。写入前确认 `<cache_dir>/.gitignore` 存在且内容为单行 `*`，不存在则连目录一并创建
- 派 `bb-spec-workflow:script-runner` 跑 ocr，`extract` 写审查结果文件 `<cache_dir>/ocr/<branch>.json` 的路径，输出文件目录 `${CACHE_DIR}/reports/`；审查结果文件的路径随报告交回，主窗口再照 `references/ocr-review.md` 里的规则逐条读代码核实

| 结果 | 处理 |
|---|---|
| 退出码 1 | 报告「ocr 没跑成功：<stderr 里的原因>」，不拦推送，跳到「收尾」 |
| `status` 为 `skipped` | 报告「本分支没有 ocr 支持审查的文件」，跳到「收尾」 |
| `comments` 为空 | 报告「ocr 审了 N 个文件，没有发现问题」，跳到「收尾」 |
| `comments` 非空 | 进入核实 |

`status` 为 `partial`（部分文件超时或超预算没审完，退出码仍为 0）时照常处理 `comments`，并在总结行后注明哪些文件没审到（取自 `warnings`）。

## 4.3 跑全量测试

**跑脚本**：会自己结束的脚本（测试、构建、类型检查、审查）——

- 预计 2 分钟内能跑完 → 主窗口用前台 Bash 直接跑
- 预计超过 2 分钟，或拿不准 → 派 `bb-spec-workflow:script-runner`，prompt 给出命令、工作目录、要摘取的内容、输出文件目录 `${CACHE_DIR}/reports/`
- 主窗口不执行循环等待脚本结束的命令；子代理等待期间做不依赖这次结果的事，没有可做的就结束回合，报告交回后继续
- 常驻服务（dev server、watch、`tail -f`）由主窗口自己用后台方式启动

全量测试按上面「跑脚本」分流。

测试放在同步基线之后跑：本分支改动和基线新改动各自都能通过，叠加后仍可能失败，只有在 rebase 后的代码上测才算数，也只需测一次。

**优先级**：Makefile `test`/`tests`/`check`/`ci`/`test-all` → 项目类型推断（`go test ./...` / `bun test` / `cargo test` / `pytest`）→ 问用户。
**失败**：立即停止，报告给用户；用户修好后重跑 `/git-push`，修复由步骤 3 提交。用户明确"跳过测试"时才可略过。

## 4.5 分支规范自查与 PR 草稿（pre-review）

仓库根有 `AGENTS.md`、本分支有新增 PRD 或本分支 commit 指向已合并 PRD 时，派 `pre-reviewer` 子代理自查，违规交 `/revise` 修；最后起草 PR 标题和 6 段描述（末尾带 `Requirement:` 行）。

走到这一步先读 `references/pre-review.md`（相对本 skill 目录）。

**子代理报告**：派工 prompt 里给出细节文件目录 `${CACHE_DIR}/reports/`（`${CACHE_DIR}` 取 `bbspec-paths.sh` 输出的 `cache_dir`）。报告超过上限照常使用，不退回重写。需要报告里没有的细节时，按「细节文件」路径只读需要的那一段，不整份读入。收尾时删掉本次产生的细节文件。

## 4.6 无关发现（推送之前问一次）

推送之前，把本次过程中冒出来的无关发现合成一张清单，用 AskUserQuestion 问一次处理哪些。

走到这一步先读 `references/unrelated-findings.md`（相对本 skill 目录）。

## 5. 推送到远程

`git push -u origin <branch>`；分支此前已推过且步骤 4 做过 rebase → `git push --force-with-lease origin <branch>`。失败 → 停止报告。

## 6. 创建 PR

按 `origin` 的地址判断平台（GitHub 用 `gh`，GitLab 用 `glab`），向步骤 4 选定的合并对象创建 PR，创建后提醒用户核对仓库的 squash 合并设置。

走到这一步先读 `references/create-pr.md`（相对本 skill 目录）。

## 7. 处理 PR

PR 创建后让用户选自动合并、已合并或关闭；合并是否完成只认 `pr-status.sh` 输出的 `state=merged`，合并后核对基线上的 commit 说明带 `Requirement:`。

走到这一步先读 `references/handle-pr.md`（相对本 skill 目录）。

## 8. 合并后清理（按步骤 2 的模式分流）

合并后清理本地与远程分支，普通模式和 worktree 模式的命令不同。

走到这一步先读 `references/cleanup.md`（相对本 skill 目录）。

## 多仓库处理

每个仓库独立执行 2-8（含各自 4.2 ocr 审查、测试和 4.5 自查）。一个失败不影响其他。步骤 7 逐仓库分别询问；4.6 的无关发现各仓库合成一张清单只问一次（各仓库都走到 4.6 再统一问，问完才推送）。

## 禁止操作

`git push --force` / `git reset --hard` / `git checkout -- .` / 未授权合并 PR / 非 squash 策略（rebase 或 merge commit）/ 提交敏感文件
