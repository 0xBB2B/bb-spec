---
name: 02-scheme-switch
description: 方案切换挪到框上方右侧、排在主题切换左边，左栏只切页面和状态并写明当前方案
---
# 方案切换挪到右上角

## 目标
有多个方案时，方案按钮在框上方一行的右侧，左栏只放页面和状态切换，并在最上面写明当前方案。

## 业务规则（来源：PRD 02-scheme-switch）
- 有 2 个及以上方案 → 框上方右侧显示「方案」两个字，后面每个方案一个按钮，文字是「<短名>：<特点>」（如「方案 A：表格」）；当前方案是选中样式；这组按钮排在明暗主题切换左边。
- 点方案按钮 → 框里换成这个方案的同一个页面和状态，左栏选中的页面和状态不变。
- 左栏从上到下：「设计说明 · 不属于页面」标签、原型标题和版本、页面和状态切换；有多个方案时切换区最上面显示「当前：<短名>：<特点>」，切换方案后跟着变。
- 只有 1 个方案 → 框上方没有「方案」和方案按钮，左栏没有「当前：…」。
- 框上方左边依次是「▼ 被设计的页面：只有这个框里的内容要实现」和「<页面名> · <状态名>」，始终完整显示；右侧按钮一行放不下时换到下一行，整组靠右。用户在原型里看过 7 个方案换行的样子并确认。
- 切换方案、页面、状态时底部说明高度不变；方案按钮行数不变时框高度也不变。
- 填写区出错时，方案按钮区和「当前：…」都隐藏（和现在出错时隐藏方案区一致）。

## 涉及文件
- `plugins/bb-spec-workflow/templates/ui-preview-shell.html` — 修改
- `tests/ui-preview-shell.test.sh` — 修改
- `plugins/bb-spec-workflow/skills/prototype/SKILL.md` — 修改（frontmatter `description`）

## 成品定义

左栏删除整个方案切换框（`#schemeBox`、`#schemeHint` 及 `.scheme`、`.scheme h2` 两条样式）。`.side-body` 的最前面加：

```html
      <p class="scheme-current" id="schemeCurrent" hidden></p>
```

框上方一行整段换成（`.theme` 那段是 01 加的主题按钮，原样保留在最后；`#frameScheme` 标签和 `.frame-right .tag` 样式删除）：

```html
    <div class="frame-bar">
      <div class="frame-left">
        <strong>▼ 被设计的页面：只有这个框里的内容要实现</strong>
        <span id="frameTitle"></span>
      </div>
      <div class="frame-right">
        <span id="schemeBar" hidden><span class="scheme-label">方案</span><span class="pick" id="schemePick"></span></span>
        <span class="theme" aria-label="外壳明暗">
          <button type="button" id="themeLight" aria-pressed="false">☀ 明亮</button>
          <button type="button" id="themeDark" aria-pressed="false">☾ 暗黑</button>
        </span>
      </div>
    </div>
```

对应样式（替换现有 `.frame-bar`、`.frame-bar strong`、`.frame-right`、`.frame-right .tag`、`#frameTitle` 规则）：

```css
  .frame-bar {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 16px;
    padding: 5px 2px 6px;
    font-size: 12px;
  }
  .frame-left { flex: none; display: flex; gap: 10px; padding-top: 5px; white-space: nowrap; }
  .frame-left strong { font-weight: 600; }
  #frameTitle { color: var(--shell-muted); }
  .frame-right { flex: 1; min-width: 0; display: flex; flex-wrap: wrap; justify-content: flex-end; align-items: center; gap: 4px; }
  #schemeBar, #schemePick { display: contents; }
  .scheme-label { margin-right: 2px; color: var(--shell-muted); }
  .scheme-current { margin: 0 0 10px; color: var(--accent); font-weight: 600; }
```

`SKILL.md` 的 `description` 里「用统一的蓝图外壳出 HTML 原型：左栏放切换、中间的框只放正式页面、底部放说明」改成：

```
用统一的蓝图外壳出 HTML 原型：左栏切页面和状态、右上角切方案和明暗主题、中间的框只放正式页面、底部放说明
```

## 函数清单
### plugins/bb-spec-workflow/templates/ui-preview-shell.html（外壳渲染脚本）
| 函数名 | 职责 |
|---|---|
| `render` | 修改：按方案数显示或隐藏 `#schemeBar`、`#schemeCurrent`，写入「当前：<方案名>」，在 `#schemePick` 里生成方案按钮；删掉对 `schemeBox`、`schemeHint`、`frameScheme` 的处理 |

## 协作关系
`render` 继续用现有的 `pickButtons` 生成方案按钮、用 `schemeName` 生成「<短名>：<特点>」，点击走现有的 `select` 保留当前页面和状态。`fitDock` 不用改，底部高度规则不变。主题脚本（01）不受影响。

## 验证方式
- 测试入口：`bash tests/ui-preview-shell.test.sh`（假 DOM + node `vm` 加载外壳 HTML）；`bash tests/validate.sh`；`bash tests/ui-preview-rules.test.sh`
- 测试输入：外壳自带的示例数据（2 个方案）、3 个方案、1 个方案、填写区语法错误四种数据；点 `#schemePick` 里的按钮、`#pagePick`、`#statePick` 里的按钮
- 预期结果：`#schemeBar`、`#schemeCurrent` 的显隐和文字，`#schemePick` 按钮的文字和 `aria-pressed`，`frameTitle`、`srcdoc` 符合下面各项
- [ ] 2 个方案加载 → `#schemeBar` 显示，`#schemePick` 有两个按钮「方案 A：表格」「方案 B：卡片」，A 的 `aria-pressed="true"`；`#schemeCurrent` 显示「当前：方案 A：表格」
- [ ] 在方案 A 的「订单列表 · 出错」点方案 B → `frameTitle` 仍是「订单列表 · 出错」，`srcdoc` 换成方案 B 的内容，`#schemeCurrent` 变成「当前：方案 B：卡片」，页面、状态按钮的选中项不变
- [ ] 3 个方案 → `#schemePick` 有 3 个按钮，切到方案 C 后 `#schemeCurrent` 是「当前：方案 C：列表」
- [ ] 1 个方案 → `#schemeBar`、`#schemeCurrent` 都隐藏
- [ ] 填写区语法错误 → `#schemeBar`、`#schemeCurrent` 都隐藏；HTML 里这两个元素的开始标签带 `hidden`
- [ ] HTML 里没有 `id="schemeBox"`、`id="schemeHint"`、`id="frameScheme"`；左栏里 `sideTitle`、`schemeCurrent`、`pagePick` 依次出现；框上方 `被设计的页面`、`frameTitle` 在 `.frame-left` 里，`schemeBar` 在 `.frame-right` 里且在 `themeLight` 之前
- [ ] 切换所有方案、页面、状态组合时底部高度不变（沿用现有底部高度测试）
- [ ] `.theme` 是 `.frame-right` 的最后一个子元素；窗口 960 宽、方案特点写 30 个汉字时，`#themeDark` 的右边缘不超出 `.frame-bar`（真浏览器里复核）
- [ ] `SKILL.md` 的 `description` 含「左栏切页面和状态、右上角切方案和明暗主题」
