---
name: 01-homepage-page
description: 在 site/ 下手写中英双语单页主页（HTML + CSS + JS，无构建、无外部资源），附行为测试
---
# 介绍主页页面

## 目标
仓库新增 `site/` 目录，用浏览器直接打开 `site/index.html` 就是定稿的深色终端风 bb-spec 主页，支持中英切换、按浏览器语言选默认语言、复制安装命令、手机布局。

## 业务规则（来源：PRD 01-homepage）
- 一个页面，从上到下：顶栏、标题区、「它解决什么问题」、「流水线怎么走」、「安装」、页脚。所有文字逐字照下方「成品定义」的 `COPY`；命令、子插件名、页脚四项两种语言相同。
- 外观按项目根 `DESIGN.md`（已在仓库里，必须先读）：深色底 `#0D1117`、全站等宽字体、主色橙 `#D97757`、链接与命令名蓝 `#58A6FF`、内容区最宽 1048px 居中、只有深色一套。顶栏贴顶固定高 48px。大标题前橙色 `>`，末尾闪烁橙色光标。终端窗口标题栏三个灰圆点 + 文字 `claude` + 右侧复制按钮，每行命令前橙色 `❯`；标题区和安装区各一个终端窗口，内容相同。三个面板标题橙色，前标 `01` `02` `03`。流水线五节点横排：蓝色命令名、橙色角色名、灰色说明；前三处箭头橙色双线，`/doc-update`→`/git-push` 浅色虚线（正文色 `#E6EDF3`）；图例橙色双线=自动衔接、浅色虚线=由你手动触发。`/prd` 节点带橙色小标签；子插件表 core、workflow 两行名字旁橙色小标签。
- 只加载站内文件：不得出现任何指向外部的 `<link>`、`<script src>`、`@import`、`url(http…)`、`<img src="http…">`。
- 打开时语言：本地存储键 `bb-spec-lang` 的值为 `zh` 或 `en` → 用它；否则浏览器首选语言（`navigator.languages[0]`，没有则 `navigator.language`）以 `zh` 开头（不分大小写）→ `zh`；否则 `en`。
- 点「中文」/「English」：不刷新，整页 `data-i18n` 文字、`document.title` 换成对应语言；当前语言按钮橙底深色字、另一个恢复；`<html lang>` 设为 `zh-CN` 或 `en`；把选择写入 `bb-spec-lang`。存储读写抛异常时吞掉，照常切换。
- 没有脚本时：`index.html` 里写死的就是完整中文内容，`<html lang="zh-CN">`，所有链接是真实 `href`。
- 页内跳转：顶栏 `[解决什么]` `[流水线]` `[安装]` 和标题区「安装」按钮用锚点跳到 `#problem` `#pipeline` `#install`；区块标题不被固定顶栏挡住（如 `scroll-margin-top`）；顶栏左侧 `bb-spec` 跳到 `#top`。
- 复制：点任一终端窗口的复制按钮 → `navigator.clipboard.writeText` 写入三行命令（`\n` 分隔、不带 `❯`）；成功后按钮文字变当前语言的 `copied`，1600ms 后变回 `copy`；失败（Promise 拒绝或 clipboard 不存在）时文字不变、不抛错。
- 链接：GitHub 三处 → `https://github.com/0xBB2B/bb-spec`；Releases → `https://github.com/0xBB2B/bb-spec/releases`；README 两处中文 → `https://github.com/0xBB2B/bb-spec#readme`，英文 → `https://github.com/0xBB2B/bb-spec/blob/main/README.en.md`（切语言时 `href` 一起换）。
- 悬停：主按钮背景 `#E1937A`，按下 `#D25D37`；次按钮边框变亮（`#6E7681`）、背景变面板色 `#161B22`；子插件表行悬停背景变面板色。键盘聚焦 `:focus-visible` 2px 蓝色描边。`prefers-reduced-motion: reduce` 时光标不闪、无过渡、`scroll-behavior: auto`。
- 窗口 ≤ 640px：顶栏只留 `bb-spec`、`[GitHub]`、语言切换；大标题 22px；面板上下排；流水线竖排，箭头换成文字行（橙色 `↓ 自动衔接`，最后一处浅色 `↓ 由你手动触发`，英文对应 `↓ chained automatically` / `↓ triggered by you`），图例隐藏；子插件表隐藏表头、每行名字一行说明一行。320–640px 任意宽度页面无横向滚动，长命令只在终端窗口内 `overflow-x: auto`。
- 视觉参考：定稿原型 `.bb-spec/.cache/ui-preview/2026-11-17.github-pages-homepage.html`（本地缓存，不进 git），布局、间距、细节以它和 `DESIGN.md` 为准。

