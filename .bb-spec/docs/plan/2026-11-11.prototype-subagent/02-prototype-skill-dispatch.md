---
name: 02-prototype-skill-dispatch
description: /prototype 规程改成调度：主对话写派工说明、派原型子代理、转报告、问用户、用 SendMessage 转回用户原话
---
# /prototype 改成派子代理

## 目标

运行 `/prototype` 时，主对话只派工和传话，出原型和对比都由原型子代理 `bb-spec-workflow:prototype-designer` 完成。

## 业务规则（来源：PRD 01-prototype-subagent）

"主对话"是用户直接对话的那个 Claude。"派工说明"是主对话派子代理时写给它的那段话。"调用方"是调用 `/prototype` 的一方：`/prd`、`/revise`、`/exec`，或用户直接运行。

1. 出原型和对比两种模式都派原型子代理做。改动再小（只换一个按钮文字、一个颜色值）也派。
2. 主对话在 `/prototype` 里只做这几件事：运行路径脚本确定缓存目录和原型文件路径、写派工说明、派子代理、用 `open` 在浏览器里打开原型文件、把子代理的报告给用户看、问用户、把用户的答复发给子代理、把最后的结果交给调用方。主对话不读项目源码，不读、不写、不改原型文件的内容，不写 DESIGN.md。
3. 出原型的派工说明必须写全 6 项，缺一项就先补齐再派：模式（出原型）；主题；原型文件的完整路径；调用方是谁；需求结论（要改哪些页面、每处要改成什么、用户已经明确定下的细节，用户的原话照抄）；DESIGN.md 应在的完整路径，原型文件旁边已有同名设计规范草稿时再写草稿的完整路径。6 项之外附上插件模板目录的完整路径 `${CLAUDE_PLUGIN_ROOT}/templates`（子代理要从这里复制外壳）。
4. 对比的派工说明必须写全 3 项：模式（对比）、原型文件的完整路径、截图目录的完整路径。截图目录是 `${CACHE_DIR}/ui-compare/<日期>.<主题>/`，名字和原型文件一致。
5. 主对话把子代理的报告原样给用户看，不删、不改写其中「待用户确认的问题」。第一轮报告回来后用 `open <原型文件路径>` 打开原型；之后每轮提醒用户刷新页面。
6. 报告里有「待用户确认的问题」时，主对话问用户，再把用户的答复发给子代理。
7. 用户提了修改意见时，主对话用 SendMessage 把用户的原话发给同一个原型子代理。可以在原话后面补充说明，但不改写原话。
8. 发不到原来的子代理时（没有 SendMessage 工具、找不到那个子代理、已经换了会话），新派一个原型子代理：派工说明在 6 项之外写明"原型文件已存在，接着改"，并附上用户的原话。
9. 用户明确说"可以"之后，主对话告诉子代理"用户已确认"，拿回确认内容清单。`/prd` 照清单写约束和验收，`/revise` 把清单当作期望行为；用户直接运行时，主对话告诉用户原型文件路径后结束。
10. 对比每次新派一个原型子代理，把它交回的结果（一致、不一致、没跑起来）原样交给调用方。
11. 子代理派不出去时（比如账号用不了 `fable` 模型），主对话停下，把报错原文告诉用户，由用户决定怎么办，不自己接手出原型。
12. `/prd`、`/revise`、`/exec` 调用 `/prototype` 的参数形式保持为 `<主题> --file <路径>` 和 `--compare <路径>`。
13. 一次原型的临时文件都以 `<日期>.<主题>` 开头：原型是 `ui-preview/<日期>.<主题>.html`，对比截图放在 `ui-compare/<日期>.<主题>/` 目录下。`/revise` 出原型时主题前面加 `revise-`，文件是 `ui-preview/<YYYY-MM-DD>.revise-<主题>.html`（原来是 `revise-<YYYY-MM-DD>-<主题>.html`）。
14. 原型文件旁边有两个设计规范临时文件：`.DESIGN.draft.md` 是用户还没同意的，`.DESIGN.md` 是用户已同意、等 `/prd` 写 PRD 文件时写进项目的。`/prd` 落盘 PRD 时只把 `.DESIGN.md` 写入项目，`.DESIGN.draft.md` 不写入。`/prd` 换到新的工作目录、给 PRD 目录改名、用户选"不做了"时，这两个临时文件跟着原型文件一起搬、一起改名、一起删。派工说明里"草稿的完整路径"那一项，旁边有哪个临时文件就写哪个的路径。

决策理由：Claude Code 官方文档写明子代理没有向用户提问的工具，所以问用户只能由主对话做；主对话用 SendMessage 给跑完一轮的子代理发消息时，子代理保留之前的上下文，但只在同一个会话里有效，所以有第 8 条。

## 涉及文件

