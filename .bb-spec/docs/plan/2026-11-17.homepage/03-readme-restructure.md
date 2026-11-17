---
name: 03-readme-restructure
description: 五份 README 按统一的新章节顺序重排：卖点提前、主页徽章、安装只写一处、阶段一览折叠细节、Hooks 合并、末尾放测试和升级说明
---
# README 改版

## 目标
`README.md`、`README.en.md`、`README.zh-TW.md`、`README.ja.md`、`README.ko.md` 五份按同一章节顺序重排，开头先讲清"是什么、为什么、怎么装"，不丢任何链接和命令，现有测试照常通过。

## 业务规则（来源：PRD 03-readme-restructure，AGENTS.md 项目约束）
- 五份用各自语言写同样的内容、同样的章节顺序；改一份其余四份同一次一起改（AGENTS.md 项目约束）。
- 开头保留横幅、`<h1>`、标语两段、徽章行、语言切换行、导航行；徽章行末尾加主页徽章：`<a href="https://0xbb2b.github.io/bb-spec/"><img src="https://img.shields.io/badge/Homepage-0xbb2b.github.io%2Fbb--spec-D97757?style=for-the-badge" alt="<各语言的"主页">" /></a>`。
- 二级标题（`## `）按下面顺序，每个以给定 emoji 开头，emoji 后的文字用各语言自己的写法：
  1. `✨` 它解决什么问题 —— 内容是原「设计渊源」末尾「BB-Spec 自己的取舍」三条（三 Agent 隔离执行、磁盘文档作为唯一交接物、代码 ⇄ PRD 经 git 双向可查），原文照搬，前面加一句原「核心流水线」后的"为什么这条流水线靠得住"那句话作导语（该句从原位置移走）。
  2. `📦` 安装 —— 原「Claude Code 安装 / Install」整节：`/plugin marketplace add 0xBB2B/bb-spec`、四个子插件表（含各自安装命令）、按需取用说明、`~/.claude/settings.json` 示例。
  3. `🚀` 日常命令 —— 原「30 秒上手」里的"日常要手动敲的 6 条命令"表和 `/git-clone`、可选命令那一行；原「30 秒上手」的三行命令代码块删掉（安装命令只在 📦 一节出现）。
  4. `🔁` 核心流水线 —— 原流程图代码块；`### 🎯` 阶段一览；「附带产物」两行原样保留（其中被动 hook 那一行 `**3 个被动 hook**(…):…` 格式和文字不动，测试按它校验）。
  5. `🧩` 配套约束 Skills —— 原样。
  6. `🔄` 版本与更新 —— 原样，但去掉其中的「从 13 及更早版本升级」小节（移到第 11 节）。
  7. `🪝` Hooks —— 原「默认启用的 Hooks」说明和表在前，原「Hook 开关速查」表紧随其后（作为 `###` 小节），两表之间没有别的 `##` 章节。表格行文字不动（测试按 `| \`background-script-wait\` |` 行和开关速查行文字校验）。
  8. `🛠️` 推荐配套 —— 原样。
  9. `💡` 设计渊源 —— 只保留导语和借鉴对比表；「BB-Spec 自己的取舍」三条已移到第 1 节，这里不再出现。
  10. `🧪` 测试 —— 原样。
  11. `⬆️` 从 13 及更早版本升级 —— 原小节内容原样。
  12. `📜` License —— 原样，结尾居中署名保留。
- 阶段一览：每个命令条目（`/git-clone`、`/prd`、`/plan`、`/exec`、`/doc-update`、`/git-push`、`/revise`、`/test-webview`、`/test-api`）保留首行粗体命令名与一句话说明；下面在折叠块外最多 3 条要点（挑最能说明"它做什么"的）；其余要点全部放进紧跟其后的 `<details><summary>…</summary>…</details>`，summary 用各语言的"更多细节"，一条都不删。
- 顶部导航行改成指向新章节：它解决什么问题、安装、日常命令、核心流水线、阶段一览、约束 Skills、Hooks、设计渊源；每个锚点按 GitHub 标题锚点规则生成：转小写，删掉除字母、数字、汉字等文字字符、空格、`-`、`_` 以外的字符（emoji 和标点都删），空格换成 `-`。例：`## 🚀 30 秒上手` → `#-30-秒上手`。
- 不丢信息：旧版每份 README 里的每个外部链接地址、每条以 `/` 开头的 Claude Code 命令，在新版同一份里仍出现。
- 改完 `tests/*.sh` 与 `tests/validate.sh` 全部通过。

## 涉及文件
- `README.md` 修改
- `README.en.md` 修改
- `README.zh-TW.md` 修改
- `README.ja.md` 修改
- `README.ko.md` 修改
- `tests/readme-structure.test.sh` 新建（Test Agent 写）

## 函数清单
无过程式代码（文档改写）。

## 协作关系
不依赖 01、02 的文件，只用到固定主页地址 `https://0xbb2b.github.io/bb-spec/`。已有测试 `tests/background-script-wait.test.sh`、`tests/investigation-rules.test.sh`、`tests/script-runner-rules.test.sh` 会检查 README 中 hook 表、被动 hook 列表、开关速查、子代理名单的原文，改写时这些行保持原样。

## 验证方式
- 测试入口：`bash tests/readme-structure.test.sh`（bash + python3 标准库）。
- 测试输入：仓库根五份 README。
- 预期结果：
  - 每份徽章行含 `https://0xbb2b.github.io/bb-spec/` 链接。
  - 每份 `## ` 标题按出现顺序取首个 emoji，序列恰为 `✨ 📦 🚀 🔁 🧩 🔄 🪝 🛠️ 💡 🧪 ⬆️ 📜`，五份相同。
  - 每份 `/plugin marketplace add 0xBB2B/bb-spec` 恰出现 1 次，且位于 `📦` 章节内；`~/.claude/settings.json` 示例也在 `📦` 章节内。
  - 每份 `💡` 章节内不含三条差异点的粗体标题（中文版即 `**三 Agent 隔离执行**`，其他语言取该文件 `✨` 章节里的三个粗体标题做比对）。
  - `🪝` 章节同时含 `| \`background-script-wait\` |` 行和开关速查表。
  - 阶段一览中九个命令条目，每个在 `<details>` 之前的二级要点（以两个空格加 `- ` 开头的行）不超过 3 条；每份至少 9 个 `<details>`。
  - 每份顶部导航里每个 `href="#…"` 锚点都对应本文件某个标题按上述规则生成的锚点。
  - 现有 `tests/*.sh`、`tests/validate.sh` 全部通过。
- [ ] 以上断言全部通过
- [ ] 一次性核对（/exec Review 时做，不写进常驻测试）：用 `git show 1341b3f:<文件>` 取旧版，每份旧版的外部链接集合与 `/` 开头命令集合都是新版同一份的子集
