# DESIGN.md

> bb-spec 产品介绍主页（GitHub Pages 站点）的设计规范，风格是深色终端风。出原型、写界面代码、审查界面代码都以它为准；新建和修改都要经用户同意后才写入。
>
> 写法要求：
> - 每项写具体数值和单位（px、ms 等）。
> - 颜色按用途命名，每个颜色写色值。
> - 间距和圆角的每个值都是 4 的倍数（0 也算）；全圆角写 9999px。
> - 颜色对比度符合 WCAG 2.2 AA：正文文字对背景至少 4.5:1；大号文字、图标、输入框和按钮的边框对相邻背景至少 3:1。对比度按相对亮度公式算。
> - 项目用不上的一节写"不适用：<原因>"。

## 1. 风格定位

给天天待在终端里的开发者，感觉像在看一个终端窗口。

- 全站只用等宽字体，正文 14px/24px
- 深色底 #0D1117，主色是 Claude Code 徽章的橙色 #D97757
- 安装命令放在带三个圆点标题栏的终端窗口里，命令前有橙色 ❯ 提示符

## 2. 颜色

只有一套深色配色，所以"浅色"一列不适用。"来源"一列写明每个色值从哪来："自定"是这份规范自己定的，没有外部出处。

| 用途 | 名字 | 浅色 | 深色 | 对比度（对哪个背景） | 来源 |
|---|---|---|---|---|---|
| 主色（主按钮、提示符、小标题、"自动衔接"箭头） | primary | 不适用：只有一套深色配色 | #D97757 | 对 background 6.1:1，对 surface 5.5:1 | README.md 第 20 行"Claude Code Plugin"徽章的颜色，原值照用 |
| 主色上的文字 | on-primary | 不适用：只有一套深色配色 | #0D1117 | 对 primary 6.1:1 | 和 background 同一个色 |
| 主按钮悬停 | primary-hover | 不适用：只有一套深色配色 | #E1937A | on-primary 对它 7.8:1 | 按 primary 推导：色相 14.8°、饱和度 63.1% 不变，亮度从 59.6% 调到 68% |
| 主按钮按下 | primary-active | 不适用：只有一套深色配色 | #D25D37 | on-primary 对它 4.8:1 | 按 primary 推导：色相、饱和度不变，亮度调到 52% |
| 页面背景 | background | 不适用：只有一套深色配色 | #0D1117 | — | 自定 |
| 面板、终端窗口、顶栏、页脚背景 | surface | 不适用：只有一套深色配色 | #161B22 | — | 自定 |
| 正文文字；"由你手动触发"箭头 | text | 不适用：只有一套深色配色 | #E6EDF3 | 对 background 16.0:1，对 surface 14.6:1 | 自定 |
| 次要文字 | text-muted | 不适用：只有一套深色配色 | #9198A1 | 对 background 6.5:1，对 surface 5.9:1 | 自定 |
| 分隔线（装饰线，不承载信息） | border | 不适用：只有一套深色配色 | #30363D | 对 background 1.6:1 | 自定 |
| 按钮、控件边框 | border-strong | 不适用：只有一套深色配色 | #6E7681 | 对 background 4.1:1，对 surface 3.8:1 | 自定 |
| 成功（预留，主页没用到） | success | 不适用：只有一套深色配色 | #3FB950 | 对 background 7.4:1 | 自定 |
| 警告（预留，主页没用到） | warning | 不适用：只有一套深色配色 | #D29922 | 对 background 7.5:1 | 自定 |
| 错误（预留，主页没用到） | danger | 不适用：只有一套深色配色 | #F85149 | 对 background 5.6:1 | 自定 |
| 信息；命令名、链接 | info | 不适用：只有一套深色配色 | #58A6FF | 对 background 7.5:1，对 surface 6.8:1 | 自定 |
| 聚焦描边 | focus | 不适用：只有一套深色配色 | #58A6FF | 对 background 7.5:1 | 自定 |

## 3. 字体与字号

- 字体：`ui-monospace, "SF Mono", Menlo, Consolas, "PingFang SC", monospace`
- 等宽字体：`ui-monospace, "SF Mono", Menlo, Consolas, "PingFang SC", monospace`