- `plugins/bb-spec-workflow/skills/prototype/SKILL.md` — 修改（重写正文）
- `tests/prototype-dispatch-rules.test.sh` — 新建
- `tests/ui-preview-rules.test.sh` — 修改（做法类断言改查子代理定义文件）
- `plugins/bb-spec-workflow/.claude-plugin/plugin.json` — 修改（description 里"5 个编排 subagent"改成"6 个"）
- `plugins/bb-spec-workflow/skills/revise/SKILL.md` — 修改（只改传给 `/prototype` 的原型文件名）
- `plugins/bb-spec-workflow/skills/prd/SKILL.md` — 修改（只改提到设计规范临时文件的几处）
- `tests/design-doc-rules.test.sh` — 修改（`/prd` 里临时文件名的断言）

`skills/exec/SKILL.md` 不改。

## 函数清单

本项目的产物是规程文本，这里列的是文件里的章节。

### plugins/bb-spec-workflow/skills/prototype/SKILL.md

frontmatter：`name`、`argument-hint`、`allowed-tools` 保持原样；`description` 保留现有各短语，在"界面原型的唯一规程——"后面加一句"出原型和对比都派原型子代理做，主对话只派工和传话"。

| 章节 | 职责 |
|---|---|
| 开头两段 | 说明本规程是调度；解释"外壳""框""原型子代理""派工说明" |
| `## 两种模式都先做` | 保持原文（取缓存目录、`.gitignore`） |
| `## 模式` | 保持原表 |
| `## 主对话做什么` | 业务规则 1、2 |
| `## 出原型` | 确定文件位置（原第 2 条原文）；写派工说明（业务规则 3）；派 `bb-spec-workflow:prototype-designer`；每轮怎么处理报告（业务规则 5、6、7）；发不到时怎么办（业务规则 8）；派不出去怎么办（业务规则 11） |
| `## 确认后` | 业务规则 9，三种调用方分别写 |
| `## 对比（--compare）` | 业务规则 4、10 |

原来的「设计规范（DESIGN.md）」「取证顺序」两节和「出原型」里填写外壳的细则、「对比」里的细则都删掉（已在子代理定义里）。

### plugins/bb-spec-workflow/skills/revise/SKILL.md

| 位置 | 改法 |
|---|---|
| 「界面预览」一段里的 `--file ${CACHE_DIR}/ui-preview/revise-<YYYY-MM-DD>-<主题>.html` | 改成 `--file ${CACHE_DIR}/ui-preview/<YYYY-MM-DD>.revise-<主题>.html`；其余不动 |

### plugins/bb-spec-workflow/skills/prd/SKILL.md

| 位置 | 改法 |
|---|---|
| 核心原则 1、步骤 8 自检第 1 条 | "它的 DESIGN.md 草稿"改成"它旁边的两个设计规范临时文件（`.DESIGN.draft.md`、`.DESIGN.md`）" |
| 步骤 6 | 搬预览页时，旁边同名的 `.DESIGN.draft.md`、`.DESIGN.md` 存在的都一起搬 |
| 步骤 7a | 预览页改名时，旁边同名的 `.DESIGN.draft.md`、`.DESIGN.md` 存在的都一起改名 |
| 步骤 7d | 改成：预览页旁边同名的 `<预览页名>.DESIGN.md` 存在（用户已同意的完整 DESIGN.md）→ 写到 DESIGN.md 的位置，写完删掉它；`<预览页名>.DESIGN.draft.md` 是用户还没同意的，不写入 |
| 步骤 9「需要修改」「不做了」两行 | "DESIGN.md 草稿"的说法改成两个临时文件都处理；「需要修改」里按 7d 再写入的条件改成"预览页旁边又有 `.DESIGN.md`" |

### tests/prototype-dispatch-rules.test.sh

| 函数名 | 职责 |
|---|---|
| `has` / `lacks` | 断言某个 skill 的 SKILL.md 含或不含某段固定文本（写法照 `tests/ui-preview-rules.test.sh`） |

### tests/ui-preview-rules.test.sh

| 函数名 | 职责 |
|---|---|
| `has_agent` / `lacks_agent` | 新增：断言 `plugins/bb-spec-workflow/agents/prototype-designer.md` 含或不含某段固定文本 |

## 协作关系

`/prd`、`/revise`、`/exec` 用 Skill 工具调用 `/prototype`（不变）→ `/prototype` 用 Agent 工具派 `bb-spec-workflow:prototype-designer` → 后续每轮用 SendMessage 发给同一个子代理。

## 验证方式

- 测试入口：`bash tests/prototype-dispatch-rules.test.sh`、`bash tests/ui-preview-rules.test.sh`、`bash tests/validate.sh`
- 测试输入：仓库里的 `plugins/bb-spec-workflow/skills/prototype/SKILL.md`、`agents/prototype-designer.md`、`skills/prd|revise|exec/SKILL.md`
- 预期结果：三个脚本都输出"失败 0"并以 0 退出

新测试按固定文本断言，SKILL.md 必须原样包含下面这些文本：