## 涉及文件
- `site/index.html` 新建
- `site/style.css` 新建
- `site/app.js` 新建
- `tests/homepage.test.sh` 新建（Test Agent 写）

## 成品定义
页面文案（`site/app.js` 里的 `COPY` 原样使用；`index.html` 静态内容用 `zh` 一列）：

```js
const COPY = {
  zh: {
    title: 'bb-spec — PRD 驱动的 Claude Code 流水线',
    nav: { problem: '[解决什么]', pipeline: '[流水线]', install: '[安装]', github: '[GitHub]' },
    kicker: '# Claude Code 插件',
    tag: '一条 PRD 驱动的 Claude Code 流水线，把模糊需求一路带到可交付的代码。',
    sub: '每个阶段可追溯、可断点恢复、经对抗验证。',
    ctaInstall: '安装', ctaGithub: '在 GitHub 上查看',
    copy: '复制', copied: '已复制',
    problemTitle: '它解决什么问题',
    problemLead: '每次交接物都是磁盘上的文档，不是会话里的临时记忆。所以它能断点续、能换 AI 接手、能逐级追溯。',
    problems: [
      ['三 Agent 隔离执行', '写实现的 Agent 看不到 PRD，只看测试，没法“照着意图蒙混”。测试、实现、审查由互相看不见的三方分别完成。'],
      ['磁盘文档是唯一交接物', '每个阶段交接的是文件，不是会话记忆。跨会话、/clear 之后，甚至换一个模型接手，都能无损续接。'],
      ['代码和 PRD 经 git 双向可查', '代码是唯一事实来源，PRD 只写为什么。每个 commit 带需求标记，从功能能找到代码，从函数能查回当时的需求与取舍。'],
    ],
    pipeTitle: '流水线怎么走',
    pipeLead: '你读完 PRD 批准一次，/plan、/exec、/doc-update 自动接着跑；/git-push 由你手动触发。',
    stages: [
      ['/prd', '做什么', '质疑、澄清、拆解，落盘 PRD，请你读完确认。'],
      ['/plan', '怎么做', '把 PRD 变成函数级实施计划。只有要引入新技术时才停下问你。'],
      ['/exec', 'Red → Green → Review', '三个互相隔离的 Agent 依次写测试、写实现、做审查。进度写进 PROGRESS.md，中断后能接着跑。'],
      ['/doc-update', '文档追平代码', '代码是事实，让本次 PRD 和 README 等文档追平实际交付。'],
      ['/git-push', 'pre-review + 开 PR', '分支规范自查，推送，开 PR。'],
    ],
    once: '唯一一次批准', auto: '自动衔接', manual: '由你手动触发',
    revise: '/revise 随时介入：有 bug 或结果和预期不符时，按根因诊断、定向修正、回归验证。',
    installTitle: '安装',
    installLead: '在 Claude Code 里执行这三行：',
    installNote: '这两个子插件给你纪律和工作流。后端、前端的技术栈约束按需再装。',
    th: ['子插件', '装了得到什么'],
    plugins: [
      ['bb-spec-core', '推荐基座', 'TDD / 版本策略 / Git 纪律，加 3 个被动 hook'],
      ['bb-spec-workflow', '核心功能', 'prd → plan → exec → doc-update → revise → git-push，加 8 个 subagent'],
      ['bb-spec-backend', '', 'Go / REST API / 数据库 / 认证 / 授权 / 可观测性 / 服务治理 / 配置约束'],
      ['bb-spec-frontend', '', 'Vue 3 + TS + Vite + Tailwind + bun 技术栈与工程约定'],
    ],
    more: '完整说明在 README →',
    readme: 'https://github.com/0xBB2B/bb-spec#readme',
  },
  en: {
    title: 'bb-spec — A PRD-driven Claude Code pipeline',
    nav: { problem: '[Why]', pipeline: '[Pipeline]', install: '[Install]', github: '[GitHub]' },
    kicker: '# Claude Code plugin',
    tag: 'A PRD-driven Claude Code pipeline that carries fuzzy requirements all the way to shipped code.',
    sub: 'Every stage traceable, resumable, and adversarially verified.',
    ctaInstall: 'Install', ctaGithub: 'View on GitHub',
    copy: 'Copy', copied: 'Copied',
    problemTitle: 'What it solves',
    problemLead: 'Every handoff is a file on disk, not a memory in the chat. That is what makes it resumable, AI-swappable, and auditable end to end.',
    problems: [
      ['Three-agent isolated execution', 'The Impl agent never sees the PRD, only the tests, so it cannot quietly “teach to intent”. Tests, implementation, and review are written by mutually-blind agents.'],
      ['Disk documents as the only handoff', 'Every stage hands off a file, not chat memory, so a run resumes losslessly across sessions, /clear, or even a different model picking up the work.'],
      ['Code and PRD, traceable both ways through git', 'Code is the single source of truth and the PRD only records why. Every commit carries a requirement trailer, so you can go from a feature to its code and from a function back to the requirement and trade-offs behind it.'],
    ],
    pipeTitle: 'How the pipeline runs',
    pipeLead: 'You read the PRD and approve once. /plan, /exec and /doc-update then run on their own; /git-push is triggered by you.',
    stages: [
      ['/prd', 'what', 'Challenge, clarify, break down, then write the PRD for you to read and confirm.'],
      ['/plan', 'how', 'Turns the PRD into a function-level plan. Stops only when new tech is needed.'],
      ['/exec', 'Red → Green → Review', 'Three isolated agents write tests, implementation and review in turn. Progress goes to PROGRESS.md, so an interrupted run resumes.'],
      ['/doc-update', 'docs sync', 'Code is the truth: this PRD and docs like README are mirrored to what was actually delivered.'],
      ['/git-push', 'pre-review + open PR', 'Branch self-check, push, open the PR.'],
    ],
    once: 'the only approval', auto: 'chained automatically', manual: 'triggered by you',
    revise: '/revise anytime: for a bug or results that don’t match expectations, diagnose by root cause, apply a targeted fix, run a regression check.',
    installTitle: 'Install',
    installLead: 'Run these three lines inside Claude Code:',
    installNote: 'These two sub-plugins give you the disciplines and the workflow. Add the backend and frontend stack constraints when you need them.',
    th: ['Sub-plugin', 'What it gives you'],
    plugins: [
      ['bb-spec-core', 'recommended base', 'TDD / version-policy / git-workflow discipline, plus 3 passive hooks'],
      ['bb-spec-workflow', 'core', 'prd → plan → exec → doc-update → revise → git-push, plus 8 subagents'],
      ['bb-spec-backend', '', 'Go / REST API / DB / authN / authZ / observability / service / config constraints'],
      ['bb-spec-frontend', '', 'Vue 3 + TS + Vite + Tailwind + bun stack & engineering conventions'],
    ],
    more: 'Full details are in the README →',
    readme: 'https://github.com/0xBB2B/bb-spec/blob/main/README.en.md',
  },
};
const COMMANDS = [
  '/plugin marketplace add 0xBB2B/bb-spec',
  '/plugin install bb-spec-core@0xbb2b',
  '/plugin install bb-spec-workflow@0xbb2b',
];
```

