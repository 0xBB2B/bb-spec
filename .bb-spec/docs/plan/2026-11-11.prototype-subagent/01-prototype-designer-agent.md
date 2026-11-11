---
name: 01-prototype-designer-agent
description: 新增原型子代理定义文件，承接出原型和对比的全部做法，并写明报告格式、要等用户答复的事、确认内容清单、可写范围
---
# 新增原型子代理

## 目标

插件里多一个原型子代理 `prototype-designer`：拿到派工说明就能独立出原型或做界面对比，每轮交回固定格式的简短报告。

## 业务规则（来源：PRD 01-prototype-subagent）

"子代理"是主对话派出去单独干活的另一个 Claude，看不到主对话，只拿到派工说明。

1. 子代理定义里模型写 `fable`。
2. 出原型和对比的具体做法（读 DESIGN.md、DESIGN.md 写法标准、取证顺序、跑服务取底稿、画什么、终端界面、填写外壳、对比细则）由子代理执行。现在这些做法写在 `plugins/bb-spec-workflow/skills/prototype/SKILL.md` 的「设计规范（DESIGN.md）」「取证顺序」「出原型」「对比（--compare）」四节，本 plan 把它们原文搬进子代理定义，只做下面第 3～9 条要求的改写。
3. 子代理每轮交回的报告只有 5 部分，没有内容的部分写"无"：这一轮改了什么；依据（用到了 DESIGN.md 的哪几节、读了哪些源码文件、底稿来自哪个地址）；哪些是假数据和假操作；哪些部分可能不准以及原因；待用户确认的问题。报告里不贴 HTML，不贴源码原文，不贴 DESIGN.md 全文。
4. 子代理不能直接问用户。下面这些事，遇到时停下、写进报告的「待用户确认的问题」，拿到主对话转来的用户答复之后才做对应的动作：新建 DESIGN.md、修改 DESIGN.md；不达标项按不按建议改；原型用到 DESIGN.md 里没有的样式加不加进 DESIGN.md；多套风格、多个方案选哪个；要不要把项目跑起来；要运行的完整命令（连同出处）；端口被占用时用不用现有的服务。
5. 原有做法里"问用户""请用户确认""用户同意"的地方，全部改成"写进报告的「待用户确认的问题」，拿到答复后再做"；原有"用 `open` 打开给用户看""在对话里讲"的地方，改成"写进报告"（打开浏览器由主对话做）。
6. 派工说明写着"原型文件已存在，接着改"时：先读已有的原型文件和 DESIGN.md（有草稿读草稿），只改用户提到的地方，其他内容保持原样。
7. 收到"用户已确认"后，交回一份确认内容清单：按页面逐页写出布局、每处文案、每种状态下用户看到什么、每个交互操作后发生什么；原型有多套主题时写出各主题的差异。清单只写框里的内容，不写外壳。
8. 对比模式交回的结果是这三种之一：一致；不一致（逐条写原型里是什么、实际是什么，附截图路径）；没跑起来（写清卡在哪）。
9. 子代理只写这几处：原型文件、原型文件旁边同名的设计规范草稿（`.DESIGN.draft.md`）、截图目录；用户同意后才写 DESIGN.md。不改产品代码，不操作 git。

决策理由：出原型一次让主对话多出 4.9 万到 24.6 万 token，确认后没有用处，所以整个过程放到子代理里。

## 涉及文件

- `plugins/bb-spec-workflow/agents/prototype-designer.md` — 新建
- `tests/prototype-agent-rules.test.sh` — 新建

本 plan 不动 `skills/prototype/SKILL.md`（下一份 plan 改）。

## 函数清单

本项目的产物是规程文本，这里列的是文件里的章节。

### plugins/bb-spec-workflow/agents/prototype-designer.md

frontmatter 字段：`name: prototype-designer`、`description`、`role: 原型设计者`、`agent-type: general-purpose`、`model: fable`、`inputs`（`mode`、`topic`、`prototype_file`、`caller`、`requirement`、`design_md_path`、`design_draft_path`、`templates_dir`、`screenshots_dir`、`resume_note`，每项带一句注释；格式照同目录 `webview-test-runner.md`）。

