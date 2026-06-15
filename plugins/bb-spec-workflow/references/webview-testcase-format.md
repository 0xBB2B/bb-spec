# Webview 测试用例格式（规范）

`/plan`（生成用例）、`/test-webview`（兜底生成 + 派发）、`webview-test-runner` agent（执行）三方共用的**单一事实源**。改格式只改本文件，三方自动对齐。

## 用例文档骨架

每个用例一个 md，落盘到 `${DOCS_DIR}/test/webview/<类别>/<用例>.md`：

```markdown
---
name: <kebab-case>
description: <一句话>
category: <category>
---
# <测试名称>
## 简介
<这个用例测什么交互场景>
## 测试目的
<验证哪条业务行为 / 验收点>
## 测试流程（固定 JSON，subagent 原样消费）
```json
{
  "id": "login-success",
  "category": "auth",
  "target": "admin-frontend",
  "dependsOn": ["register-success"],   // 可选；无依赖则省略。上游失败则本用例 skipped
  "setup":  [],
  "steps": [
    { "action": "navigate", "target": "/login" },
    { "action": "fill", "selector": "input[name=email]", "value": "user@example.com" },
    { "action": "fill", "selector": "input[name=password]", "value": "secret" },
    { "action": "click", "selector": "button[type=submit]" },
    { "action": "waitFor", "text": "Dashboard" },
    { "action": "assertUrl", "contains": "/dashboard" },
    { "action": "assertVisible", "selector": ".user-menu" },
    { "action": "screenshot", "name": "after-login" }
  ],
  "teardown": []
}
```
## 如何验收
- [ ] <验收项>
```

## JSON 流字段约定

- `id`：用例唯一标识（kebab-case，与文件名一致）。
- `category`：功能领域，与所在子文件夹一致。
- `target`：打哪个前端服务（对应 `test/webview/INDEX.md` frontmatter `env.frontends` 的服务名）；**单前端项目可省**。
- **无 `baseUrl` 字段**：运行时由 Docker 拉起后 `target` 前端的 published port 注入；仅当某步要访问外部 / 跨源地址时，才在该 step 里写绝对 URL。
- `setup` / `teardown`：可选的前置 / 清理步骤，结构同 `steps`。
- `steps`：借鉴 workflow 的**声明式步骤序列**——一串可被独立执行的步骤，subagent 顺序执行、**断言失败即停**。
- `dependsOn`：可选，前置用例的 `id` 列表（可跨类别）。声明"本用例依赖这些用例先成功"。**无此字段 = 独立用例**。详见下方「执行顺序与依赖」。

## 执行顺序与依赖

UI 测试的"先后顺序"分两个层级，分别由两种机制承载：

- **用例内（强顺序）**：`setup → steps → teardown` 严格按序执行、**断言失败即停**、不跳步。**有紧耦合 UI 连续操作（如"填表 → 提交 → 校验跳转"）应写成同一个用例里的有序 steps**——同一 subagent、同一浏览器上下文，天然共享登录态与中间数据。
- **用例间（依赖 + 跳过）**：默认用例**自包含、互相独立**，各自 `setup` 建立前置；执行按依赖拓扑序串行（`dependsOn` 的用例先跑，无依赖关系按 INDEX 顺序）。失败策略：
  - **有依赖**：上游用例 `fail` / `error` / 被跳过 → 下游用例**不运行**、标 `skipped`，并**级联**到其传递依赖者（依赖已失败用例的结果不可信，跑了也是假阳/假阴）。
  - **无依赖**：某用例失败**不影响**其它独立用例，继续跑完全部，最后汇总。
  - 依赖成环属编写错误：检测到环 → 环内用例全标 `skipped` 并在报告点名。

> 跨用例依赖只解决"**要不要跑**"（上游挂了下游别跑）；它依赖的是后端 / DB 等**持久应用状态**（整轮测试结束才 `down -v`，期间不清理，故上游写入的数据下游可见）。浏览器会话态（登录等）不保证跨用例延续，下游若需要应在自己的 `setup` 里重建——真正紧耦合的会话连续操作请合并成单个用例的有序 steps。

## 抽象 action 词表

仅定义语义（与具体浏览器 MCP 无关，便于跨 playwright / chrome-devtools 复用）；各 action 到 MCP 工具的执行映射见 `agents/webview-test-runner.md`。

| action | 语义 |
|---|---|
| `navigate` | 跳转到 `target`（相对路径基于注入的 baseUrl） |
| `click` | 点击 `selector` 命中的元素 |
| `fill` | 向 `selector` 输入框填 `value` |
| `fillForm` | 一次性批量填多个字段 |
| `hover` | 悬停 `selector` |
| `press` | 按下某个键（`key`） |
| `select` | 在下拉框 `selector` 选 `value` |
| `waitFor` | 等待元素 / 文本 / 网络空闲出现（`selector` 或 `text`） |
| `assertVisible` | 断言 `selector` 元素可见 |
| `assertText` | 断言页面 / 元素含 `text` |
| `assertUrl` | 断言当前 URL `contains` 给定片段 |
| `assertConsoleNoError` | 断言执行至此无 console error |
| `screenshot` | 截图，命名 `name`（取证 / 留档） |
| `evaluate` | 执行脚本片段做自定义断言 |