| 用途 | 字号 | 行高 | 字重 |
|---|---|---|---|
| 页面标题 | 32px（手机 22px） | 44px（手机 32px） | 700 |
| 区块标题 | 20px | 28px | 700 |
| 正文 | 14px | 24px | 400 |
| 导语 | 16px（手机 14px） | 28px（手机 24px） | 400 |
| 辅助文字 | 12px | 20px | 400 |
| 代码 | 14px | 28px | 400 |

## 4. 间距

- 尺度：0、4、8、12、16、24、32、48、64、96 px
- 页面外边距：左右 24px（手机 16px），内容区上 64px（手机 32px）、下 96px（手机 64px）
- 卡片内边距：面板和终端窗口 16px，流水线节点 12px
- 表单项之间：不适用：介绍页是静态页面，没有表单
- 按钮内边距：0 16px
- 区块间距：区块之间 96px（手机 64px）

## 5. 圆角、边框、阴影

| 项 | 值 |
|---|---|
| 小圆角（按钮、面板、节点、标签、语言切换） | 4px |
| 中圆角（终端窗口） | 8px |
| 大圆角（弹窗） | 不适用：没有弹窗 |
| 全圆角（窗口标题栏圆点） | 9999px |
| 边框宽度 | 1px |
| 卡片阴影 | 终端窗口 0 16px 48px rgba(0, 0, 0, .5)；面板无阴影 |
| 弹窗阴影 | 不适用：没有弹窗 |

## 6. 布局与断点

- 断点：页面宽度 640px 及以下是手机布局；960px 及以下流水线从横排改成竖排
- 页面最大宽度：1048px（加左右内边距共 1096px）
- 栅格："解决什么"三列，列间距 16px；流水线 5 个节点横排，节点之间留 48px 画箭头

| 部分 | 位置和尺寸 | 写法（HTML 结构和类名） | 不同断点下怎么变 |
|---|---|---|---|
| 顶栏 | 贴顶固定，高 48px，背景 surface，底部 1px border | `<header class="top"><div class="top-in">…</div></header>` | 手机：左右内边距 16px，间距 12px |
| 侧边栏 | 不适用：单页介绍站 |  |  |
| 导航 | 顶栏右侧，每个链接两边带方括号，间距 16px，颜色 text-muted | `<nav class="nav"><a class="in" href="#problem">…</a>…</nav>` | 手机：隐藏带 `in` 类的页内链接 |
| 页面标题区 | 注释行 → 带 > 提示符和闪烁光标的 h1 → 导语 → 两个按钮 → 终端窗口 | `<p class="comment">`、`<h1><span class="p">&gt;</span>…<span class="cursor"></span></h1>`、`<p class="lead">`、`<div class="cta">`、`<div class="win">` | 手机：h1 22px/32px |
| 内容区 | 三个区块，标题前带橙色 ## | `<main class="main"><section class="sec" id="…"><h2><span class="h">##</span> …</h2>…</section></main>` | 手机：三列改一列 |
| 页脚 | 背景 surface，顶部 1px border，上下内边距 12px，12px/20px | `<footer class="foot"><div class="foot-in">…</div></footer>` | 自动换行 |

页面框架写法：整页结构是 `<header class="top">`、`<main>`、`<footer class="foot">` 依次排，各部分的标签和类名见上表"写法"一列。

## 7. 组件

### 按钮

- 写法：主按钮 `<a class="btn btn-primary" href="…">安装</a>`；次按钮 `<a class="btn" href="…">在 GitHub 上查看</a>`
- 高度：40px
- 内边距：0 16px
- 圆角 4px，文字 700 14px/24px，1px 边框

| 状态 | 主按钮 | 次按钮 |
|---|---|---|
| 默认 | 背景和边框 primary，文字 on-primary | 透明底，边框 border-strong，文字 text |
| 悬停 | 背景 primary-hover，120ms ease-out | 边框 text、背景 surface |
| 按下 | 背景 primary-active | 背景 border |
| 禁用 | 背景 surface，边框 border，文字 text-muted，鼠标指针 not-allowed | 同主按钮 |
| 聚焦 | 2px focus 色描边，离按钮 2px | 同主按钮 |

