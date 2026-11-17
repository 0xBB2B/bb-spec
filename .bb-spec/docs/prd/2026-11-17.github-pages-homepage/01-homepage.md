---
name: 01-homepage
description: 中英双语的 bb-spec 单页介绍主页：深色终端风，按浏览器语言选默认语言，手机能看
date: 2026-11-17
---

# 介绍主页

## 用户故事
### P0：作为第一次听说 bb-spec 的开发者，我想要打开一个链接就看懂它解决什么问题、怎么用、怎么装，以便决定要不要试

**用例（主路径）**
- 场景：一位中文开发者在群里看到 `https://0xbb2b.github.io/bb-spec/`，用浏览器语言为 `zh-CN` 的电脑第一次打开。
- 操作：从上往下滚动；点标题区的「安装」按钮；点终端窗口的「复制」；点「在 GitHub 上查看」。
- 预期：页面是中文；依次看到标题区、「它解决什么问题」、「流水线怎么走」、「安装」、页脚；点「安装」页面滚到安装区块；点「复制」后按钮变成「已复制」，1.6 秒后变回「复制」，剪贴板里是三行安装命令；点「在 GitHub 上查看」进入 `https://github.com/0xBB2B/bb-spec`。

### P0：作为英文读者，我想要看到英文页面，以便读懂

**用例（主路径）**
- 场景：浏览器语言为 `en-US`，第一次打开主页。
- 操作：直接看页面；然后点「中文」；再刷新页面。
- 预期：第一次打开是英文；点「中文」后整页立即变中文，不刷新页面；刷新后仍是中文。

**用例（边界）**
- 场景：浏览器语言为 `zh-TW`，第一次打开。→ 预期：显示中文（简体文案）。
- 场景：浏览器语言为 `ja-JP`，第一次打开。→ 预期：显示英文。
- 场景：浏览器禁止网站存储数据（如隐私模式下存储写入报错），浏览器语言 `en-US`，点「中文」。→ 预期：整页切到中文，不报错；刷新后回到英文。
- 场景：浏览器关闭了脚本。→ 预期：页面完整显示中文内容，所有链接可点。

### P1：作为用手机的访客，我想要在手机上正常阅读，以便随手看

**用例（主路径）**
- 场景：在 390px 宽的手机浏览器里打开主页。
- 操作：上下滚动整页。
- 预期：页面没有横向滚动；顶栏只剩 `bb-spec`、`[GitHub]` 和语言切换；三个面板上下排列；流水线竖排；安装命令比屏幕宽时只在终端窗口里左右滑。

## 约束

### 页面内容（中英文逐字照下表）
- 主页是一个页面，从上到下依次是：顶栏、标题区、「它解决什么问题」区块、「流水线怎么走」区块、「安装」区块、页脚。
- 各处文字逐字照下表；表里同一行的中文和英文是同一位置在两种语言下的文字。命令、子插件名、页脚四项在两种语言下相同。