页脚四项文字固定为 `MIT License`、`GitHub`、`Releases`、`README`，两种语言相同。

## 函数清单
### site/app.js
| 函数名 | 职责 |
|---|---|
| `pickLang` | 纯函数：按"存储值 → 浏览器首选语言 → en"规则返回 `zh` 或 `en` |
| `readSavedLang` / `saveLang` | 读写本地存储键 `bb-spec-lang`，任何异常吞掉（读失败返回空） |
| `applyLang` | 把 `COPY[lang]` 写到所有 `data-i18n` 元素、`document.title`、README 链接 `href`、`<html lang>`、语言按钮选中态 |
| `copyCommands` | 写剪贴板三行命令；成功时改按钮文字并 1600ms 后复原，失败不改 |
| `init` | 页面加载时定语言并 `applyLang`，绑定语言按钮和复制按钮的点击 |

### site/index.html / site/style.css
静态结构与样式，无函数。

## 协作关系
`init` → `readSavedLang` + `pickLang` → `applyLang`；语言按钮点击 → `applyLang` + `saveLang`；复制按钮点击 → `copyCommands`。`app.js` 结尾把 `{ COPY, COMMANDS, pickLang, applyLang, copyCommands }` 挂到 `window.BBHomepage`，供测试调用；`index.html` 用 `<script src="app.js" defer>` 引入，用 `<link rel="stylesheet" href="style.css">` 引入样式。无外部依赖。

