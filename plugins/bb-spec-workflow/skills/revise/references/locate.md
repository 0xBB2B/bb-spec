> 用在 /revise 步骤 1：定位修复现场、读取配置、定位 PRD/plan/代码/测试四层资产。

**先定位修复现场（worktree 感知）**：主仓库目录常年停在 main，进行中的功能分支可能在 `~/.bb-spec/worktrees/` 下的某棵 worktree 里。读任何资产前先跑 `git branch --show-current` + `git worktree list --porcelain`：

- **已在 linked worktree 或非 main/master 功能分支** → cwd 即修复现场，继续
- **在主仓库且 HEAD 为 main/master**，且问题指向某棵 worktree 上进行中的工作（其 plan PROGRESS.md 未全完成，或分支领先 main）→ 后续读资产、修代码、跑测试、commit **全部定位到该 worktree 内执行**（`cd` 进去或全程用其绝对路径）；多棵候选 → AskUserQuestion 让用户选
- **问题针对 main 上已合入的代码** → 属新修复任务，按 git-workflow 先确定开分支方式再动手，**禁止直接在 main 工作区改代码**

现场确定后，在**该目录**下运行 `${CLAUDE_PLUGIN_ROOT}/scripts/bbspec-paths.sh`，`${DOCS_DIR}` 取输出的 `docs_dir`，`${CACHE_DIR}` 取 `cache_dir`。读项目根 `AGENTS.md`，按下表定位四层资产并全部读取：

| 资产 | 定位方式 | 目的 |
|---|---|---|
| 实现代码 | 有 `ARCHITECTURE.md` 先按模块地图定位；再按问题描述的功能名搜 `${DOCS_DIR}/prd/*/OVERVIEW.md` 的 `features:` → 在各代码仓库里 `git log --grep "Requirement: <目录名>" --name-only`；实现代码按「调查交给子代理」分流 | 确认"实际做了什么"（附 `文件:行号`） |
| 测试文件 | 测试目录 + 命名惯例 | 确认"验了什么" |
| 相关 PRD | 在函数所在仓库里对出问题的函数跑表格下方的命令（按函数名 no match 时改用行号范围 `-L <起始行>,<结束行>:<文件>`），读最新那个 commit 的 `Requirement` 行指向的 PRD 与 commit 正文（squash 合并的 commit 可能有多行，逐个读）；无标记的 commit 是接入 bb-spec 之前的老代码，没有对应 PRD | 确认"当初要的行为与为什么" |
| plan 文件 | 进行中主题的 INDEX.md（无进行中 plan 则跳过） | 确认"怎么做"的设计 |

查相关 PRD 的命令（列出改过该函数的 commit 和各自的 `Requirement` 行，最新的在前）：

```bash
git log -L :<函数>:<文件> -s --format='%h %s%n%b' | grep -e '^[0-9a-f]\{7,40\} ' -e '^Requirement:'
```

建立完整链路：**PRD 要什么 → plan 怎么做 → 代码做了什么 → 测试验了什么**。