| 位置 | 中文 | English |
|---|---|---|
| 浏览器标签页标题 | `bb-spec — PRD 驱动的 Claude Code 流水线` | `bb-spec — A PRD-driven Claude Code pipeline` |
| 顶栏左侧 | `bb-spec`（前面一个橙色圆点） | 同左 |
| 顶栏链接 | `[解决什么]` `[流水线]` `[安装]` `[GitHub]` | `[Why]` `[Pipeline]` `[Install]` `[GitHub]` |
| 语言切换 | `中文 \| English` | 同左 |
| 标题区注释行 | `# Claude Code 插件` | `# Claude Code plugin` |
| 大标题 | `一条 PRD 驱动的 Claude Code 流水线，把模糊需求一路带到可交付的代码。` | `A PRD-driven Claude Code pipeline that carries fuzzy requirements all the way to shipped code.` |
| 副标题 | `每个阶段可追溯、可断点恢复、经对抗验证。` | `Every stage traceable, resumable, and adversarially verified.` |
| 两个按钮 | `安装`、`在 GitHub 上查看` | `Install`、`View on GitHub` |
| 终端窗口 | 标题栏文字 `claude`，右侧按钮 `复制`；点后变 `已复制` | 标题栏 `claude`，按钮 `Copy`；点后变 `Copied` |
| 终端窗口三行命令 | `/plugin marketplace add 0xBB2B/bb-spec`、`/plugin install bb-spec-core@0xbb2b`、`/plugin install bb-spec-workflow@0xbb2b` | 同左 |
| 区块标题 1 | `## 它解决什么问题` | `## What it solves` |
| 区块 1 导语 | `每次交接物都是磁盘上的文档，不是会话里的临时记忆。所以它能断点续、能换 AI 接手、能逐级追溯。` | `Every handoff is a file on disk, not a memory in the chat. That is what makes it resumable, AI-swappable, and auditable end to end.` |
| 面板 01 标题 | `三 Agent 隔离执行` | `Three-agent isolated execution` |
| 面板 01 正文 | `写实现的 Agent 看不到 PRD，只看测试，没法“照着意图蒙混”。测试、实现、审查由互相看不见的三方分别完成。` | `The Impl agent never sees the PRD, only the tests, so it cannot quietly “teach to intent”. Tests, implementation, and review are written by mutually-blind agents.` |
| 面板 02 标题 | `磁盘文档是唯一交接物` | `Disk documents as the only handoff` |
| 面板 02 正文 | `每个阶段交接的是文件，不是会话记忆。跨会话、/clear 之后，甚至换一个模型接手，都能无损续接。` | `Every stage hands off a file, not chat memory, so a run resumes losslessly across sessions, /clear, or even a different model picking up the work.` |
| 面板 03 标题 | `代码和 PRD 经 git 双向可查` | `Code and PRD, traceable both ways through git` |
| 面板 03 正文 | `代码是唯一事实来源，PRD 只写为什么。每个 commit 带需求标记，从功能能找到代码，从函数能查回当时的需求与取舍。` | `Code is the single source of truth and the PRD only records why. Every commit carries a requirement trailer, so you can go from a feature to its code and from a function back to the requirement and trade-offs behind it.` |
| 区块标题 2 | `## 流水线怎么走` | `## How the pipeline runs` |
| 区块 2 导语 | `你读完 PRD 批准一次，/plan、/exec、/doc-update 自动接着跑；/git-push 由你手动触发。` | `You read the PRD and approve once. /plan, /exec and /doc-update then run on their own; /git-push is triggered by you.` |
| 节点 1 | `/prd` · `做什么` · `质疑、澄清、拆解，落盘 PRD，请你读完确认。` 小标签 `唯一一次批准` | `/prd` · `what` · `Challenge, clarify, break down, then write the PRD for you to read and confirm.` 小标签 `the only approval` |
| 节点 2 | `/plan` · `怎么做` · `把 PRD 变成函数级实施计划。只有要引入新技术时才停下问你。` | `/plan` · `how` · `Turns the PRD into a function-level plan. Stops only when new tech is needed.` |
| 节点 3 | `/exec` · `Red → Green → Review` · `三个互相隔离的 Agent 依次写测试、写实现、做审查。进度写进 PROGRESS.md，中断后能接着跑。` | `/exec` · `Red → Green → Review` · `Three isolated agents write tests, implementation and review in turn. Progress goes to PROGRESS.md, so an interrupted run resumes.` |
| 节点 4 | `/doc-update` · `文档追平代码` · `代码是事实，让本次 PRD 和 README 等文档追平实际交付。` | `/doc-update` · `docs sync` · `Code is the truth: this PRD and docs like README are mirrored to what was actually delivered.` |
| 节点 5 | `/git-push` · `pre-review + 开 PR` · `分支规范自查，推送，开 PR。` | `/git-push` · `pre-review + open PR` · `Branch self-check, push, open the PR.` |
| 图例 | `自动衔接`、`由你手动触发` | `chained automatically`、`triggered by you` |
| 补充行 | `/revise 随时介入：有 bug 或结果和预期不符时，按根因诊断、定向修正、回归验证。` | `/revise anytime: for a bug or results that don’t match expectations, diagnose by root cause, apply a targeted fix, run a regression check.` |
| 区块标题 3 | `## 安装` | `## Install` |
| 区块 3 导语 | `在 Claude Code 里执行这三行：` | `Run these three lines inside Claude Code:` |
| 区块 3 说明 | `这两个子插件给你纪律和工作流。后端、前端的技术栈约束按需再装。` | `These two sub-plugins give you the disciplines and the workflow. Add the backend and frontend stack constraints when you need them.` |
| 子插件表表头 | `子插件` / `装了得到什么` | `Sub-plugin` / `What it gives you` |
| 表行 1 | `bb-spec-core` 小标签 `推荐基座`：`TDD / 版本策略 / Git 纪律，加 3 个被动 hook` | `bb-spec-core` 小标签 `recommended base`：`TDD / version-policy / git-workflow discipline, plus 3 passive hooks` |
| 表行 2 | `bb-spec-workflow` 小标签 `核心功能`：`prd → plan → exec → doc-update → revise → git-push，加 8 个 subagent` | `bb-spec-workflow` 小标签 `core`：`prd → plan → exec → doc-update → revise → git-push, plus 8 subagents` |
| 表行 3 | `bb-spec-backend`：`Go / REST API / 数据库 / 认证 / 授权 / 可观测性 / 服务治理 / 配置约束` | `bb-spec-backend`：`Go / REST API / DB / authN / authZ / observability / service / config constraints` |
| 表行 4 | `bb-spec-frontend`：`Vue 3 + TS + Vite + Tailwind + bun 技术栈与工程约定` | `bb-spec-frontend`：`Vue 3 + TS + Vite + Tailwind + bun stack & engineering conventions` |
| README 链接 | `完整说明在 README →` | `Full details are in the README →` |
| 页脚 | `MIT License`、`GitHub`、`Releases`、`README` | 同左 |

