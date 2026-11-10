---
name: 02-top-switches
description: 外壳右上角按需显示方案和页面主题切换，1 个不显示、2～3 个平铺按钮、4 个及以上下拉菜单；框里页面带当前主题标记
---
# 右上角切换方案和页面主题

## 目标
原型填写区可以用 `themes` 声明被设计页面的几套配色，右上角按数量显示主题切换，框里页面跟着换主题；方案切换按同一套数量规则显示。

## 业务规则（来源：PRD 02-top-switches）
- `themes` 是数组，每项 `{ id, label }`，如 `{ id: 'dark', label: '☾ 暗黑' }`；不写等同于空数组。
- 方案组、主题组各自按数量显示：0 或 1 个 → 整组不显示（没有「方案」/「主题」两个字）；2～3 个 → 组名 + 平铺按钮，当前项是选中样式（`aria-pressed="true"`）；4 个及以上 → 组名 + 一个下拉菜单（`<select>`），选项按填写顺序列出全部项，收起时显示当前项。
- 方案项文字「<短名>：<特点>」（如「方案 A：表格」）；主题项文字等于 `label`。
- 两组都显示时右侧从左到右：「方案」组、一条细分隔线颜色（`#3a3d43`）的竖线、「主题」组；只有一组时没有竖线，这一组靠右。
- 左栏的页面、状态切换始终是平铺按钮，数量再多也不变成下拉菜单。
- 打开时当前主题是 `themes` 第一项，不看系统外观。
- 框里页面根元素带当前主题 id：`<html data-theme="<id>">`；网页页面和终端页面都带；没有声明主题时不带 `data-theme`。项目样式和 `terminalCss` 可按 `[data-theme="dark"]` 写不同颜色。
- 切换主题 → 框按新主题重新显示，方案、页面、状态、左栏选中项、外壳配色都不变。切换方案、页面、状态或框内 `data-go` 跳转 → 当前主题不变。
- 换方案（按钮或菜单）→ 框换成该方案的同一页面和状态，左栏选中项不变，左栏「当前：<短名>：<特点>」跟着变。
- `themes` 某项缺 `id` 或 `label`，或两项 `id` 相同 → 框里显示「原型填写有误」和出错项（缺字段时写第几项和缺什么，重复时写重复的 `id`）。
- 填写区注释要写清 `themes` 的格式、默认第一套、页面根元素上的 `data-theme` 怎么用（如 `[data-theme="dark"] body { background: #111; }`）。示例原型不加 `themes`（保持示例简单）。
- 外壳配色、本 plan 用到的样式沿用 01 号 plan 完成后的暗黑变量；下拉菜单样式：细线框用强调色、底色用外壳底色、字体继承。

## 涉及文件
- 修改 `plugins/bb-spec-workflow/templates/ui-preview-shell.html`
- 修改 `tests/ui-preview-shell.test.sh`

## 函数清单
### plugins/bb-spec-workflow/templates/ui-preview-shell.html
| 函数名 | 职责 |
|---|---|
| `pickButtons` | 保留：一组平铺按钮（左栏页面、状态，以及 2～3 个的方案、主题都用它） |
| `pickMenu` | 新建：一组下拉菜单，选中后回调对应项 |
| `pickSwitch` | 新建：按项数决定用 `pickButtons` 还是 `pickMenu`（≥ 4 用菜单） |
| `checkThemes` | 新建：加载时校验 `themes` 每项有 `id`、`label` 且 `id` 不重复，出错抛带原因的错误 |
| `frameDoc` | 修改：根元素按当前主题加 `data-theme` |
| `select` | 修改：当前选择增加主题，切换方案/页面/状态时保留当前主题 |
| `render` | 修改：方案组、主题组按数量显示或隐藏，调用 `pickSwitch` 填两组；分隔竖线只在两组都显示时出现 |

另需改动的非函数部分：
- HTML：框上方一行右侧在 `#schemeBar` 后面新增 `#themeBar`（含「主题」文字和 `#themePick`），默认 `hidden`
- `<style>`：`#themeBar` 的布局；方案组和主题组都显示时主题组左侧加竖线（`border-left: 1px solid var(--shell-line)` + 间距）；`.pick select` 的样式
- 填写区注释：新增 `themes` 说明

## 协作关系
`render` → `pickSwitch` → `pickButtons` / `pickMenu`；点击或菜单 `change` → `select` → `render` → `frameDoc`。`checkThemes` 在首次 `render` 前执行，抛错由外壳已有的错误监听显示「原型填写有误」。

## 验证方式
- 测试入口：`bash tests/ui-preview-shell.test.sh`（node `vm` + 假 DOM；假 DOM 需支持 `select`/`option` 元素、`value` 和 `change` 事件）
- 测试输入：方案数 1、3、4；主题数 0、1、2、4；主题缺 `id`、缺 `label`、`id` 重复；明暗两套且暗黑排第一；终端页面
- 预期结果：
- [ ] 方案 1 / 主题 0 或 1 → `#schemeBar`、`#themeBar` 都隐藏
- [ ] 3 个方案 + 2 套主题 → 两组都是按钮，方案按钮文字「方案 A：表格」格式，主题按钮文字等于 `label`；主题组带竖线
- [ ] 只有主题组显示时没有竖线
- [ ] 4 个方案 + 4 套主题 → 两组都是 `<select>`，选项顺序和填写一致，初始值为第一项
- [ ] 一个页面 5 个状态、4 个页面时，左栏 `#pagePick`、`#statePick` 仍是按钮
- [ ] 暗黑排第一、模拟浅色系统打开 → 当前主题是暗黑，框 srcdoc 根元素 `data-theme="dark"`
- [ ] 终端页面 srcdoc 同样带 `data-theme`；不声明主题时 srcdoc 不含 `data-theme`
- [ ] 在方案 B「订单列表 · 出错」切到暗黑 → srcdoc 变为暗黑标记，方案、页面、状态、左栏选中项不变
- [ ] 切到暗黑后切方案、页面、状态、`data-go` 跳转 → 仍是暗黑
- [ ] 4 个方案时菜单选方案 C → 框是方案 C 同一页面和状态，`#schemeCurrent` 为「当前：方案 C：紧凑列表」
- [ ] 主题缺 `label` / 缺 `id` / `id` 重复 → 框 srcdoc 含「原型填写有误」和出错项
