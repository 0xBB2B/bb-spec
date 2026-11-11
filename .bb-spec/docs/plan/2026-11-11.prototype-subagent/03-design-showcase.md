---
name: 03-design-showcase
description: 新建或修改 DESIGN.md 时，原型子代理把规范画成原型里的「设计规范」展示页给用户确认；新增展示页固定部分的模板
---
# 设计规范展示页

## 目标

新建或修改 DESIGN.md 时，用户在原型里看到一页画出来的「设计规范」，说"可以"就算同意规范；对话里不出现规范全文。

## 业务规则（来源：PRD 02-design-spec-showcase）

"展示页"是原型左栏名叫「设计规范」的一页，把 DESIGN.md 的内容画出来。"设计规范草稿"是还没写进项目的 DESIGN.md 完整内容，存在原型文件旁边，文件名是原型文件名的 `.html` 换成 `.DESIGN.draft.md`。"不达标项"是不符合 DESIGN.md 写法标准的地方。

1. 三种情况先出展示页，用户确认展示页之后才出要设计的页面：项目没有 DESIGN.md 要新建；DESIGN.md 缺项或有不达标项要修改；原型要用 DESIGN.md 里没有的颜色、字号、间距、圆角、阴影或组件样式，要加进 DESIGN.md。
2. 展示页放在同一份原型里，是左栏的一页，名字叫「设计规范」。
3. 项目没有 DESIGN.md、也还没有界面代码时，设计 2 到 3 套风格，每套风格是一个方案，每个方案的「设计规范」页画这套风格；用户选定后删掉其余方案。
4. 图形界面项目的展示页从上到下依次是：标题「设计规范 · <项目名>」、摘要、颜色、字体与字号、间距、「圆角、边框、阴影」、组件、动效。
5. 摘要：新建且全部达标写一句"全部符合写法标准"；新建且有不达标项，写有几项不达标、逐条列出，并写明"哪一项不想改直接说，那一项按现状画并记进例外表"；修改已有规范，写这次要改几项、逐条列出。
6. 颜色：每种颜色画一个色块，色块下写用途名、色值、用在哪。文字色、边框色、成功色、警告色、错误色写出它对所在背景的对比度；主色写出按钮文字对它的对比度。对比度按 WCAG 相对亮度公式算出来。多套主题时在原型里声明多套，色块随右上角的主题切换变成对应那一套。
7. 字体与字号：写出字体；每一级字号一行，写名字、字号、行高、字重，并用这一级的样式写一行示例文字。
8. 间距：每个间距值一行，写数值，并画一条宽度等于这个值的色条。
9. 圆角、边框、阴影：每个圆角值、边框、每种阴影各画一个样例方块，写名字、数值、用在哪。
10. 组件：画一张状态对照表，列是默认、悬停、按下、禁用、聚焦，每个组件一行，把每种状态的样子静态画出来；「默认」一列的组件是真的，鼠标移上去、按下、用 Tab 键聚焦时会变成对应状态的样子；组件没有某种状态时那一格写"没有这个状态"；表格、弹窗、提示条另外各画一个完整样例；DESIGN.md 里写了"不适用"的组件不画。
11. 动效：每个动效时长画一个方块，写名字、时长和缓动、用在哪；鼠标移到方块上，方块按这个时长动一次。
12. 新建规范时现状有不达标项：展示页按建议改好的值画。每个不达标项在它所在的小节下面加一个对比框：2px 橙色（`#D97706`）虚线，框内第一行写这一项的名字和它属于哪套主题；左格带「现状 · 不达标」标签（底色 `#FDE68A`、文字 `#422006`），用现状的值画一个样例，写现状的值和原因，原因写出实际数值和要求的数值；右格带「建议 · 本页按这个画」标签（底色 `#BBF7D0`、文字 `#052E16`），用建议的值画同一个样例，写建议的值；左右两格的背景用这一项所属主题的卡片背景色，不随右上角的主题切换变化。
13. 用户说某个不达标项不改：这一项改回现状的值，去掉它的对比框，摘要里去掉这一条；写入的 DESIGN.md 在「无障碍」一节的例外表里记下这一项、实际值、确认日期。
14. 修改已有规范时：改动和新增的项在原本的位置带「本次修改」或「本次新增」标签（底色 `#C7D2FE`、文字 `#1E1B4B`）；每个改动或新增的项在所在小节下面加一个对比框：2px 紫色（`#6366F1`）虚线，左格带「改之前」标签，右格带「改之后」标签，各用对应的值画同一个样例并写出值；新增的项左格不画样例，写"规范里原来没有<这一项的名字>"；因不达标而修改的项用第 12 条的橙色对比框。
15. 对比框和标签的颜色固定，不随项目配色和主题变化。
16. 命令行项目的展示页是终端样式的页面，依次列出：颜色（「终端界面」一节的每种颜色一行，写色块、用途名、色值、对终端背景的对比度，再用这个颜色写一句示例）、符号（每个符号和含义）、表格（一个带表头的样例）、进度条（一个样例）。有不达标项或修改项时，在这些内容下面逐项列出：一行「现状 · 不达标」或「改之前」，一行「建议」或「改之后」，各带色块、色值、示例和对比度。
17. 展示页不画「布局与断点」和「无障碍」两节。
18. 对话里不贴 DESIGN.md 或设计规范草稿的全文。用户要看原文时，告诉用户草稿的完整路径。
19. 展示页出来之前，设计规范草稿先存到原型文件旁边。用户对展示页提意见时，草稿和展示页一起改，两边的值保持一致。
20. 用户对展示页明确说"可以"，就是同意了这份规范：被 `/prd` 调用时，草稿留在原型文件旁边，由 `/prd` 落盘 PRD 时写入项目；被 `/revise` 调用或用户直接运行时，把草稿写成项目的 DESIGN.md，删掉草稿。
21. 用户确认展示页后，「设计规范」一页从原型里删掉，然后出要设计的页面。
22. 用户说这次不想建 DESIGN.md：删掉「设计规范」一页，按草稿出这一次的原型，不写入项目；这次的原型确认后删掉草稿。

