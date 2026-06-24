# 应用侧改造规范（test-only endpoints）

`/test-api` 的前置依赖。把后端改造成支持时间穿越 + 数据回填 + job 手动触发的 e2e 友好形态，**通过 Go build tag 与生产构建编译期隔离**。

## 总体设计

| 关注点 | 方案 |
|---|---|
| 时间获取 | 全应用走 `Clock` 接口，禁直接 `time.Now()`；prod 用 `RealClock`、e2e 用 `FakeClock` |
| 测试接口隔离 | `//go:build testapi` build tag，**生产构建编译期不存在** `/test/*` 路由 |
| 生产防误启 | 带 `testapi` tag 的二进制若检测到 `APP_ENV=production` → panic 退出 |
| Docker 编排 | `docker-compose.e2e.yaml` 通过 build args 注入 `BUILD_TAGS=testapi` |

## 1. 时钟注入

依赖：`github.com/jonboulle/clockwork`（推荐，API 简洁；亦可用 `benbjohnson/clock`）。

**禁**：项目内任意位置直接调 `time.Now()` / `time.Since()` / `time.Until()`（除了 main 装配 clock 之外的入口）。
**约定**：所有需要"当前时间"的代码持有 `clockwork.Clock` 依赖。

```go
// internal/platform/clock/clock.go（生产入口固定 real）
package clock

import "github.com/jonboulle/clockwork"

var c clockwork.Clock = clockwork.NewRealClock()

func Get() clockwork.Clock { return c }
func Set(x clockwork.Clock) { c = x }    // 仅 testapi build 用
```

业务代码：

```go
type OrderService struct {
  clock clockwork.Clock
  // ...
}

func (s *OrderService) CreateOrder(...) {
  now := s.clock.Now()    // ✅
  // time.Now()           // ❌
}
```

CI 加 lint 检查：禁止业务包内出现 `time.Now()` 调用（go-vet 自定义 analyzer 或简单 grep）。

## 2. build tag 隔离

测试接口源文件加 build tag：

```go
//go:build testapi
// +build testapi

package router

import (
  "net/http"
  "os"

  "github.com/jonboulle/clockwork"

  "myapp/internal/platform/clock"
)

func init() {
  // 防误启：带 testapi tag 的二进制绝不允许跑生产
  if os.Getenv("APP_ENV") == "production" {
    panic("testapi build must not run in production")
  }
  // 安装 FakeClock
  clock.Set(clockwork.NewFakeClockAt(clock.Get().Now()))
}

func RegisterTestRoutes(mux *http.ServeMux) {
  mux.HandleFunc("GET /test/healthz", healthz)
  mux.HandleFunc("POST /test/advance-time", advanceTime)
  mux.HandleFunc("POST /test/backdate", backdate)
  mux.HandleFunc("POST /test/trigger-job", triggerJob)
  mux.HandleFunc("POST /test/seed", seed)
  mux.HandleFunc("POST /test/cleanup", cleanup)
  mux.HandleFunc("POST /test/reset-time", resetTime)
}
```

main 装配只在 testapi build 注册：

```go
//go:build testapi
// +build testapi

package main

func registerTestRoutesIfAny(mux *http.ServeMux) {
  router.RegisterTestRoutes(mux)
}
```

```go
//go:build !testapi
// +build !testapi

package main

func registerTestRoutesIfAny(mux *http.ServeMux) {
  // no-op：生产构建中本函数体为空，/test/* 路由编译期不存在
}
```

**关键点**：生产 `go build ./...`（不带 `-tags testapi`）出来的二进制里**找不到任何 `/test/*` 路由源码**——这是编译期隔离，比运行时 flag 关闭更安全（运行时 flag 一旦配错就是漏洞）。

## 3. 测试接口规范

所有接口前缀 `/test/`，请求 / 响应统一 JSON。

### GET /test/healthz

返回 200 + `{ "ok": true, "clock": "<RFC3339>", "build_tags": "testapi" }`。`/test-api` skill 启动时探测此接口确认改造已就位。

### POST /test/advance-time

```json
{ "duration": "30m" }
```
解析 `duration`（支持 `s`/`m`/`h`/`d`，`d` 按 24h 算），调用 `clock.Get().(*clockwork.FakeClock).Advance(d)`。返回新 `clock`。

### POST /test/reset-time

无 body。把 FakeClock 重置回 `time.Now()`。

### POST /test/backdate

```json
{ "entity": "order", "id": "ord_123", "field": "created_at", "by": "31m" }
```
应用层提供 entity→table 映射，执行 `UPDATE <table> SET <field> = <field> - <by> WHERE id = ?`。**注意 by 是负向偏移**（"31 分钟前"对应 `created_at = created_at - 31m`）。

### POST /test/trigger-job

```json
{ "job": "close-stale-orders", "args": { "batchSize": 1000 } }
```
查注册表，同步执行一次该 job（不等定时器），返回执行结果或异常。

### POST /test/seed

```json
{ "fixture": "user-with-balance", "data": { "email": "u@example.com", "balance": 100 } }
```
应用层维护 fixture 注册表，按名称分发到对应 seeder。

### POST /test/cleanup

```json
{ "entity": "order", "filter": { "id": "ord_123" } }
```
按 filter 删除指定 entity 的记录。慎用 `filter: {}` 全删——应用层对每个 entity 设白名单字段。

## 4. docker-compose.e2e.yaml 模板

```yaml
services:
  api:
    build:
      context: ./backend                    # 或仓库根，按 monorepo 形态调整
      dockerfile: Dockerfile
      args:
        BUILD_TAGS: testapi                  # 关键：触发 testapi build
    environment:
      APP_ENV: e2e                            # 禁等于 production
      DATABASE_URL: postgres://e2e:e2e@db:5432/e2e
    ports:
      - "8080:8080"
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: e2e
      POSTGRES_PASSWORD: e2e
      POSTGRES_DB: e2e
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U e2e"]
      interval: 2s
      timeout: 3s
      retries: 30
```

Dockerfile 需消费 `BUILD_TAGS`：

```dockerfile
ARG BUILD_TAGS=""
RUN go build -tags "$BUILD_TAGS" -o /app/server ./cmd/server
```

## 5. CI 防泄漏检查

仓库根 `.github/workflows/` 或等价 CI 配置中加一道闸门：

```bash
# 生产构建禁带 testapi tag
if grep -r "BUILD_TAGS.*testapi" deploy/ k8s/ helm/ 2>/dev/null; then
  echo "FATAL: testapi build tag leaked into production deploy config" >&2
  exit 1
fi
```

## 6. 改造检查清单

接入 `/test-api` 前后端应核对：

- [ ] 业务包内**零** `time.Now()` 直接调用（lint 通过）
- [ ] `internal/platform/clock` 包就位，`Clock` 依赖注入到所有服务层
- [ ] `testapi` build tag 源文件就位，`registerTestRoutesIfAny` 双实现
- [ ] `APP_ENV=production` 检测 + panic
- [ ] `docker-compose.e2e.yaml` 通过 `BUILD_TAGS=testapi` 构建后端镜像
- [ ] CI 有"prod 配置禁带 testapi tag"闸门
- [ ] `/test/healthz` 返回包含 `build_tags: testapi`
