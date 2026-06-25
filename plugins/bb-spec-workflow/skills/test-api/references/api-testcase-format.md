# API e2e 测试用例格式（规范）

`/test-api`（生成用例 + 编译执行）共用的**单一事实源**。改格式只改本文件。

## 用例文档骨架

每个用例一个 md，落盘到 `${DOCS_DIR}/test/api/<scope>/<category>/<用例>.md`（`<scope>` = INDEX `env.backends` 服务名，顶层永远按 scope 分，即便只有一个后端）：

```markdown
---
name: <kebab-case>
description: <一句话>
category: <category>
---
# <测试名称>
## 简介
<这个用例测什么业务流>
## 测试目的
<验证哪条业务行为 / 时间敏感规则>
## 测试流程（固定 JSON，代码生成器原样消费）
```json
{
  "id": "token-expiry-after-5min",
  "category": "auth",
  "scope": "api",
  "dependsOn": ["login-success"],
  "setup":  [],
  "steps": [
    { "action": "request", "method": "POST", "path": "/login",
      "body": { "email": "u@example.com", "password": "secret" } },
    { "action": "expect", "status": 200,
      "jsonPath": { "$.token": { "exists": true } } },
    { "action": "extract", "jsonPath": { "token": "$.token" } },

    { "action": "advanceTime", "duration": "5m1s" },

    { "action": "request", "method": "GET", "path": "/api/me",
      "headers": { "Authorization": "Bearer {{token}}" } },
    { "action": "expect", "status": 401,
      "jsonPath": { "$.code": { "equals": "A-AUTH-1001" } } }
  ],
  "teardown": [
    { "action": "resetTime" }
  ]
}
```
## 如何验收
- [ ] <验收项>
```

## JSON 流字段约定

- `id`：用例唯一标识（kebab-case，与文件名一致）。
- `category`：功能领域，与所在子文件夹一致。
- `scope`：打哪个后端服务（对应 `test/api/INDEX.md` frontmatter `env.backends` 服务名）；**始终必填，且须与落盘路径 `<scope>` 顶层目录段一致**。
- **无 `baseUrl` 字段**：运行时由 INDEX `env.backends[scope]` 注入；仅当某步要访问外部 / 跨源地址时，在该 step 里写绝对 URL（`path` 以 `http(s)://` 开头时按绝对 URL 处理）。
- `setup` / `teardown`：可选前置 / 清理步骤，结构同 `steps`。
- `steps`：声明式步骤序列，按序执行、**断言失败即停**。
- `dependsOn`：可选，前置用例 `id` 列表（可跨 category 跨 scope）。声明"本用例依赖这些用例先成功"。无此字段 = 独立用例。详见下方「执行顺序与依赖」。
- `{{var}}`：步骤间变量插值，引用前序 `extract` 抽取的值。

## 执行顺序与依赖

- **用例内（强顺序）**：`setup → steps → teardown` 严格按序、断言失败即停、不跳步。**紧耦合多请求流（如"注册→登录→建单"）应写成同一用例里的有序 steps**——同一用例上下文内，`extract` 出的变量在后续 step 中天然可用。
- **用例间（依赖 + 跳过）**：默认用例自包含、互相独立，各自 `setup` 建立前置；执行按依赖拓扑序串行。失败策略：
  - **有依赖**：上游 `fail` / `error` / 被跳过 → 下游不运行、标 `skipped`，并**级联**到其传递依赖者。
  - **无依赖**：某用例失败不影响其它独立用例，继续跑完全部。
  - 依赖成环属编写错误：**编译阶段**检测到环 → 报错点名、不进入执行。

> 跨用例依赖只解决"**要不要跑**"（上游挂了下游别跑）；它依赖的是后端 / DB 等**持久应用状态**（整轮测试结束才 `down -v`，期间不清理，故上游写入的数据下游可见）。HTTP 客户端层面无"会话"概念，token 等凭证靠 `extract` + `{{var}}` 显式传递。

## 抽象 action 词表

按语义分四组，与具体 HTTP 客户端 / 时钟实现无关；执行映射见 `references/runner-ts-template.md`。

### HTTP 调用 + 断言

