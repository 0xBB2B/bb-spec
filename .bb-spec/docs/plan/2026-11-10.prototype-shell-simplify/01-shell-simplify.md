---
name: 01-shell-simplify
description: 外壳模板固定暗黑配色、删掉底部说明区和外壳明暗切换，填写格式去掉 note/fake/openQuestions 和方案 note
---
# 外壳精简

## 目标
原型外壳只有一套暗黑配色，没有底部说明区，框占满左栏右边除框上方一行外的全部高度；填写格式里只剩外壳会显示的填写项。

## 业务规则（来源：PRD 01-shell-simplify）
- 外壳只有一套配色：底色 `#26282c`，细分隔线 `#3a3d43`，正文字 `#d4d4d4`，次要文字 `#8f949b`，虚线和强调色 `#8e9aa8`，网格线 `rgba(255,255,255,.03)`，选中按钮填充 `#33363c`、字 `#e6e6e6`。系统是浅色还是深色、打开后系统外观怎么变，外壳都不变（去掉 `matchMedia` 跟随和明暗按钮）。
- 外壳由左栏、框上方一行、框三块组成，框下面没有说明区；`main` 的下内边距 6px 保留，窗口高 900 时框（iframe）下边缘在 894px。
- 外壳上不出现「这个画面的说明」「只在原型里成立」「还没确认的问题」「这一块上线后不存在」；左栏顶部「设计说明 · 不属于页面」标签和「第 N 版 · 这一栏上线后不存在」保留。
- 填写区说明里没有 `note`、`fake`、`openQuestions`；方案填写项只有 `id`、`label`、`desc`。方案数 ≥ 2 且某方案缺 `desc` → 框里显示「原型填写有误」和该方案的 `label`（错误文案示例：`方案 B 缺少 desc`）。
- 填写区仍写了 `note`、`fake`、`openQuestions` 或方案 `note`（任意类型，如字符串、对象）→ 原型照常显示，外壳上不显示这些内容，不触发「原型填写有误」。
- 外壳模板自带的示例原型（订单导出示例）去掉这四个填写项，其余页面、状态、方案、终端示例保留。
- 外壳右上角在本 plan 完成后只剩方案切换（现有平铺按钮行为不变）；页面主题切换由 02 号 plan 加在同一位置，本 plan 先删掉 `.theme` 明暗按钮及其样式。

## 涉及文件
- 修改 `plugins/bb-spec-workflow/templates/ui-preview-shell.html`
- 修改 `tests/ui-preview-shell.test.sh`

## 函数清单
### plugins/bb-spec-workflow/templates/ui-preview-shell.html
| 函数名 | 职责 |
|---|---|
| `applyTheme` | 删除：外壳明暗切换 |
| `initTheme` | 删除：外壳跟随系统外观、绑定明暗按钮 |
| `fillList` | 删除：只给底部说明区填列表 |
| `fillNotes` | 删除：底部说明区三栏内容 |
| `chooseSchemeQuestion` | 删除：只给「还没确认的问题」自动加"选哪个方案" |
| `fitDock` | 删除：底部说明区高度计算，连同 `resize` 监听 |
| `requireList`（内联箭头函数） | 删除：note/fake/openQuestions 必须是数组的校验 |
| 方案校验（`incomplete` 一段） | 修改：多方案时只检查 `desc`，错误文案改为「<label> 缺少 desc」 |
| `render` | 修改：去掉对 `fillNotes` 的调用，其余行为不变 |

另需改动的非函数部分：
- `<style>`：`:root` 直接写暗黑那套变量，删掉 `:root[data-theme="dark"]` 块、`.dock*` 样式、`.theme` 样式；`main` 的 `grid-template-rows` 从三行改两行（`auto minmax(0, 1fr)`）
- HTML：删掉 `<section class="dock">` 整块和 `.theme` 明暗按钮 `<span>`
- 填写区注释：删掉 `openQuestions`、方案 `note`、页面 `fake`、状态 `note` 的说明，以及 "note、fake、openQuestions 都是数组" 一句；示例数据删掉对应字段

## 协作关系
`render` 由方案、页面、状态切换和框内 `data-go` 消息触发，只更新左栏、框上方一行、框。外壳不再依赖 `window.matchMedia`。

## 验证方式
- 测试入口：`bash tests/ui-preview-shell.test.sh`（node `vm` + 假 DOM 加载外壳 HTML，按需替换填写区数据）
- 测试输入：模板自带示例数据；自定义数据（1 个方案 / 2 个方案缺 `desc` / 写了字符串 `note`、对象 `fake`、方案 `note` 的旧写法）；模拟 `matchMedia` 浅色、深色及打开后切换
- 预期结果：
- [ ] 外壳 CSS 里只有一套颜色变量，值等于上面 8 个色值；文件里没有 `prefers-color-scheme`、`data-theme="dark"` 的外壳样式块
- [ ] 模拟浅色、深色外观加载后，根元素不带外壳主题标记、外壳样式不变；触发系统外观变化后不变
- [ ] HTML 里没有 id 为 `dock`、`noteList`、`fakeList`、`openList`、`themeLight`、`themeDark` 的元素；`main` 只有两行网格
- [ ] 模板里搜不到「这个画面的说明」「只在原型里成立」「还没确认的问题」「这一块上线后不存在」；能搜到「设计说明 · 不属于页面」「这一栏上线后不存在」
- [ ] 2 个方案其中一个缺 `desc` → 框里 srcdoc 含「原型填写有误」和该方案 `label`；方案只缺 `note` → 正常显示
- [ ] 旧写法字段（字符串 `note`、对象 `fake`、方案 `note`、`openQuestions`）→ 正常显示，框里不是错误提示
- [ ] 填写区说明和示例数据里搜不到 `note`、`fake`、`openQuestions`
- [ ] 原有方案切换、页面状态切换、`data-go`、终端页面、错误提示、框内隔离测试继续通过；只测底部说明区和外壳明暗的测试分组删除
