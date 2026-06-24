# md → Go test 代码生成模板

`/test-api` 步骤 4 编译阶段使用：把 md 用例机械渲染成 Go test 文件落盘 `${CACHE_DIR}/test-api-gen/`，再一次性 `go test -tags testapi -json` 跑完。

## 目录布局（生成产物）

```
${CACHE_DIR}/test-api-gen/
├── go.mod                              # 独立 module，名 testapigen
├── go.sum
├── helpers/
│   ├── client.go                       # HTTP 客户端 + action 执行器
│   ├── ctx.go                          # 共享上下文（base_url、变量表、依赖状态表）
│   ├── time.go                         # advanceTime / resetTime / expireEntity / triggerJob 调用
│   └── assert.go                       # 断言条件求值（equals/exists/gt/lt/regex/length/contains）
└── <scope>/
    └── <category>_test.go              # 每个 category 一个 _test.go，含该 category 全部用例
```

## go.mod 模板

```
module testapigen

go 1.22

require (
  github.com/stretchr/testify v1.9.0
  github.com/tidwall/gjson v1.17.0
)
```

`stretchr/testify` 提供 `require` 断言（失败即停）+ 友好 diff；`tidwall/gjson` 解析 jsonPath（轻量、无反射、足够 e2e）。

## helpers/ctx.go（共享上下文骨架）

```go
package helpers

import "sync"

type TestCtx struct {
  BaseURL  string                  // 当前 scope 的 base_url
  Vars     map[string]any          // extract 出来的变量，{{name}} 引用
  LastResp *Response               // 最近一次 request 响应
  mu       sync.Mutex
}

// 全局依赖状态表：用例 id → pass/fail/skip，用于 dependsOn 闸门
var (
  Status     = map[string]string{}
  StatusLock sync.RWMutex
)

func MarkPass(id string) { StatusLock.Lock(); Status[id] = "pass"; StatusLock.Unlock() }
func MarkFail(id string) { StatusLock.Lock(); Status[id] = "fail"; StatusLock.Unlock() }
func MarkSkip(id string) { StatusLock.Lock(); Status[id] = "skip"; StatusLock.Unlock() }

func DepsOk(deps []string) (bool, string) {
  StatusLock.RLock(); defer StatusLock.RUnlock()
  for _, d := range deps {
    if s, ok := Status[d]; !ok || s != "pass" { return false, d }
  }
  return true, ""
}
```

## helpers/client.go（HTTP + action 执行器要点）

- `Request(method, path string, opts RequestOpts) *Response`：拼 base_url + 自动 marshal body + 注入 headers + 变量插值（`{{var}}` 在 path/header/body 字符串里替换）
- `Response`：含 `Status int`、`Headers http.Header`、`Body []byte`
- `ApplyExpect(t, expect ExpectClause)`：对 `LastResp` 跑断言（status / headers / jsonPath / bodyContains）；用 testify `require` 失败即停
- `ApplyExtract(extract ExtractClause)`：从 `LastResp` 抽 jsonPath / headers，写入 `Vars`
- `Interpolate(s string, vars map[string]any) string`：`{{var}}` 模板替换；缺失变量 → testify `require.FailNow` 报缺失

## helpers/time.go（时间控制 action 执行器）

直接 POST 到 `/test/advance-time`、`/test/backdate`、`/test/trigger-job`，非 2xx → `require.FailNow` 报"应用未接入 testapi 改造"指引。

## helpers/assert.go（断言条件求值）

实现 `Eval(actual any, cond any) (ok bool, msg string)`：

- cond 是标量 → 等值
- cond 是 map[string]any → 按 key 路由（`equals` / `exists` / `gt` / `lt` / `gte` / `lte` / `regex` / `length` / `contains`）

## 用例 → Go test 渲染规则

### 命名

| md 字段 | Go 测试函数 |
|---|---|
| `id: token-expiry-after-5min` | `func TestCase_TokenExpiryAfter5Min(t *testing.T)` |

kebab-case → PascalCase + `TestCase_` 前缀，避免与项目其他测试名冲突。

### 函数骨架

```go
//go:build testapi
// +build testapi

package <category>

import (
  "testing"
  "testapigen/helpers"
)

func TestCase_TokenExpiryAfter5Min(t *testing.T) {
  const caseID = "token-expiry-after-5min"
  const scope  = "api"

  // 依赖闸门
  if ok, failed := helpers.DepsOk([]string{"login-success"}); !ok {
    helpers.MarkSkip(caseID)
    t.Skipf("dependency not satisfied: %s", failed)
  }

  ctx := helpers.NewCtx(scope)            // 注入 base_url、初始化 Vars
  defer helpers.RunTeardown(t, ctx, []helpers.Step{
    {Action: "resetTime"},
  })

  // ---- steps ----
  helpers.Step{Action: "request", Method: "POST", Path: "/login",
    Body: map[string]any{"email": "u@example.com", "password": "secret"}}.Run(t, ctx)
  helpers.Step{Action: "expect", Status: 200,
    JSONPath: map[string]any{"$.token": map[string]any{"exists": true}}}.Run(t, ctx)
  helpers.Step{Action: "extract",
    JSONPath: map[string]string{"token": "$.token"}}.Run(t, ctx)

  helpers.Step{Action: "advanceTime", Duration: "5m1s"}.Run(t, ctx)

  helpers.Step{Action: "request", Method: "GET", Path: "/api/me",
    Headers: map[string]string{"Authorization": "Bearer {{token}}"}}.Run(t, ctx)
  helpers.Step{Action: "expect", Status: 401,
    JSONPath: map[string]any{"$.code": map[string]any{"equals": "A-AUTH-1001"}}}.Run(t, ctx)

  helpers.MarkPass(caseID)
}
```

### 同 category 多用例

合并到同一 `_test.go` 文件，按 **依赖拓扑序** 排列函数声明。`go test` 默认按文件内函数定义顺序执行（非并行模式），与拓扑序对齐。

跨 category 依赖：因为 `Status` 表是 package 间共享的 `helpers` 全局变量，**跨 category 的依赖闸门自然成立**。但要求 `go test ./...` 跑 package 顺序与拓扑兼容——代码生成器按依赖图给每个 package 分配前缀数字 `01_<category>` / `02_<category>` 保证 package 排序与拓扑序一致。

### 依赖成环

编译阶段拓扑排序时检测，找到环 → 写一份 `_compile_error.go` 故意 `package main` 导致编译失败，错误信息：

```
// CYCLE DETECTED: <case-a> → <case-b> → <case-a>
package _compile_error
const _ = "remove dependsOn cycle in api-testcase: <a>, <b>"
```

main 编译失败 = go test 整体失败，error 信息直达用户。

## 串行约束的代码层落地

- **禁** 在生成的代码里调 `t.Parallel()`
- **禁** 在 `go test` 命令里传 `-parallel` / `-p` flag（命令行写死 `go test -tags testapi -json -count=1 ./...`）
- 每个 category 一个 package，`go test` 默认按 package 串行（除非加 `-p`）

## 失败信息回流

`go test -json` 输出的 `{"Action":"fail","Test":"TestCase_XxxYyy","Output":"..."}` 是 SKILL.md 步骤 5 报告解析的输入。代码生成器要保证每个断言失败带可读 message，例如：

```go
require.Equal(t, expected, actual,
  "step#3 expect: jsonPath %s, want %v, got %v", "$.code", expected, actual)
```

这样报告里能直接展示「step#3 expect: jsonPath $.code, want A-AUTH-1001, got A-AUTH-1003」。
