# md → 单文件 TS runner 渲染模板

`/test-api` 步骤 4 渲染阶段使用：把入选 md 用例与 INDEX `env.backends` 一起，机械渲染为单文件 `runner.ts` + `cases.json`，落 `${CACHE_DIR}/test-api-gen/`，再用 `bun run runner.ts` 一次跑完。

## 设计选择

| 关注点 | 决策 | 为什么 |
|---|---|---|
| 执行栈 | Bun + 原生 TS | 单二进制安装、零编译步骤、毫秒级冷启动；与 bb-spec-frontend 默认包管理器一致 |
| 测试框架 | **无**（不引 vitest/jest） | 并行/IDE 集成/堆栈我们都不需要；用例错误用 `step#K <action>` 定位，框架反成负担 |
| 报告格式 | 自定义 `result.json` | 主 agent 直接消费，schema 受控；不依赖框架报告解析 |
| 并发 | `await` 顺序循环 | 时钟串行约束；**禁** `Promise.all` / `Promise.allSettled` 跨用例并发 |
| 依赖 | runner.ts 内置 fetch + JSON path 子集；**不引第三方 npm 包** | 避免 `node_modules` / `package.json` / 安装步骤；Bun 自带 `fetch` 与 TS |
| 类型 | 内联类型定义，不引外部 `.d.ts` | 单文件自包含 |

## 产物布局

```
${CACHE_DIR}/test-api-gen/
├── .fingerprint        # SHA-256(入选 md 拼接 + 本模板)
├── cases.json          # 渲染产物：拓扑序的用例数组 + backends 映射
├── runner.ts           # 渲染产物：唯一可执行文件
└── result.json         # 运行产物：runner 写入
```

## cases.json schema（渲染产物）

```jsonc
{
  "backends": {
    // 来自 INDEX env.backends：scope 名 → base_url
    "api": "http://localhost:8080"
  },
  "testEndpointsPrefix": "/test",     // 来自 INDEX env.test_endpoints_prefix
  "cases": [
    // 已按 dependsOn 拓扑序排序；环已在渲染阶段被拒绝
    {
      "id": "login-success",
      "category": "auth",
      "scope": "api",
      "dependsOn": [],
      "setup":    [ /* steps[] */ ],
      "steps":    [ /* steps[] */ ],
      "teardown": [ /* steps[] */ ]
    }
    // ...
  ]
}
```

step 对象的字段定义见 `references/api-testcase-format.md`「抽象 action 词表」与「断言条件语法」——本 runner 是该词表的执行映射，**不扩展**词表。

## result.json schema（runner 输出，主 agent 消费）

```jsonc
{
  "startedAt": "2026-06-25T10:00:00.000Z",
  "finishedAt": "2026-06-25T10:01:23.456Z",
  "summary": { "pass": 8, "fail": 1, "error": 0, "skipped": 2, "total": 11 },
  "results": [
    {
      "caseId": "login-success",
      "scope": "api",
      "category": "auth",
      "status": "pass",                 // pass | fail | error | skipped
      "durationMs": 142,
      "failedStep": null,               // 仅 fail / error：{ phase, index, action, message }
      "skippedBy": null,                // 仅 skipped：上游失败 caseId
      "evidence": []                    // 仅 fail / error：响应摘要等取证片段
    }
    // ...
  ]
}
```

`status` 取值约束：
- `pass`：所有 setup + steps + teardown 步骤通过
- `fail`：断言不通过（`expect` 失败、`waitFor` 超时仍不满足）
- `error`：执行异常（网络错误、JSON 解析失败、`/test/*` 非 2xx、不识别的 action）
- `skipped`：依赖闸门拒绝执行（任一 `dependsOn` 上游非 `pass`）

## runner.ts 结构骨架

模板要求每个渲染必含以下函数；具体实现允许优化，但**外部行为** / **result.json schema** 不得偏离。