### 外观
- 颜色、字体、字号、间距、圆角、组件样式、动效按项目根 `DESIGN.md` 执行：深色底 `#0D1117`，全站等宽字体，主色橙 `#D97757`，链接和命令名蓝色 `#58A6FF`，内容区最宽 1048px 居中，只有深色一套配色。
- 顶栏贴顶固定，高 48px。
- 大标题前有橙色 `>`，末尾有闪烁的橙色光标。终端窗口标题栏有三个灰色圆点，每行命令前有橙色 `❯`；两个终端窗口（标题区、安装区块）内容相同。
- 三个面板的标题是橙色，前面依次标 `01` `02` `03`。
- 流水线五个节点横排，每个节点有蓝色命令名、橙色角色名、灰色说明；`/prd`→`/plan`、`/plan`→`/exec`、`/exec`→`/doc-update` 之间是橙色双线箭头，`/doc-update`→`/git-push` 之间是浅色虚线箭头；图例中橙色双线对应「自动衔接」，浅色虚线对应「由你手动触发」。
- 子插件表中 `bb-spec-core`、`bb-spec-workflow` 两行名字旁有橙色小标签。
- 页面只加载站内文件：不引用任何外部字体、脚本、样式表或图片。

### 语言
- 打开页面时的语言按下面顺序定：访客以前在本站点过「中文」或「English」→ 用他上次点的；否则浏览器首选语言以 `zh` 开头（不分大小写，`zh-CN`、`zh-TW`、`zh-HK`、`zh` 都算）→ 中文；其他情况 → 英文。
- 点「中文」或「English」→ 整页文字（含浏览器标签页标题）立即换成对应语言，不刷新页面；当前语言的按钮显示为橙底深色字，另一个按钮恢复普通样式；页面的语言标注同步改成 `zh-CN` 或 `en`；记住这次选择。
- 浏览器不允许本站存储数据时，点按钮照常切换语言，页面不报错；只是下次打开时不记得上次的选择。
- 浏览器关闭脚本时，页面显示完整的中文内容，所有链接可点（语言切换和复制按钮不起作用）。

### 交互
- 点顶栏 `[解决什么]`/`[Why]`、`[流水线]`/`[Pipeline]`、`[安装]`/`[Install]` → 页面滚到对应区块，区块标题不被固定顶栏挡住；点标题区 `安装`/`Install` 按钮 → 滚到「安装」区块；点顶栏左侧 `bb-spec` → 回到页面顶部。
- 点任一终端窗口的「复制」/`Copy` → 剪贴板写入三行安装命令（行与行之间用换行分隔，不带 `❯`）；按钮文字变成「已复制」/`Copied`，1.6 秒后变回。写剪贴板失败时按钮文字保持「复制」/`Copy` 不变，页面不报错。
- `在 GitHub 上查看`/`View on GitHub`、顶栏 `[GitHub]`、页脚 `GitHub` → `https://github.com/0xBB2B/bb-spec`。
- 页脚 `Releases` → `https://github.com/0xBB2B/bb-spec/releases`。
- 页脚 `MIT License` → `https://github.com/0xBB2B/bb-spec/blob/main/LICENSE`。
- `完整说明在 README →` 和页脚 `README`：中文时 → `https://github.com/0xBB2B/bb-spec#readme`；英文时 → `https://github.com/0xBB2B/bb-spec/blob/main/README.en.md`。
- 鼠标移到主按钮上 → 背景变浅橙 `#E1937A`；按下 → 深橙 `#D25D37`。鼠标移到次按钮上 → 边框变亮、背景变成面板色。鼠标移到子插件表某一行 → 这一行背景变成面板色。
- 用键盘 Tab 聚焦到任何可点的元素 → 出现 2px 蓝色描边。
- 系统设置了"减少动态效果"时 → 光标不闪，悬停没有过渡动画，页内跳转直接跳到位置、不做平滑滚动。

