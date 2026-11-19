---
name: public-wording
description: README、主页、插件描述和 /prd 弹窗说明改成"PRD 批准需求；新技术先问；技术变更再确认一次"
date: 2026-11-19
---

# 对外说明跟上新行为

## 用户故事
### P0：作为第一次了解 bb-spec 的人，我想要从介绍里知道什么时候需要我确认，以便不会被中途的弹窗意外打断

**用例（主路径）**
- 场景：用户打开介绍主页的流水线区块。
- 操作：读导语和 `/plan` 节点说明，切换到 English 再读一遍。
- 预期：中英文都说明了三件事：读完 PRD 批准需求；要用新技术时先问；plan 新增或修改表结构、接口、数据格式、配置时再确认一次。`/prd` 节点上没有"唯一一次批准"小标签。

**用例（/prd 弹窗）**
- 场景：用户在 `/prd` 最后一步看到确认弹窗。
- 操作：读「已阅读，通过并执行」的说明。
- 预期：说明里写清楚后面哪些时候还会停下来问。

## 约束
1. 介绍主页 `site/index.html` 流水线区块导语：
   - 中：「你读完 PRD 批准需求；要用新技术时先问你，plan 里新增或修改表结构、接口、数据格式、配置时再确认一次，其余自动跑完。/git-push 由你手动触发。」
   - 英：「You read the PRD and approve the requirement. New tech is confirmed with you before the plan is written, and any new or changed table schema, API, data format or config is confirmed once the plan is done; everything else runs on its own. /git-push is triggered by you.」
2. 主页 `/plan` 节点说明：
   - 中：「把 PRD 变成函数级实施计划。要用新技术时先问你；新增或修改表结构、接口、数据格式、配置时，列成清单请你确认。」
   - 英：「Turns the PRD into a function-level plan. Asks before bringing in new tech, and lists any new or changed table schema, API, data format or config for you to confirm.」
3. 主页 `/prd` 节点不带小标签（原「唯一一次批准」/「the only approval」），中英两种语言都没有；其余文字、布局、样式、箭头、图例不变。
4. 项目根 DESIGN.md 第 7 节「组件」：「流水线图」里没有关于第一个节点小标签的那一行；「表格」里有一行「子插件名后面的标签 `<span class="badge">`：1px primary 边框、primary 文字、圆角 4px、内边距 0 8px、12px/20px；全站只有这里用标签」。
5. `/prd` 确认弹窗「已阅读，通过并执行」的说明：「提交 PRD，然后自动跑 /plan → /exec → /doc-update；要引入新技术时先问你，plan 里新增或修改表结构、接口、数据格式、配置时再请你确认一次，遇到设计判断时也会停下问你」。弹窗问题、另外两个选项和各选项的后续行为不变。
6. 五份 README（简体、繁体、英、日、韩）里介绍 `/prd`、`/plan` 和流水线图的地方，都写成"PRD 批准需求；新技术先问；plan 有表结构、接口、数据格式、配置的新增或修改时再确认一次，其余自动跑完"，五份内容一致。
7. marketplace 和 plugin.json 的插件描述用和约束 6 一致的说法概括 `/prd` 和 `/plan`：用户批准需求；新技术、技术变更先请用户确认。
8. 在插件文件（`plugins/`）、五份 README、`site/`、DESIGN.md、marketplace 和 plugin.json 的描述里搜「只批准一次」「只批准这一次」「唯一一次批准」「一次批准」「批准一次」「approve once」「the only approval」「只有要引入新技术时才停下」「只在需要引入新技术时停下」「Stops only when new tech」及其他三种语言 README 里的同义说法，均无命中（已合并的 PRD 不在搜索范围内）。

## 验收
- [ ] 主页导语中英文和约束 1 一致。
- [ ] 主页 `/plan` 节点说明中英文和约束 2 一致。
- [ ] 主页 `/prd` 节点中英文都没有小标签，其余不变（约束 3）。
- [ ] DESIGN.md 两处改动和约束 4 一致。
- [ ] `/prd` 弹窗选项 1 说明和约束 5 一致，其余不变。
- [ ] 五份 README 相关段落说法一致并符合约束 6。
- [ ] marketplace 和 plugin.json 描述符合约束 7。
- [ ] 约束 8 列出的旧说法在指定范围内搜不到。

## 验证路径
1. 打开 `site/index.html`，看流水线区块导语、`/plan` 说明、`/prd` 节点；切换 English 再看一遍 → 和约束 1~3 一致。
2. 读 DESIGN.md 第 7 节「流水线图」「表格」→ 和约束 4 一致。
3. 走一遍 `/prd` 到最后一步 → 弹窗选项 1 说明和约束 5 一致。
4. 对比五份 README 的 `/prd`、`/plan` 介绍和流水线图 → 说法一致。
5. 按约束 8 的范围和词表搜索 → 无命中。