决策理由：用户不读 Markdown 全文，只看画出来的样子；标记颜色固定，是为了不管项目用什么配色都认得出来。

## 涉及文件

- `plugins/bb-spec-workflow/templates/design-showcase.js` — 新建（成品见下）
- `plugins/bb-spec-workflow/agents/prototype-designer.md` — 修改
- `plugins/bb-spec-workflow/skills/prototype/SKILL.md` — 修改
- `tests/design-showcase-rules.test.sh` — 新建
- `tests/ui-preview-rules.test.sh`、`tests/prototype-agent-rules.test.sh` — 修改（被本 plan 改掉的旧文本对应的断言）

## 成品定义

`plugins/bb-spec-workflow/templates/design-showcase.js`，原样落盘：

```js
/* 设计规范展示页的固定部分。
   用法：把本文件全文复制到原型填写区 PROTOTYPE-START 那段说明的下面，再写项目自己的内容。
   - 项目样式 css 的末尾拼上 DS_CSS；终端页的 terminalCss 末尾拼上 DS_TERMINAL_CSS。
   - 项目样式里要按每套主题定义这 6 个变量，DS_CSS 靠它们跟着主题变：
     --ds-surface 卡片背景色、--ds-divider 分隔线色、--ds-text 正文文字色、
     --ds-text-2 次要文字色、--ds-border 控件边框色、--ds-accent 主色。
   - 对比框和标签的颜色是固定的，不要改。 */

// 按 WCAG 相对亮度公式算两个 #RRGGBB 颜色的对比度，返回保留一位小数的字符串
const dsLum = (hex) => {
  const c = [1, 3, 5]
    .map((i) => parseInt(hex.slice(i, i + 2), 16) / 255)
    .map((x) => (x <= 0.04045 ? x / 12.92 : ((x + 0.055) / 1.055) ** 2.4));
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
};
const dsContrast = (a, b) => ((Math.max(dsLum(a), dsLum(b)) + 0.05) / (Math.min(dsLum(a), dsLum(b)) + 0.05)).toFixed(1);

// 标签。kind：bad 现状不达标、good 建议或改之后、old 改之前、chg 本次修改或本次新增
const dsTag = (kind, text) => `<span class="ds-tag ds-tag-${kind}">${text}</span>`;

// 对比框。kind：bad 不达标（橙色虚线）、chg 本次修改或新增（紫色虚线）
// title：这一项的名字和所属主题；before、after：左右两格里的样例 HTML
// side：这一项所属主题的颜色，两格固定用它，不随右上角切换
const dsPair = (kind, title, before, after, side = { bg: '#FFFFFF', fg: '#0F172A', sub: '#475569', line: '#E2E8F0' }) => {
  const st = `background:${side.bg};color:${side.fg};border-color:${side.line};--ds-side-sub:${side.sub}`;
  return `<div class="ds-pair ds-pair-${kind}">
  <div class="ds-pair-title">${title}</div>
  <div class="ds-side" style="${st}">${dsTag(kind === 'bad' ? 'bad' : 'old', kind === 'bad' ? '现状 · 不达标' : '改之前')}${before}</div>
  <div class="ds-arrow">→</div>
  <div class="ds-side" style="${st}">${dsTag('good', kind === 'bad' ? '建议 · 本页按这个画' : '改之后')}${after}</div>