- [ ] 派谁：`bb-spec-workflow:prototype-designer`、`改动再小（只换一个按钮文字、一个颜色值）也派`
- [ ] 主对话边界：`不读项目源码`、`不读、不写、不改原型文件的内容`、`不写 DESIGN.md`
- [ ] 出原型派工说明：`必须写全 6 项`、`缺一项就先补齐再派`、`调用方是谁`、`需求结论`、`用户的原话照抄`、`DESIGN.md 应在的完整路径`、`草稿的完整路径`、`${CLAUDE_PLUGIN_ROOT}/templates`
- [ ] 对比派工说明：`必须写全 3 项`、`截图目录的完整路径`、`${CACHE_DIR}/ui-compare/<日期>.<主题>/`
- [ ] 转报告：`原样给用户看`、`待用户确认的问题`、`open <原型文件路径>`、`提醒用户刷新页面`
- [ ] 传话：`SendMessage`、`同一个原型子代理`、`不改写原话`
- [ ] 发不到：`新派一个原型子代理`、`原型文件已存在，接着改`
- [ ] 确认后：`用户已确认`、`确认内容清单`、`告诉用户原型文件路径`
- [ ] 对比：`每次新派一个原型子代理`、`原样交给调用方`
- [ ] 派不出去：`把报错原文告诉用户`、`不自己接手出原型`
- [ ] 保留：`| \`/prototype <主题>\` |`、`| \`<主题> --file <路径>\` |`、`| \`--compare <路径>\` |`、`scripts/bbspec-paths.sh`、`${CACHE_DIR}/ui-preview/<YYYY-MM-DD>.<主题>.html`、`明确说"可以"`、`不写 PRD`
- [ ] SKILL.md 不含 `PROTOTYPE-START`、`WCAG`、`取证顺序`、`terminalCss`（这些做法只在子代理定义里）
- [ ] `plugin.json` 的 description 含 `6 个编排 subagent`

`tests/ui-preview-rules.test.sh` 的改法：

- [ ] 这些小节的断言改成查子代理定义文件（文本不变）：「prototype 写明原型做法」里除 `--file`、`--compare`、`明确说"可以"`、`不写 PRD` 之外的各项；「prototype 的 DESIGN.md 位置与写入」「prototype 的 DESIGN.md 写法标准」「prototype 过一遍 DESIGN.md」「prototype 的取证顺序」「prototype 跑服务取底稿」「prototype 画什么」「prototype 终端原型」「prototype 不含与取证顺序矛盾的写法」「prototype 草稿写入、不想建时的退路、跑服务和对比的保护」「prototype 全文不含已删除的填写项和旧说明区」「prototype 规范外样式在对话里逐个列出」「prototype 多方案在对话里讲取舍」「prototype 主题按 DESIGN.md 颜色一节声明」「prototype 对比一节」
- [ ] 子代理定义里因"问用户改成写进报告""打开浏览器由主对话做"而变了的文本（如 `open <文件路径>`、`按第 8、9 步打开给用户看`、含"问用户""在对话里"的句子），对应断言改成子代理定义里的新写法；断言的意图不变
- [ ] 章节顺序类断言（DESIGN.md 两节在出原型之前、出原型第 1 条先过 DESIGN.md、取证顺序三条的先后）改成查子代理定义文件
- [ ] 「prototype 的 frontmatter」「prototype 正文的模式、取目录和文件位置」「prototype 给了文件时取缓存目录的写法和顺序」「prototype 的 description 写明先读 DESIGN.md 和取证」「prd、revise、exec 的调用写法和文件名」及之后各节保持查 SKILL.md，文本不变；其中 `文件已存在时直接改它`、`写了 \`css\` 后默认页面样式完全不生效`、对比细则几条改查子代理定义文件
- [ ] `revise` 的 SKILL.md 含 `--file ${CACHE_DIR}/ui-preview/<YYYY-MM-DD>.revise-<主题>.html`，不含 `revise-<YYYY-MM-DD>-<主题>`；`tests/ui-preview-rules.test.sh` 里断言旧文件名的那一条改成新文件名
- [ ] `prd` 的 SKILL.md：步骤 7d 一节含 `<预览页名>.DESIGN.md`、`写完删掉它`、`<预览页名>.DESIGN.draft.md`、`不写入`；步骤 6 一节和 7a 那一段都同时含 `.DESIGN.draft.md` 和 `.DESIGN.md`；「不做了」一行含 `设计规范临时文件`
- [ ] `tests/design-doc-rules.test.sh` 里「prd：步骤 6 搬草稿、7d、简报、不做了、步骤 10 提交清单」和 `prd-7a` 那条断言旧说法的地方，改成断言上一条的新文本；其余断言不动
- [ ] `/prototype` 规程含 `旁边有哪个临时文件就写哪个的路径`
- [ ] `exec` 的 SKILL.md 相对 main 没有改动（`git diff main -- plugins/bb-spec-workflow/skills/exec` 为空）