```typescript
// runner.ts —— 渲染产物，禁手改
// 入口：bun run runner.ts
// 读取：./cases.json
// 写出：./result.json

interface Step {
  action: "request" | "expect" | "extract" | "advanceTime" | "resetTime"
        | "expireEntity" | "triggerJob" | "seed" | "cleanup"
        | "waitFor" | "sleep"
  [k: string]: unknown
}

interface Case {
  id: string; category: string; scope: string
  dependsOn: string[]
  setup: Step[]; steps: Step[]; teardown: Step[]
}

interface Plan {
  backends: Record<string, string>
  testEndpointsPrefix: string
  cases: Case[]
}

interface CaseResult {
  caseId: string; scope: string; category: string
  status: "pass" | "fail" | "error" | "skipped"
  durationMs: number
  failedStep: { phase: "setup" | "steps" | "teardown"; index: number; action: string; message: string } | null
  skippedBy: string | null
  evidence: unknown[]
}

const plan: Plan = await Bun.file("./cases.json").json()

// 兜底校验：dangling dependsOn（渲染期已校验，这里防御渲染逻辑被改坏）
const caseIds = new Set(plan.cases.map(c => c.id))
const dangling = plan.cases.flatMap(c => c.dependsOn.filter(d => !caseIds.has(d)).map(d => ({ case: c.id, missing: d })))
if (dangling.length) {
  console.error("FATAL: dangling dependsOn references:", JSON.stringify(dangling, null, 2))
  process.exit(2)
}

const status = new Map<string, CaseResult["status"]>()
const results: CaseResult[] = []
const startedAt = new Date().toISOString()

for (const c of plan.cases) {
  // 依赖闸门
  const failedUpstream = c.dependsOn.find(d => status.get(d) !== "pass")
  if (failedUpstream) {
    const r: CaseResult = {
      caseId: c.id, scope: c.scope, category: c.category,
      status: "skipped", durationMs: 0,
      failedStep: null, skippedBy: failedUpstream, evidence: []
    }
    status.set(c.id, "skipped"); results.push(r); continue
  }

  const ctx = makeCtx(plan, c.scope)             // { baseUrl, vars: {}, lastResp: null }
  const t0 = performance.now()
  const r: CaseResult = {
    caseId: c.id, scope: c.scope, category: c.category,
    status: "pass", durationMs: 0,
    failedStep: null, skippedBy: null, evidence: []
  }

  try {
    await runPhase("setup", c.setup, ctx, r)
    if (r.status === "pass") await runPhase("steps", c.steps, ctx, r)
    // teardown 无论前面成败都跑（用于 resetTime / cleanup）；teardown 失败不覆盖业务 status，只补记
    await runPhase("teardown", c.teardown, ctx, r, { keepStatusOnFail: true })
  } catch (e) {
    r.status = "error"
    r.failedStep = { phase: "steps", index: -1, action: "(uncaught)", message: String(e) }
  }

  r.durationMs = Math.round(performance.now() - t0)
  status.set(c.id, r.status); results.push(r)
}

const finishedAt = new Date().toISOString()
const summary = aggregate(results)              // 数 pass/fail/error/skipped/total

await Bun.write("./result.json", JSON.stringify({ startedAt, finishedAt, summary, results }, null, 2))

// 进程退出码：仅 fail / error 影响（skipped 不算失败）
process.exit(summary.fail + summary.error > 0 ? 1 : 0)
```

## action 执行映射（runner 内 dispatch）

按 `references/api-testcase-format.md` 词表，每个 action 的执行行为：

### `request`
拼 `ctx.baseUrl + interpolate(path, ctx.vars)`（path 以 `http(s)://` 开头时按绝对 URL 处理）→ 用 Bun 内置 `fetch` 发送，注入 `headers` / `query` / `body`（JSON 自动 `JSON.stringify` + `Content-Type: application/json`）或 `form`（`URLSearchParams`）→ 响应解析为 `{ status, headers, bodyText, bodyJson? }` 存入 `ctx.lastResp`。**非 2xx 不报错**，留给下一步 `expect` 断言。

### `expect`
对 `ctx.lastResp` 跑断言：
- `status`：标量等值或数组 `[200, 201]` 任一匹配
- `headers`：`{ key: matcher }`，matcher 同断言条件语法
- `jsonPath`：`{ "$.a.b": matcher }`，按 `$.a.b[0].c` 子集对 `bodyJson` 取值（实现一个 ~30 行的简易求值器；遇 wildcard `$..` / 复杂表达式应抛 `error` 而非静默假阳性）
- `bodyContains`：`bodyText.includes(v)`
任一断言失败 → 标 `fail`、记 `failedStep`、push evidence（status + 截断的 body）、本用例后续步骤跳过（teardown 仍跑）。