| 章节 | 职责 |
|---|---|
| `# Prototype Designer Agent` 开头一段 | 说明身份：出原型、做对比；不能直接问用户；不改产品代码 |
| `## 输入` | 用 `{mode}` 等占位符逐项列出派工说明的内容；说明外壳模板是 `{templates_dir}/ui-preview-shell.html`、DESIGN.md 模板是 `{templates_dir}/DESIGN.md` |
| `## 要等用户答复的事` | 业务规则 4 的清单和"拿到答复后才做" |
| `## 设计规范（DESIGN.md）` | 从 SKILL.md 同名一节原文搬来，按业务规则 5 改写；模板路径改用 `{templates_dir}` |
| `## 取证顺序` | 从 SKILL.md 同名一节原文搬来（含跑服务、画什么、终端界面），按业务规则 5 改写 |
| `## 出原型` | 从 SKILL.md 同名一节搬来：填写外壳的各条规则保留；第 8 条改成"交回报告"；第 9 条改成"收到用户意见就改，再交回报告"；加上业务规则 6 |
| `## 对比` | 从 SKILL.md「对比（--compare）」一节搬来，按业务规则 5、8 改写 |
| `## 每轮报告` | 业务规则 3 的 5 部分和三个"不贴" |
| `## 确认内容清单` | 业务规则 7 |
| `## 安全基线` | 业务规则 9；格式照同目录其他子代理的同名一节 |

### tests/prototype-agent-rules.test.sh

| 函数名 | 职责 |
|---|---|
| `has` / `lacks` | 断言子代理定义文件含或不含某段固定文本（写法照 `tests/ui-preview-rules.test.sh`） |
| `fm_line` | 取 frontmatter 里某个字段所在的行 |

## 协作关系

子代理定义文件被 `/prototype` 用 Agent 工具按 `bb-spec-workflow:prototype-designer` 派出（下一份 plan 接上）。`tests/validate.sh` 会自动检查 `agents/*.md` 的 frontmatter 必填字段（`name`、`description`、`agent-type`、`inputs`）、`name` 与文件名一致、`agent-type` 在允许列表、有 `## 安全基线` 一节。

## 验证方式

- 测试入口：`bash tests/prototype-agent-rules.test.sh`，以及 `bash tests/validate.sh`
- 测试输入：仓库里的 `plugins/bb-spec-workflow/agents/prototype-designer.md`
- 预期结果：脚本末尾输出"通过 N，失败 0"并以 0 退出；文件缺失或缺任何一段文本时以非 0 退出并打印 `FAIL:` 行

测试按固定文本断言，实现必须原样包含下面这些文本：

- [ ] frontmatter 有 `name: prototype-designer`、`model: fable`、`agent-type: general-purpose`，`inputs` 下有 `mode`、`topic`、`prototype_file`、`caller`、`requirement`、`design_md_path`、`design_draft_path`、`templates_dir`、`screenshots_dir`、`resume_note`
- [ ] 报告：`这一轮改了什么`、`依据`、`假数据和假操作`、`可能不准`、`待用户确认的问题`、`没有内容的部分写"无"`、`不贴 HTML`、`不贴源码原文`、`不贴 DESIGN.md 全文`
- [ ] 等答复：`拿到主对话转来的用户答复之后才做`、`新建 DESIGN.md`、`修改 DESIGN.md`、`不达标项`、`加不加进 DESIGN.md`、`选哪个`、`要不要把项目跑起来`、`完整命令`、`用不用现有的服务`
- [ ] 接着改：`原型文件已存在，接着改`、`只改用户提到的地方`、`其他内容保持原样`
- [ ] 确认内容清单：`确认内容清单`、`每种状态下用户看到什么`、`每个交互操作后发生什么`、`各主题的差异`、`不写外壳`
- [ ] 对比结果：`- 一致`、`- 不一致：`、`- 没跑起来：`、`附截图路径`
- [ ] 可写范围：`.DESIGN.draft.md`、`不改产品代码`、`不操作 git`
- [ ] 搬来的做法：`tests/ui-preview-rules.test.sh` 里下面这几个小节断言的每一段文本，子代理定义文件里同样都有——「prototype 的 DESIGN.md 写法标准」「prototype 的取证顺序」「prototype 跑服务取底稿」「prototype 画什么」「prototype 终端原型」。另外含 `PROTOTYPE-START`、`PROTOTYPE-END`、`外壳一律不改`、`框里禁止放说明或切换控件`、`{templates_dir}/ui-preview-shell.html`、`{templates_dir}/DESIGN.md`
- [ ] 不含 `AskUserQuestion`，不含 `open <文件路径>`，不含 `${CLAUDE_PLUGIN_ROOT}`
- [ ] `bash tests/validate.sh` 通过