## 验证方式
- 测试入口：`bash tests/homepage.test.sh`（本机需 node，参照 `tests/ui-preview-shell.test.sh` 用 node 自带 `vm` 模块在假 `window` / `document` 里执行 `site/app.js`）。
- 测试输入与预期：
  - 文件：`site/index.html`、`site/style.css`、`site/app.js` 存在；`node --check site/app.js` 通过。
  - 静态中文：`index.html` 含 `<html lang="zh-CN">`、中文 `title`，以及上方 `COPY.zh` 的每段正文、三行命令、页脚四项；含 `id="problem"`、`id="pipeline"`、`id="install"` 锚点；GitHub / Releases / README 链接是约束里的地址。
  - 无外部资源：三个文件里没有 `http(s)://` 开头的 `src=`、`<link href>`、`@import`、`url(`（`<a href>` 外链除外）。
  - 样式：`style.css` 含 `#0D1117`、`#D97757`、`#58A6FF`、`#E1937A`、`#D25D37`、`max-width: 640px` 媒体查询、`prefers-reduced-motion` 媒体查询、`:focus-visible`。
  - `window.BBHomepage.COPY` 的 `zh` / `en` 与成品定义逐字一致（两份键结构相同）。
  - `pickLang(saved, languages)`：`(null, ['zh-CN'])`、`(null, ['zh-TW'])`、`(null, ['ZH'])` → `zh`；`(null, ['en-US'])`、`(null, ['ja-JP'])`、`(null, [])` → `en`；`('en', ['zh-CN'])` → `en`；`('zh', ['en-US'])` → `zh`；`('fr', ['en-US'])` → `en`。
  - 存储：假 `localStorage` 的 `getItem`/`setItem` 抛异常时，加载 `app.js` 和点击语言按钮都不抛错，`<html lang>` 仍切换。
  - `applyLang('en')` 后：带 `data-i18n` 的假元素文字变英文、`document.title` 为英文标题、README 链接 `href` 为英文地址、`<html lang>` 为 `en`。
  - `copyCommands`：假 `navigator.clipboard.writeText` 收到 `COMMANDS.join('\n')`；成功后按钮文字为 `已复制`（`zh`），推进假时钟 1600ms 后为 `复制`；`writeText` 拒绝时按钮文字保持 `复制`，无未捕获异常。
- [ ] 以上全部断言通过
- [ ] 浏览器直接打开 `site/index.html` 与定稿原型目测一致（/exec 收尾时做原型对比）
