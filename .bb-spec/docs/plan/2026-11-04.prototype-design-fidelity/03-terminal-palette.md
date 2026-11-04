---
name: 03-terminal-palette
description: 外壳允许单个终端页面用 terminalCss 指定项目自己的终端样式，没指定时用外壳默认终端配色
---
# 终端页面可用项目配色

## 目标
原型填写区里，终端页面可以写 `terminalCss` 指定项目自己的终端样式；写了就替换外壳默认终端样式，没写或只有空白就用默认样式，只影响这一页。

## 业务规则（来源：PRD 02-prototype-fidelity）
- 原型可以给终端页面指定项目自己的配色；指定了 → 框里的终端用项目配色；没指定 → 用外壳默认终端配色。
- 指定配色不影响同一份原型里的其他页面（其他终端页面、普通页面）。
- 外壳默认终端配色只在项目没有命令行输出代码时使用（规程层面的要求，由 /prototype 规程承担；外壳只提供能力）。

## 涉及文件
- `plugins/bb-spec-workflow/templates/ui-preview-shell.html` — 修改
- `tests/ui-preview-shell.test.sh` — 修改（测试）

## 成品定义

填写区说明（`PROTOTYPE-START` 注释）里 `terminal` 那一段换成：

```
     terminal：终端界面写 true。这时 html 写终端里的文字，<pre> 外面包好了，不用再写。
       终端文字里的 < 和 & 要写成 &lt; 和 &amp;，否则会被当成标签吞掉。
     terminalCss：终端页面的样式，照项目实际输出的颜色写，比如
       'body { background: #1e1e1e; } pre { color: #d4d4d4; } .ok { color: #4ec9b0; }'，
       html 里用 <span class="ok">…</span> 上色。只对这一页生效。
       不写时用外壳默认终端配色，颜色用 <span class="g">绿</span>、<span class="y">黄</span>、
       <span class="b">蓝</span>、<span class="r">红</span>；默认配色只在项目没有命令行输出代码时用。
```

同一段注释里 `css` 的说明（从「css：项目有自己的设计时」到「终端页面固定用外壳自带的样式。」共 4 行）整段换成：

```
   css：页面样式，照项目根目录 DESIGN.md 和项目现有样式写，写了之后默认页面样式完全不生效。
     不写时框里用默认页面样式，可以直接用的元素有
     header、h1、main、.card、table、button、button.plain、.center、.alert、.bar、dl、.cards。
     终端页面用 terminalCss，不用 css。
```

## 函数清单
### plugins/bb-spec-workflow/templates/ui-preview-shell.html（外壳渲染脚本）
| 函数名 | 职责 |
|---|---|
| `frameDoc` | 修改：终端页面的样式改为"这一页的 `terminalCss` 去掉首尾空白后非空就用它，否则用外壳默认终端样式"；普通页面的样式选择不变 |

## 协作关系
`frameDoc` 被 `render` 调用生成框的 `srcdoc`；终端页面仍然把 html 包进 `<pre>`，并附上现有的框内跳转脚本。外壳默认终端样式常量保留不变。

## 验证方式
- 测试入口：`bash tests/ui-preview-shell.test.sh`（假 DOM + node `vm` 加载外壳，沿用现有 `load`/`mk`/`srcdoc()`/`pick` 写法）
- 测试输入：一份原型含 3 个页面：终端页 A 写 `terminalCss: 'body{background:#123456} .ok{color:#abcdef}'`，终端页 B 不写 `terminalCss`，普通页 C 写了项目 `css`；另测 `terminalCss` 为空字符串、只有空白
- 预期结果：
- [ ] 切到终端页 A → `srcdoc` 含 `#123456` 和 `.ok{color:#abcdef}`，不含外壳默认终端底色 `#0b1730`，也不含项目 `css` 的标记
- [ ] 切到终端页 B → `srcdoc` 含默认终端样式（`#0b1730`、`.g { color: #7ee7c1; }`），不含 `#123456`
- [ ] 切到普通页 C → `srcdoc` 含项目 `css`，不含 `#123456` 和 `#0b1730`
- [ ] `terminalCss` 为 `''` 或 `'   '` → 用默认终端样式
- [ ] 终端页 A 的 html 仍然包在 `<pre>` 里，框内 `data-go` 跳转仍可用
- [ ] 两种主题下终端页 A 的 `srcdoc` 相同（框里的页面不随外壳主题变化）
- [ ] 填写区说明里含 `terminalCss`、`只对这一页生效`、`默认配色只在项目没有命令行输出代码时用`；`css` 说明含「照项目根目录 DESIGN.md 和项目现有样式写」「终端页面用 terminalCss，不用 css。」；外壳全文不含「项目没有自己的设计时不写这一项」「终端页面固定用外壳自带的样式」
- [ ] 现有外壳测试全部仍通过