### 语言切换

- 写法：`<div class="lang" role="group"><button class="lang-btn" aria-pressed="true">中文</button><button class="lang-btn" aria-pressed="false">English</button></div>`
- 样子：外框 1px border-strong、圆角 4px；每个按钮高 32px、内边距 0 12px、12px/20px；选中：背景 primary、文字 on-primary、700；未选中：透明底、文字 text-muted；悬停：文字 text、背景 border；按下：背景 background；聚焦：2px focus 色描边；禁用：没有这个状态

### 代码块

- 写法和样子：终端窗口 `<div class="win"><div class="win-bar"><i></i><i></i><i></i><span>claude</span><button class="copy">复制</button></div><pre><span class="p">❯</span> …</pre></div>`：背景 surface，1px border，圆角 8px，阴影见第 5 节；提示符颜色 primary；复制按钮高 32px、1px border-strong、圆角 4px，悬停边框 text，按下背景 border

### 流水线图

- 写法和样子：`.pipe` 里 5 个 `.node`（背景 surface，1px border-strong，圆角 4px，内边距 12px；命令颜色 info，角色颜色 primary，说明 12px/20px text-muted）；节点之间 `.conn`：自动衔接是 primary 色双线箭头，手动触发是 text 色虚线箭头；下面有图例
- 页面宽度 960px 及以下：节点改成一列，箭头换成一行文字"↓ 自动衔接"或"↓ 由你手动触发"，颜色不变

### 输入框

不适用：介绍页是静态页面，没有表单

### 表格

- 写法：`<table><thead><tr><th>…</th></tr></thead><tbody><tr><td><code>bb-spec-core</code> <span class="badge">推荐基座</span></td><td>…</td></tr></tbody></table>`
- 样子：表头文字 text-muted；单元格内边距 8px 16px，行底 1px border；子插件名颜色 info、700；悬停行背景 surface；手机上隐藏表头，每行上下堆叠
- 子插件名后面的标签 `<span class="badge">`：1px primary 边框、primary 文字、圆角 4px、内边距 0 8px、12px/20px；全站只有这里用标签
- 按下、禁用、聚焦：没有这个状态（行不可点击）

### 卡片

面板 `<article class="pane"><h3><span>01</span> 标题</h3><p>…</p></article>`：背景 surface，1px border，圆角 4px；标题栏内边距 8px 16px、文字 primary、底部 1px border；正文内边距 16px。静态，没有悬停、按下、禁用、聚焦状态

### 弹窗

不适用：介绍页没有弹窗

### 提示条

不适用：介绍页没有提示条

## 8. 动效

| 项 | 时长 | 缓动 |
|---|---|---|
| 悬停、按下反馈 | 120ms | ease-out |
| 光标闪烁 | 1000ms 一个周期 | steps(1)，无限循环 |
| 展开、收起 | 不适用：没有可展开内容 |  |
| 弹窗出现、消失 | 不适用：没有弹窗 |  |

- 用户系统设置了"减少动态效果"时：所有过渡时长变成 0ms，动画停掉，页内跳转不做平滑滚动

## 9. 无障碍

- 聚焦：所有可操作元素聚焦时显示 focus 色描边，宽度：2px，离元素 2px
- 点击区域：至少 24×24 px（最小的可点元素是 32px 高的语言切换和复制按钮）
- 颜色不是唯一的信息来源：流水线里"自动衔接"和"由你手动触发"除了颜色不同，线型也不同（双线和虚线），并且配有文字
- 表单：不适用：介绍页是静态页面，没有表单
- 语言切换用 `aria-pressed` 标出当前语言；页面根元素按当前语言设 `lang`

例外：

| 项 | 实际值 | 用户确认日期 |
|---|---|---|

## 10. 终端界面

不适用：这份规范管的是 GitHub Pages 介绍站；bb-spec 插件本身没有自己的命令行输出程序
