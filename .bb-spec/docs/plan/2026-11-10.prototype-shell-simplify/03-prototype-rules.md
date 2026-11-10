---
name: 03-prototype-rules
description: /prototype 规程改成在对话里讲说明、假的部分和未确认问题；主题套数按 DESIGN.md 决定；对比时示例数据不算差异
---
# 原型规程跟着调整

## 目标
`/prototype` 规程（`plugins/bb-spec-workflow/skills/prototype/SKILL.md`）和精简后的外壳一致：没有 `note`、`fake`、`openQuestions`，这些内容改在对话里讲；写清什么时候声明页面主题；对比规则不把示例数据当差异。

## 业务规则（来源：PRD 03-prototype-rules）
- 规程全文没有 `note`、`fake`、`openQuestions`。Claude 打开原型给用户看时，在同一条回复里讲：照着 DESIGN.md 哪几节、读了哪些源码文件、用了底稿时底稿来自哪个地址；哪些是假数据、假操作，以及没有能打开网页的工具、端口被占用、服务没跑起来等原因导致可能画得不准的部分；还没确认的问题。
- 原型用到 DESIGN.md 没有的颜色、字号、间距、圆角、阴影或组件样式 → 在对话里逐个列出问用户；同意写进 DESIGN.md 对应的一节，不同意就改用 DESIGN.md 里有的。用户不想建 DESIGN.md 那条里"规范外样式和源码补充只记在 openQuestions 里"改成"只在对话里说明"。
- 2 个及以上方案 → 在对话里讲每个方案的取舍，并问用户选哪个；方案填写项只有 `id`、`label`、`desc`。
- DESIGN.md「颜色」一节写了几套颜色，原型就在 `themes` 里声明几套，项目样式按每套主题写颜色（框里页面根元素带 `data-theme="<id>"`）；只写了一套不声明主题；用户要求看某套主题时照加。
- 对比（`--compare`）只比布局、文案、每种状态、每个交互操作后的结果；示例数据（订单号、人名、金额、数量、日期等）和真实界面不同不算不一致；外壳的左栏和框上方一行不参与对比；原型声明了多套主题时逐套对比。规程里搜不到「底部说明」「只在原型里成立」。
- frontmatter `description`：外壳写成"左栏切页面和状态、右上角按需切方案和页面主题、中间的框只放正式页面"，没有"明暗主题""底部放说明"。

## 涉及文件
- 修改 `plugins/bb-spec-workflow/skills/prototype/SKILL.md`
- 修改 `tests/ui-preview-rules.test.sh`

## 函数清单
无过程式代码。SKILL.md 需改的位置：
| 位置 | 改法 |
|---|---|
| frontmatter `description` | 按上面最后一条改外壳描述 |
| 「出原型前先过一遍 DESIGN.md」第 2 条 | `openQuestions` 改成在对话里说明 |
| 同上第 6 条 | 改成在对话里逐个列出问用户 |
| 「取证顺序」第 3 条、「跑服务」两处 | "`fake` 里写明…"改成"告诉用户…" |
| 「画什么」第 3 条 | "`note` 写明依据"改成打开原型时在对话里说明依据 |
| 「出原型」第 4 条 | 删掉"说明写进 note/fake/openQuestions"，改为说明在对话里讲（讲哪些见第一条规则） |
| 「出原型」第 6 条或新增一条 | 写页面主题套数规则 |
| 「出原型」第 7、8 条 | 多方案时在对话里讲取舍、问选哪个；打开原型时在同一条回复里讲说明 |
| 「对比（--compare）」 | 按对比规则改写 |

## 协作关系
`/prd`、`/revise` 调用本规程出原型，`/exec`、`/revise` 收尾用 `--compare`；它们只引用规程，不复述细节，本 plan 不改它们。

## 验证方式
- 测试入口：`bash tests/ui-preview-rules.test.sh`（按文字检查 SKILL.md）
- 测试输入：仓库里的 `plugins/bb-spec-workflow/skills/prototype/SKILL.md`
- 预期结果：
- [ ] 全文搜不到 `note`、`fake`、`openQuestions`、「底部说明」「只在原型里成立」「底部放说明」「明暗主题」
- [ ] 有"打开原型时在对话里讲依据（DESIGN.md 哪几节、源码文件、底稿地址）、假数据和假操作、未确认问题"的规定
- [ ] 有规范外样式在对话里逐个列出问用户及同意、不同意两种处理
- [ ] 有多方案时在对话里讲取舍并问选哪个；方案填写项只写 `id`、`label`、`desc`
- [ ] 有主题套数按 DESIGN.md「颜色」一节、一套时不声明、用户要求时照加，并提到 `themes` 和 `data-theme`
- [ ] 对比一节写明示例数据不同不算不一致、左栏和框上方一行不参与对比、多套主题逐套对比
- [ ] `description` 含"右上角按需切方案和页面主题"
- [ ] 其余已有检查（DESIGN.md 规则、取证顺序、跑服务保护、validate.sh 对外壳文件的检查）继续通过