### `extract`
- `jsonPath`：`{ varName: "$.x.y" }` → 写入 `ctx.vars[varName]`
- `headers`：`{ varName: "Set-Cookie" }` → 写入 `ctx.vars[varName]`

### `advanceTime` / `resetTime` / `expireEntity` / `triggerJob` / `seed` / `cleanup`
POST 到 `ctx.baseUrl + plan.testEndpointsPrefix + "/<endpoint>"`，body 为该 step 的字段（已剥离 `action`）。非 2xx → 标 `error`，message 为 `"<endpoint> returned <status>: 应用未按协议契约接入"`。endpoint 映射：

| action | endpoint |
|---|---|
| `advanceTime` | `/advance-time` |
| `resetTime` | `/reset-time` |
| `expireEntity` | `/backdate` |
| `triggerJob` | `/trigger-job` |
| `seed` | `/seed` |
| `cleanup` | `/cleanup` |

### `waitFor`
固定结构：`{ action: "waitFor", request: {...}, expect: {...}, interval: "500ms", timeout: "30s" }`。runner 内部按 `interval` 周期 `request + expect`，直到 `expect` 通过或超过 `timeout`。超时 → 标 `fail`。

### `sleep`
`{ duration: "<≤5s>" }`。runner 校验 ≤ 5000ms，超出标 `error`（"请改用 advanceTime / waitFor"）。

## interpolate（变量插值）

只在以下位置识别 `{{var}}`：`path` / `headers` value / `body`（字符串值递归替换；非字符串原样）/ `query` value / `form` value。
- 缺失变量 → 标 `error`，message 为 `"missing variable: {{var}}"`
- 实现：单次正则 `\{\{(\w+)\}\}` 替换，**禁** 任何代码执行 / 表达式求值

## 用例间隔离

- runner 全过程**单进程单 ctx 池**，但每个用例独立 `makeCtx()`——`vars` / `lastResp` 不跨用例泄漏
- 持久状态（DB / 应用内存）由 `down -v` 在整轮结束后清，**用例间不清**——这是 dependsOn 语义的前提（上游写入下游可见）

## 渲染阶段的职责

主 agent 在渲染时必须做：

1. **拓扑排序**：按 `dependsOn` 把 `cases` 排成线性序列；检测环 → 渲染失败、报错点名、不写盘
2. **scope 注入**：每个 case 的 `scope` 必须在 `plan.backends` 里找得到 base_url；找不到 → 渲染失败
3. **action 白名单**：每个 step 的 `action` 必须在词表内；未知 action → 渲染失败（早于 runner 跑）
4. **sleep 上限**：渲染期就拒绝 `sleep.duration > 5s`，不延后到 runner
5. **`dependsOn` 引用完整性**：每个 case 的 `dependsOn` 中每个 caseId 必须在 plan.cases 的 `id` 集合内；缺失 → 渲染失败、报错点名（输出 `case <id> 依赖的 caseId <missing> 不存在——typo 还是漏写？`）、不写盘。**禁静默吞掉**——若放过到 runner，dangling 引用会被依赖闸门当作"上游失败"标 skipped，退出码仍为 0，与 SKILL 顶层"禁静默漏测"原则冲突

渲染失败属编写错误，按 `references/api-testcase-format.md` 规范修 md 用例后重跑。

## 不变量（自检清单）

- [ ] `runner.ts` 单文件、无 `import` 外部 npm 包（仅 `Bun.*` / `globalThis.fetch` / 内置 `URL` `URLSearchParams` `performance` 等）
- [ ] 无 `Promise.all` / `Promise.allSettled` / `Promise.race` 跨用例并发调用
- [ ] `result.json` 写盘后再 `process.exit`
- [ ] 退出码：`fail + error > 0` → 1，否则 0；`skipped` 不影响退出码
- [ ] teardown 失败不覆盖 `pass` 状态（仅在 `evidence` 补记）
