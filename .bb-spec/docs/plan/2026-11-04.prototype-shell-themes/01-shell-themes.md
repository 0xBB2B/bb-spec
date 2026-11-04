---
name: 01-shell-themes
description: 外壳加明亮、暗黑两套配色和切换按钮，打开时跟系统外观一致，手动切过后以手动为准
---
# 外壳明暗主题

## 目标
原型外壳有明亮（雾灰蓝）和暗黑（石墨深灰）两套配色，打开时跟系统外观一致，框上方最右端可以手动切换，框里的页面不受影响。

## 业务规则（来源：PRD 01-shell-themes）
- 明亮主题：底色 `#d5dae1`，细分隔线 `#b7bfca`，正文字 `#1d2633`，次要文字 `#4f5b6b`，虚线和强调色 `#47607f`，网格线 `rgba(71,96,127,.06)`，选中按钮填充 `#c2cad5`、字 `#1d2633`。
- 暗黑主题：底色 `#26282c`，细分隔线 `#3a3d43`，正文字 `#d4d4d4`，次要文字 `#8f949b`，虚线和强调色 `#8e9aa8`，网格线 `rgba(255,255,255,.03)`，选中按钮填充 `#33363c`、字 `#e6e6e6`。
- 两种主题都保留细网格、等宽字体、方角、三处强调色虚线分界，「设计说明 · 不属于页面」标签是强调色虚线框、强调色字、无填充。
- 切换按钮未选中：细分隔线颜色的细线框、透明底；选中：强调色细线框 + 选中填充色 + 选中字色，字加粗。
- 框上方一行最右端是「☀ 明亮」「☾ 暗黑」，左边用一条细分隔线颜色的竖线和其他内容隔开；只有 1 个方案时也显示。
- 打开时系统浅色 → 明亮，系统深色 → 暗黑，对应按钮选中。
- 点按钮 → 立即换主题，当前方案、页面、状态、框里内容、框和底部高度都不变。
- 没点过按钮时系统外观变了 → 跟着换；点过之后 → 不跟。
- 重新打开 → 跟系统一致，不沿用上次手动选择（原型是双击打开的本地文件，往浏览器存设置在不同浏览器表现不一，用户确认不记）。
- 框里的页面（默认页面样式、项目样式、终端配色）两种主题下完全一样。
- 原型填写区写错、外壳报错时，主题照常按系统外观生效，按钮照常能切。

## 涉及文件
- `plugins/bb-spec-workflow/templates/ui-preview-shell.html` — 修改
- `tests/ui-preview-shell.test.sh` — 修改

## 成品定义

外壳 `<style>` 里的颜色变量整段替换成下面两块（`--accent-ink` 删除，用到它的地方改用 `--pick-text`）：

```css
  :root {
    --shell-bg: #d5dae1;
    --shell-line: #b7bfca;
    --shell-text: #1d2633;
    --shell-muted: #4f5b6b;
    --accent: #47607f;
    --pick-bg: #c2cad5;
    --pick-text: #1d2633;
    --grid: rgba(71, 96, 127, .06);
  }
  :root[data-theme="dark"] {
    --shell-bg: #26282c;
    --shell-line: #3a3d43;
    --shell-text: #d4d4d4;
    --shell-muted: #8f949b;
    --accent: #8e9aa8;
    --pick-bg: #33363c;
    --pick-text: #e6e6e6;
    --grid: rgba(255, 255, 255, .03);
  }
```

切换按钮样式（替换现有 `.pick button` 三条规则，让主题按钮共用同一套样式）：

```css
  .pick button, .theme button {
    padding: 5px 10px;
    border: 1px solid var(--shell-line);
    background: transparent;
    color: inherit;
    font: inherit;
    text-align: left;
    cursor: pointer;
  }
  .pick button:hover, .theme button:hover { border-color: var(--accent); }
  .pick button[aria-pressed="true"], .theme button[aria-pressed="true"] { border-color: var(--accent); background: var(--pick-bg); color: var(--pick-text); font-weight: 600; }
  .theme { display: flex; flex: none; gap: 4px; margin-left: 6px; padding-left: 10px; border-left: 1px solid var(--shell-line); }
```

