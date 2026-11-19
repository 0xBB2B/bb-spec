---
name: homepage-wording
description: 介绍主页流水线区块改导语和 /plan 说明（中英），去掉 /prd 节点的小标签及其死样式
---
# 主页流水线区块文字

## 目标
主页流水线区块说清楚：PRD 批准需求；新技术先问；plan 新增或修改表结构、接口、数据格式、配置时再确认一次。`/prd` 节点不带小标签。

## 业务规则（来源：PRD public-wording）
- 导语和 `/plan` 节点说明改成下面「成品定义」里的中英文，逐字一致（用户在原型里确认过）。
- `/prd` 节点不带小标签（原「唯一一次批准」/「the only approval」），中英两种语言都没有。
- 其余文字、布局、样式、箭头、图例不变；安装表格里子插件名后面的标签（`.badge`）照旧。
- DESIGN.md 已在 PRD 阶段改好（流水线图一节不再描述节点标签），本 plan 不动 DESIGN.md。

## 涉及文件
- `site/index.html` — 修改
- `site/app.js` — 修改
- `site/style.css` — 修改（删掉只给节点内标签用的规则，节点里没有标签后它成了死代码）
- `tests/homepage.test.sh` — 修改（测试阶段处理）

## 成品定义

**site/index.html 第 40 行整行替换为：**

```html
    <p class="sec-lead" data-i18n="pipeLead">你读完 PRD 批准需求；要用新技术时先问你，plan 里新增或修改表结构、接口、数据格式、配置时再确认一次，其余自动跑完。/git-push 由你手动触发。</p>
```

**site/index.html 第 42 行整行替换为（删掉末尾的 `<span class="badge" data-i18n="once">…</span>`）：**

```html
      <div class="node"><code data-i18n="stages.0.0">/prd</code><span class="role" data-i18n="stages.0.1">做什么</span><p data-i18n="stages.0.2">质疑、澄清、拆解，落盘 PRD，请你读完确认。</p></div>
```

**site/index.html 第 44 行整行替换为：**

```html
      <div class="node"><code data-i18n="stages.1.0">/plan</code><span class="role" data-i18n="stages.1.1">怎么做</span><p data-i18n="stages.1.2">把 PRD 变成函数级实施计划。要用新技术时先问你；新增或修改表结构、接口、数据格式、配置时，列成清单请你确认。</p></div>
```

**site/app.js 中文字典：**

```js
    pipeLead: '你读完 PRD 批准需求；要用新技术时先问你，plan 里新增或修改表结构、接口、数据格式、配置时再确认一次，其余自动跑完。/git-push 由你手动触发。',
```

```js
      ['/plan', '怎么做', '把 PRD 变成函数级实施计划。要用新技术时先问你；新增或修改表结构、接口、数据格式、配置时，列成清单请你确认。'],
```

第 26 行改为（删掉 `once` 键）：

```js
    auto: '自动衔接', manual: '由你手动触发',
```

**site/app.js 英文字典：**

```js
    pipeLead: 'You read the PRD and approve the requirement. New tech is confirmed with you before the plan is written, and any new or changed table schema, API, data format or config is confirmed once the plan is done; everything else runs on its own. /git-push is triggered by you.',
```

```js
      ['/plan', 'how', 'Turns the PRD into a function-level plan. Asks before bringing in new tech, and lists any new or changed table schema, API, data format or config for you to confirm.'],
```

第 65 行改为（删掉 `once` 键）：

```js
    auto: 'chained automatically', manual: 'triggered by you',
```

**site/style.css：** 删除第 79 行 `.node .badge { margin-top: 8px; }`，第 78 行 `.badge { … }` 保留（安装表格在用）。

## 函数清单
无新增或改名的函数：只改 `site/app.js` 两份文案字典里的字符串和键，切换语言的逻辑不动。

## 协作关系
`site/app.js` 按 `data-i18n` 键把字典里的文字填进 `site/index.html`；删掉 `once` 键时 HTML 里引用它的元素一起删，两边一致。

## 验证方式
- 测试入口：`bash tests/homepage.test.sh`（用 node 加载 `site/index.html` 和 `site/app.js`，按 `PIECES` 表核对中英文文案）。
- 测试输入：仓库里的 `site/` 三个文件。
- 预期结果：
- [ ] `PIECES` 表里旧导语那条换成新导语（中英文和「成品定义」逐字一致），旧 `/plan` 说明那条换成新说明，`T('唯一一次批准', 'the only approval')` 那条删掉；静态中文页面和切到英文后都能找到新文字。
- [ ] 第 387 行页面顺序断言里的锚点 `'你读完 PRD 批准一次'` 换成 `'你读完 PRD 批准需求'`，顺序断言照常通过。
- [ ] 新增断言：`index.html` 里 `.node` 内没有 `.badge` 元素；`app.js` 中英文字典都没有 `once` 键；页面文字（中英）里搜不到「唯一一次批准」「the only approval」「批准一次」「approve once」「只有要引入新技术时才停下」「Stops only when new tech」。
- [ ] 新增断言：`site/style.css` 不含 `.node .badge`，仍含 `.badge {`。
- [ ] 测试里原有的中英字典结构一致性检查（两种语言键相同）照常通过。