</div>`;
};
// 对比框里写值和原因的那一行
const dsWhy = (text) => `<p class="ds-why">${text}</p>`;

const DS_CSS = `
.ds-page{max-width:1040px;margin:0 auto;padding:24px}
.ds-summary{margin-top:16px;padding:12px 16px;border-radius:8px;background:var(--ds-surface);border:1px solid var(--ds-divider)}
.ds-summary-bad{border:2px dashed #D97706}
.ds-summary-chg{border:2px dashed #6366F1}
.ds-summary p{margin:0}.ds-summary ol{margin:8px 0;padding-left:24px}
.ds-sec{margin-top:32px}
.ds-note{margin:0 0 12px;color:var(--ds-text-2);font-size:12px;line-height:20px}
.ds-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(184px,1fr));gap:12px}
.ds-swatch{background:var(--ds-surface);border:1px solid var(--ds-divider);border-radius:8px;overflow:hidden}
.ds-chip{height:56px;border-bottom:1px solid var(--ds-divider)}
.ds-meta{padding:8px 12px}
.ds-meta code,.ds-meta span,.ds-box-wrap code,.ds-box-wrap span{display:block;color:var(--ds-text-2);font-size:12px;line-height:20px}
.ds-rows{display:grid;gap:8px}
.ds-row{display:grid;grid-template-columns:160px 1fr;align-items:center;gap:12px}
.ds-label{color:var(--ds-text-2);font-size:12px;line-height:20px}.ds-label small{display:block;font-size:12px}
.ds-bar{display:block;height:16px;background:var(--ds-accent);border-radius:4px}
.ds-box-wrap strong{display:block;margin-top:8px}
.ds-box{height:64px;background:var(--ds-surface);border:1px solid var(--ds-border)}
.ds-move{transition-property:transform,background-color;transition-timing-function:ease-out}
.ds-move:hover{transform:translateX(24px);background:var(--ds-accent)}
.ds-states{display:grid;grid-template-columns:96px repeat(5,minmax(0,1fr));gap:16px 12px;align-items:center}
.ds-th{color:var(--ds-text-2);font-size:12px;line-height:20px;font-weight:600}
.ds-none{color:var(--ds-text-2);font-size:12px;line-height:20px}
.ds-mask{background:rgba(15,23,42,.48);border-radius:8px;padding:32px;display:flex;justify-content:center}
.ds-stack{display:grid;gap:8px}
.ds-tag{display:inline-block;font:600 12px/20px system-ui,sans-serif;padding:0 8px;border-radius:4px;vertical-align:middle}
.ds-tag-bad{background:#FDE68A;color:#422006}
.ds-tag-good{background:#BBF7D0;color:#052E16}
.ds-tag-old{background:#E2E8F0;color:#0F172A}
.ds-tag-chg{background:#C7D2FE;color:#1E1B4B}
.ds-pair{display:grid;grid-template-columns:1fr 24px 1fr;gap:12px;align-items:stretch;border-radius:8px;padding:12px;margin-top:12px}
.ds-pair-bad{border:2px dashed #D97706}
.ds-pair-chg{border:2px dashed #6366F1}
.ds-pair-title{grid-column:1/-1;font-weight:600}
.ds-pair-title .ds-tag{margin-left:8px}
.ds-arrow{align-self:center;text-align:center;color:var(--ds-text-2)}
.ds-side{border:1px solid;border-radius:8px;padding:12px}
.ds-side>.ds-tag{margin-bottom:12px}
.ds-side p{margin:0 0 4px}
.ds-side code{display:block;color:var(--ds-side-sub);margin-top:8px}
.ds-side .ds-why,.ds-side .ds-none{color:var(--ds-side-sub);font-size:12px;line-height:20px;margin:4px 0 0}
`;

// 终端展示页里的标签：<span class="ds-t-bad"> 现状 · 不达标 </span> 这样用
const DS_TERMINAL_CSS = `
.ds-t-bad{background:#FDE68A;color:#422006}
.ds-t-good{background:#BBF7D0;color:#052E16}
.ds-t-old{background:#E2E8F0;color:#0F172A}
.ds-t-chg{background:#C7D2FE;color:#1E1B4B}
`;
```

## 函数清单

规程文本列的是章节。

### plugins/bb-spec-workflow/agents/prototype-designer.md

| 章节 | 职责 |
|---|---|
| `## 设计规范（DESIGN.md）` 里「出原型前先过一遍 DESIGN.md」各条 | 改写：起草或修改时先把完整草稿存到原型文件旁边（规则 19），再出展示页（规则 1、3）；"风格样张"的说法都换成展示页；规范外样式按"本次新增"出展示页；不想建时按规则 22 |
| `## 设计规范（DESIGN.md）` 里关于草稿和写入的那一段 | 改写成规则 19、20；删掉"还没确认的草稿只贴在对话里""草稿只留在对话里" |
| `## 设计规范展示页`（新增，放在「设计规范（DESIGN.md）」之后、「取证顺序」之前） | 规则 2、4～17、21；写明先把 `{templates_dir}/design-showcase.js` 全文复制进填写区，用 `dsContrast` 算对比度、用 `dsPair` 和 `dsTag` 画对比框和标签，项目样式里定义 6 个 `--ds-*` 变量 |
| `## 每轮报告` | 加一句：出了展示页时，「这一轮改了什么」写明展示页有几项不达标或几项修改；报告里给出草稿的完整路径（规则 18） |

### plugins/bb-spec-workflow/skills/prototype/SKILL.md

| 章节 | 职责 |
|---|---|
| `## 出原型` | 加：子代理先出「设计规范」展示页时，主对话请用户看展示页；对话里不贴 DESIGN.md 或草稿全文，用户要看原文时告诉用户草稿的完整路径（规则 18）；用户对展示页说"可以"后转告子代理，子代理删掉展示页再出要设计的页面（规则 20、21） |
| frontmatter `description` | "没有就起草、不达标就先补齐，都经用户确认"后面加"新建和修改都画成展示页给用户看" |

### tests/design-showcase-rules.test.sh

| 函数名 | 职责 |
|---|---|
| `has_agent` / `has_skill` / `has_tpl` | 断言子代理定义、`/prototype` 规程、展示页模板含某段固定文本 |
| `lacks_agent` | 断言子代理定义不含某段固定文本 |

## 协作关系

原型子代理出展示页时复制 `design-showcase.js` 进原型填写区；外壳 `ui-preview-shell.html` 不改。`/prd` 步骤 7d 照旧把原型文件旁边的 `.DESIGN.draft.md` 写入项目（不改）。

## 验证方式

- 测试入口：`bash tests/design-showcase-rules.test.sh`；回归跑 `bash tests/ui-preview-rules.test.sh`、`bash tests/prototype-agent-rules.test.sh`、`bash tests/prototype-dispatch-rules.test.sh`、`bash tests/design-doc-rules.test.sh`、`bash tests/validate.sh`
- 测试输入：仓库里的子代理定义、`/prototype` 规程、`templates/design-showcase.js`
- 预期结果：各脚本输出"失败 0"并以 0 退出

模板文件：

- [ ] `node --check plugins/bb-spec-workflow/templates/design-showcase.js` 通过（没有 node 时跳过这一项并打印说明）
- [ ] 含 `dsContrast`、`dsTag`、`dsPair`、`dsWhy`、`DS_CSS`、`DS_TERMINAL_CSS`
- [ ] 含固定颜色 `#D97706`、`#6366F1`、`#FDE68A`、`#422006`、`#BBF7D0`、`#052E16`、`#C7D2FE`、`#1E1B4B`
- [ ] 含标签文字 `现状 · 不达标`、`建议 · 本页按这个画`、`改之前`、`改之后`
- [ ] 有 node 时：`dsContrast('#94A3B8', '#FFFFFF')` 得 `2.6`，`dsContrast('#475569', '#FFFFFF')` 得 `7.6`

子代理定义必须原样包含：

- [ ] `## 设计规范展示页`，且这一节在 `## 设计规范（DESIGN.md）` 之后、`## 取证顺序` 之前
- [ ] `{templates_dir}/design-showcase.js`、`dsContrast`、`dsPair`、`dsTag`、`--ds-surface`
- [ ] 时机：`用户确认展示页之后才出要设计的页面`、`要新建`、`要修改`、`要加进 DESIGN.md`
- [ ] 位置：`名字叫「设计规范」`、`每套风格是一个方案`
- [ ] 结构：`标题「设计规范 · <项目名>」、摘要、颜色、字体与字号、间距、「圆角、边框、阴影」、组件、动效`
- [ ] 摘要：`全部符合写法标准`、`哪一项不想改直接说`、`这次要改几项`
- [ ] 颜色：`用途名、色值、用在哪`、`按钮文字对它的对比度`、`随右上角的主题切换`
- [ ] 字号、间距、圆角：`名字、字号、行高、字重`、`宽度等于这个值的色条`、`样例方块`
- [ ] 组件：`默认、悬停、按下、禁用、聚焦`、`「默认」一列的组件是真的`、`没有这个状态`、`表格、弹窗、提示条另外各画一个完整样例`
- [ ] 动效：`按这个时长动一次`
- [ ] 不达标：`按建议改好的值画`、`现状 · 不达标`、`建议 · 本页按这个画`、`实际数值和要求的数值`、`所属主题的卡片背景色`、`不随右上角的主题切换变化`
- [ ] 不改某项：`改回现状的值`、`去掉它的对比框`、`例外表`
- [ ] 修改：`本次修改`、`本次新增`、`改之前`、`改之后`、`规范里原来没有`
- [ ] 固定：`不随项目配色和主题变化`
- [ ] 命令行：`颜色、符号、表格、进度条`、`对终端背景的对比度`、`DS_TERMINAL_CSS`
- [ ] 不画：`不画「布局与断点」和「无障碍」两节`
- [ ] 草稿与写入：`草稿先存到原型文件旁边`、`草稿和展示页一起改`、`由 \`/prd\` 落盘 PRD 时写入项目`、`把草稿写成项目的 DESIGN.md，删掉草稿`、`「设计规范」一页从原型里删掉`、`这次的原型确认后删掉草稿`
- [ ] 不含 `风格样张`、`还没确认的草稿只贴在对话里`、`草稿只留在对话里`

`/prototype` 规程必须原样包含：

- [ ] `「设计规范」展示页`、`不贴 DESIGN.md 或草稿全文`、`告诉用户草稿的完整路径`、`新建和修改都画成展示页给用户看`

旧测试的改法：

- [ ] `tests/ui-preview-rules.test.sh`、`tests/prototype-agent-rules.test.sh` 里断言 `风格样张`、`还没确认的草稿只贴在对话里`、`草稿只留在对话里`、`删掉其余方案和风格样张页`、`每套风格画一页风格样张`、`逐个列出` 这类被本 plan 改掉的文本的地方，改成断言上面的新文本或删掉；其余断言不动