主题按钮 HTML，放在 `.frame-right` 里的最后一个位置（`#frameTitle` 之后）：

```html
        <span class="theme" aria-label="外壳明暗">
          <button type="button" id="themeLight" aria-pressed="false">☀ 明亮</button>
          <button type="button" id="themeDark" aria-pressed="false">☾ 暗黑</button>
        </span>
```

主题脚本是一个独立的 `<script>`，放在错误监听脚本之后、填写区脚本之前，这样填写区出错时主题照样生效。主题状态只体现在 `<html>` 元素的 `data-theme` 属性上，取值 `light` 或 `dark`。

## 函数清单
### plugins/bb-spec-workflow/templates/ui-preview-shell.html（主题脚本）
| 函数名 | 职责 |
|---|---|
| `applyTheme` | 把 `<html>` 的 `data-theme` 设成给定主题，并更新两个主题按钮的 `aria-pressed` |
| `initTheme` | 读系统外观决定初始主题；监听系统外观变化，没手动切过时跟着换；给两个按钮绑定点击，点击后记下"已手动切换"并换主题；浏览器没有 `matchMedia` 时用明亮主题 |

## 协作关系
页面加载时主题脚本立即调用 `initTheme`，`initTheme` 和按钮点击、系统变化回调都通过 `applyTheme` 生效。主题脚本不读写填写区和外壳渲染脚本的任何变量，外壳渲染脚本也不碰主题；框是 `srcdoc` 生成的独立文档，外壳的 CSS 变量进不去。不用 `localStorage` 等任何浏览器存储。

## 验证方式
- 测试入口：`bash tests/ui-preview-shell.test.sh`（用假 DOM + node `vm` 加载外壳 HTML 运行全部脚本）
- 测试输入：假 `window.matchMedia('(prefers-color-scheme: dark)')` 返回 `{ matches, addEventListener('change', fn) }`，可切换 `matches` 并触发 `change`；点击 `#themeLight`、`#themeDark`；用默认示例数据、多方案数据、终端页面、填写区语法错误四种数据加载
- 预期结果：`<html>` 的 `data-theme` 和两个按钮的 `aria-pressed` 符合下面各项；CSS 文本里两块变量的值和成品定义一致
- [ ] `matches=false` 加载 → `data-theme="light"`，`#themeLight` 的 `aria-pressed="true"`、`#themeDark` 为 `"false"`
- [ ] `matches=true` 加载 → `data-theme="dark"`，`#themeDark` 选中
- [ ] 没点过按钮时 `matches` 改成 `true` 并触发 `change` → 变成 `dark`
- [ ] 点 `#themeLight` 后 `matches` 改变并触发 `change` → 保持 `light`
- [ ] 切到方案 B 某个状态后点 `#themeDark` → `frameTitle`、选中的方案/页面/状态按钮、框的 `srcdoc` 都和点之前完全相同
- [ ] 同一个网页画面、同一个终端画面在两种主题下 `srcdoc` 完全相同，且不含 `--shell-` 和 `--accent`
- [ ] 填写区有语法错误时加载 → `data-theme` 仍按 `matches` 设好，点按钮仍能切换
- [ ] 不提供 `matchMedia` 时加载 → `data-theme="light"`，不报错
- [ ] HTML 里不出现 `localStorage`、`sessionStorage`
- [ ] CSS 两块变量的 8 个值分别和成品定义一致；外壳 CSS 仍不含 `border-radius`；`#themeLight`、`#themeDark` 在 `.frame-right` 里且在 `#frameTitle` 之后
- [ ] `bash tests/validate.sh` 和 `bash tests/ui-preview-rules.test.sh` 照常通过