| action | 语义 |
|---|---|
| `request` | 发起 HTTP 请求。字段：`method`、`path`、`headers`、`query`、`body`（JSON 自动序列化）、`form`（表单）；`path` 可含 `{{var}}`。响应自动暂存供后续 `expect` / `extract` 使用 |
| `expect` | 断言最近一次 `request` 响应：`status`（数字 / 列表）、`headers`（key→value/contains/regex）、`jsonPath`（key→断言条件：`equals` / `exists` / `gt` / `lt` / `regex` / `length`）、`bodyContains`（子串） |
| `extract` | 从最近一次 `request` 响应抽取值供后续步骤插值。`jsonPath`：`{ 变量名: "$.x.y" }`、`headers`：`{ 变量名: "Set-Cookie" }` |

### 时间控制（要求应用按 `test-only-endpoints.md` 接入）

| action | 语义 |
|---|---|
| `advanceTime` | 推进应用时钟。字段：`duration`（如 `30m`、`365d`、`5m1s`）。调用 `POST /test/advance-time?d=<duration>` |
| `resetTime` | 重置应用时钟到 wall-clock now。`teardown` 必带 |
| `expireEntity` | 把某实体的某时间字段回填，模拟"已过期"。字段：`entity`（如 `order`）、`id`（支持 `{{var}}`）、`field`（如 `created_at`）、`by`（负向偏移，如 `31m`）。调用 `POST /test/backdate` |
| `triggerJob` | 同步触发某后台 job 立即执行一次。字段：`job`（如 `close-stale-orders`）、`args`（可选）。调用 `POST /test/trigger-job` |

### 数据准备 / 清理

| action | 语义 |
|---|---|
| `seed` | 注入测试数据。字段：`fixture`（fixture 名，由应用侧 `/test/seed` 识别）、`data`（任意 JSON payload）。调用 `POST /test/seed` |
| `cleanup` | 显式清理某实体。字段：`entity`、`filter`（条件）。调用 `POST /test/cleanup` |

### 控制流

| action | 语义 |
|---|---|
| `waitFor` | 等待某条件成立。字段：`condition`（仅支持 `request` 形式：`request` + `expect` 组合反复探测，间隔 `interval`、最长 `timeout`）。专治异步 job 触发后的最终一致性 |
| `sleep` | 真实等待固定时长。**仅允许 ≤5s**，超过会被代码生成器拒绝（请改用 `advanceTime` / `waitFor`） |

## 断言条件语法

`expect.jsonPath` 与 `expect.headers` 的 value 端支持以下形式之一：

| 形式 | 例 | 语义 |
|---|---|---|
| 标量 | `"hello"` / `42` / `true` | 等值 |
| `{ "equals": v }` | `{ "equals": "CLOSED" }` | 等值（显式） |
| `{ "exists": true/false }` | `{ "exists": true }` | 字段存在 / 不存在 |
| `{ "gt": v }` / `{ "lt": v }` / `{ "gte": v }` / `{ "lte": v }` | `{ "gt": 0 }` | 数值比较 |
| `{ "regex": "..." }` | `{ "regex": "^A-[A-Z]+-\\d+$" }` | 正则匹配 |
| `{ "length": n }` | `{ "length": 3 }` | 数组 / 字符串长度 |
| `{ "contains": v }` | `{ "contains": "expired" }` | 子串 / 数组包含 |

多个 jsonPath 是 AND 关系：必须全部满足才算 pass。

## 完整示例（订单 30min 自动关闭）

```json
{
  "id": "order-auto-close-after-30min",
  "category": "order",
  "scope": "api",
  "dependsOn": ["login-success"],
  "setup": [
    { "action": "request", "method": "POST", "path": "/login",
      "body": { "email": "u@example.com", "password": "secret" } },
    { "action": "extract", "jsonPath": { "token": "$.token" } }
  ],
  "steps": [
    { "action": "request", "method": "POST", "path": "/orders",
      "headers": { "Authorization": "Bearer {{token}}" },
      "body": { "sku": "X1", "qty": 1 } },
    { "action": "expect", "status": 201 },
    { "action": "extract", "jsonPath": { "orderId": "$.id" } },

    { "action": "expireEntity",
      "entity": "order", "id": "{{orderId}}", "field": "created_at", "by": "31m" },
    { "action": "triggerJob", "job": "close-stale-orders" },

    { "action": "request", "method": "GET", "path": "/orders/{{orderId}}",
      "headers": { "Authorization": "Bearer {{token}}" } },
    { "action": "expect", "status": 200,
      "jsonPath": {
        "$.status": "CLOSED",
        "$.closeReason": { "equals": "TIMEOUT" }
      } }
  ],
  "teardown": [
    { "action": "cleanup", "entity": "order", "filter": { "id": "{{orderId}}" } }
  ]
}
```