### 手机宽度（浏览器窗口宽度 ≤ 640px）
- 顶栏只显示 `bb-spec`、`[GitHub]` 和语言切换，三个页内链接隐藏。
- 大标题字号 22px。
- 三个面板上下排列。
- 流水线五个节点竖排，节点之间的箭头换成一行文字：橙色 `↓ 自动衔接`/`↓ chained automatically`，最后一处是浅色 `↓ 由你手动触发`/`↓ triggered by you`；图例隐藏。
- 子插件表去掉表头，每个子插件显示成名字一行、说明一行。
- 窗口宽 320px 到 640px 之间任意宽度，页面都没有横向滚动；安装命令比终端窗口宽时，只在终端窗口内部左右滑动。

## 验收
- [ ] 主页六部分顺序为顶栏、标题区、它解决什么问题、流水线怎么走、安装、页脚。
- [ ] 中文和英文下每个位置的文字与上表逐字一致（含浏览器标签页标题、复制按钮前后两种文字）。
- [ ] 外观各项（深色底、等宽字体、主色、蓝色链接、1048px 内容宽、48px 固定顶栏、光标、`❯`、面板编号、箭头样式与图例、橙色小标签）与约束一致。
- [ ] 页面加载时没有任何发往站外地址的请求。
- [ ] 无存储记录、浏览器语言 `zh-CN` / `zh-TW` / `zh` → 中文；`en-US` / `ja-JP` → 英文。
- [ ] 点过「English」后刷新 → 英文，即使浏览器语言是 `zh-CN`；点过「中文」后刷新 → 中文，即使浏览器语言是 `en-US`。
- [ ] 切换语言不刷新页面，标签页标题、页面语言标注、按钮选中样式同步变化。
- [ ] 存储被禁止时点语言按钮能切换，控制台无报错。
- [ ] 关闭脚本时页面显示完整中文内容。
- [ ] 顶栏三个页内链接、标题区「安装」按钮、顶栏 `bb-spec` 跳到正确位置，区块标题不被顶栏遮挡。
- [ ] 点「复制」后剪贴板内容是三行命令、无 `❯`；按钮变「已复制」/`Copied`，1.6 秒后复原；写剪贴板失败时按钮文字不变、无报错。
- [ ] GitHub、Releases、README、MIT License 链接按语言指向约束里的地址。
- [ ] 主按钮悬停 `#E1937A`、按下 `#D25D37`；次按钮悬停边框变亮、背景变面板色；表格行悬停背景变面板色。
- [ ] 键盘 Tab 聚焦时出现 2px 蓝色描边。
- [ ] 开启"减少动态效果"后光标不闪、无悬停过渡、页内跳转无平滑滚动。
- [ ] 窗口 ≤ 640px 时顶栏只剩三项、大标题 22px、面板上下排、流水线竖排且箭头换成文字、图例隐藏、子插件表无表头且名字说明分两行。
- [ ] 窗口宽 320px、390px、640px 时页面都没有横向滚动。

## 验证路径
1. 用浏览器直接打开主页文件，浏览器语言 `zh-CN` → 中文页面，六部分顺序正确，逐项核对文字表。
2. 点「English」→ 整页英文、标签页标题变英文、`English` 按钮橙底；逐项核对英文文字；刷新 → 仍英文。
3. 清掉站点存储、浏览器语言改 `en-US` 刷新 → 英文；改 `zh-TW` 刷新 → 中文。
4. 点顶栏三个链接和「安装」按钮 → 滚到对应区块；点「复制」→ 粘贴得到三行命令，按钮 1.6 秒后复原。
5. 打开开发者工具的网络面板刷新 → 没有站外请求。
6. 窗口缩到 390px → 无横向滚动，手机布局各项符合约束；再缩到 320px → 仍无横向滚动。
7. 关闭脚本刷新 → 完整中文内容。
