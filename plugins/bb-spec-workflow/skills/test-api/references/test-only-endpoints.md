# 应用侧 /test/* 协议契约（与语言/框架无关）

`/test-api` 的前置依赖。后端须暴露一组以 `/test/` 开头的 HTTP 接口，让测试 runner 可控制时钟、回填数据、触发后台 job。**本契约只规定 HTTP wire（URL / 请求体 / 响应体 / 状态码）与隔离约束**——具体用什么语言、框架、时钟库实现，由各项目按本语言惯例自选。

## 1. 隔离契约（硬约束，无协商空间）

测试接口在**生产环境必须不可达**。具体机制由应用按所选语言生态自选——以下都满足约束：

- 编译期排除（Go build tag / Rust cargo feature / C# `#if` / Kotlin Gradle source set 等）
- 启动期开关（环境变量门控、Spring Profile、NestJS module condition 等）
- 部署期隔离（专用 e2e 镜像、独立 deployment、生产 ingress 不暴露 `/test/*` 前缀）

**约束底线**：

- **默认禁用**：未显式开启时，`/test/healthz` 返回 404 / 不存在，**不是返回 503**——404 才能让 skill 在生产探测时立刻判定"未启用 testapi 协议"。
- **生产防误启**：测试模式开启的进程检测到 `APP_ENV=production`（或等价信号）必须直接 panic / exit，绝不允许带测试接口跑生产流量。
- **CI 闸门**：生产部署配置（k8s / helm / terraform / dockerfile 默认 stage）禁止出现"开启测试模式"的标志位。

> 之所以坚持"默认禁用"而非"运行时开关默认关"，是因为运行时开关一旦配错就是漏洞；**编译期 / 部署期隔离比运行时 flag 更安全**——能选编译期就别选运行时。

## 2. 接口契约

所有接口前缀 `/test/`，请求 / 响应统一 JSON（`Content-Type: application/json`）。失败均返回 5xx + `{ "error": "<message>" }`，runner 据此标 `error`。

### `GET /test/healthz`

skill 启动时探测此接口确认应用已启用 testapi 协议。

**响应 200**：
```json
{
  "ok": true,
  "clock": "2026-06-25T10:00:00Z",   // 当前应用逻辑时钟（RFC3339）
  "mode": "testapi"                  // 固定字符串，标识本进程开启了测试模式
}
```

`mode` 字段必填，值 `"testapi"`。skill 用此字段防御"业务侧自己实现了 /test/healthz 但没接入完整协议"的歧义。

### `POST /test/advance-time`

```json
{ "duration": "30m" }
```

`duration` 支持 `Ns`（秒）/ `Nm`（分）/ `Nh`（小时）/ `Nd`（24h）的组合，例：`5m1s` / `365d` / `2h30m`。

实现：把应用逻辑时钟向前推 `duration`。**应用代码必须全程走自家 Clock 抽象**——直接 `time.Now()` / `Date.now()` 会绕过推进，导致时间敏感断言假阳性。

**响应 200**：`{ "clock": "<新 RFC3339>" }`

### `POST /test/reset-time`

无 body。把应用逻辑时钟重置回真实 wall-clock。每个用例的 teardown 默认带这一步。

**响应 200**：`{ "clock": "<RFC3339>" }`

### `POST /test/backdate`

```json
{
  "entity": "order",
  "id": "ord_123",
  "field": "created_at",
  "by": "31m"
}
```

把指定记录的某时间字段向**过去**偏移 `by`（即 `field = field - by`）。用于模拟"31 分钟前创建的订单"无需真等待。

应用层维护 `entity → table/column` 白名单，未在白名单内的 entity / field 返回 4xx。

**响应 200**：`{ "updated": 1 }`

### `POST /test/trigger-job`

```json
{ "job": "close-stale-orders", "args": { "batchSize": 1000 } }
```

同步执行一次指定后台 job（不等定时器、不进队列）。应用层维护 job 注册表。

**响应 200**：`{ "result": <job 返回值> }`，job 内部异常 → 5xx + error message。

### `POST /test/seed`

```json
{ "fixture": "user-with-balance", "data": { "email": "u@example.com", "balance": 100 } }
```

应用层维护 fixture 注册表，按 `fixture` 名分发到对应 seeder。

**响应 200**：`{ "seeded": <任意应用自定义字段，如新建 id> }`

### `POST /test/cleanup`

```json
{ "entity": "order", "filter": { "id": "ord_123" } }
```

按 filter 删除指定 entity 的记录。

**应用必须为每个 entity 设白名单过滤字段**——禁止 `filter: {}` 全删（无字段命中白名单时返回 4xx），防止误操作。

**响应 200**：`{ "deleted": <整数> }`

## 3. 多语言隔离 / 时钟实现样板

下表给出主流语言的**参考实现路径**，不强制——只要满足 §1 隔离契约 + §2 接口契约即可。

| 语言 / 框架 | 隔离机制 | 时钟抽象 |
|---|---|---|
| Go | `//go:build testapi` build tag（生产 `go build ./...` 不带 tag）+ `APP_ENV=production` panic | `github.com/jonboulle/clockwork` / `github.com/benbjohnson/clock` |
| Python (FastAPI / Flask) | 模块条件 `if os.getenv("TESTAPI") == "1"` mount router；生产镜像不设该 env | `freezegun` 库 或 自家 `Clock` Protocol 注入 |
| Node / TS (Express / Fastify / NestJS) | env 条件 `if (process.env.TESTAPI === "1") app.register(testRouter)`；生产 image 不设 | `@sinonjs/fake-timers` 或 自家 `Clock` interface 注入 |
| Java (Spring Boot) | `@Profile("testapi")` + `application-testapi.yaml`；生产 profile 不含此名 | `java.time.Clock` bean 注入，`Clock.fixed` / 自家 `MutableClock` |
| Kotlin (Ktor) | Gradle source set `testapiMain`；生产 jar 不含此 sourceset | 同 Java |
| Rust (Actix / Axum) | cargo feature `testapi`，生产 `cargo build --release` 不带 feature | `mock_instant` crate 或自家 `Clock` trait |
| C# (.NET) | `#if TESTAPI` 预处理 + `csproj` Configuration | `ITimeProvider`（.NET 8+ 内置）或自家接口 |

**通用约束（不论语言）**：

- 业务代码**禁止**直接调标准库的 `now()`（`time.Now()` / `Date.now()` / `Instant.now()` / `System.currentTimeMillis()` / `DateTime.Now` / `Date()`）——一律走应用自家 Clock 抽象。建议 CI 加 lint / grep 闸门。
- `/test/*` 接口必须与业务路由**同进程**（共享内存中的 Clock 实例），不能拆成独立进程。
- 测试镜像应通过 docker build args / `--target testapi` / 独立 `compose.e2e.yaml` 等机制启用，生产镜像保持原样。

## 4. compose.e2e.yaml 模板（语言无关骨架）

```yaml
services:
  api:
    build:
      context: .                                  # 或 ./backend，按 monorepo 形态调整
      # 启用 testapi 的方式按语言生态自选，例：
      # - Go:   args: { BUILD_TAGS: testapi },  Dockerfile 里 `go build -tags "$BUILD_TAGS"`
      # - 通用: target: testapi 多 stage Dockerfile
      # - 通用: environment 注入 TESTAPI=1（要求应用启动期门控）
    environment:
      APP_ENV: e2e                                # 须不等于 production
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

具体如何把"启用 testapi"映射到 build args / target / env，由项目按上表样板挑一种实现。

## 5. CI 防泄漏闸门

生产部署配置中**禁止出现**测试模式启用标志。在 CI 加一道 grep 闸门（具体关键字按所选机制调整）：

```bash
# 例 1：Go build tag 不得出现在 deploy 配置
if grep -rE "BUILD_TAGS.*testapi" deploy/ k8s/ helm/ 2>/dev/null; then
  echo "FATAL: testapi build tag leaked into production deploy config" >&2
  exit 1
fi

# 例 2：env 门控方案下，生产配置不得设 TESTAPI=1
if grep -rE "TESTAPI[: =]+['\"]?1['\"]?" deploy/prod/ 2>/dev/null; then
  echo "FATAL: TESTAPI=1 leaked into production deploy config" >&2
  exit 1
fi
```

## 6. 改造检查清单

接入 `/test-api` 前，应用须满足：

- [ ] 业务代码**零** `now()` 直接调用（lint / grep 通过）
- [ ] 自家 Clock 抽象就位、注入到所有用时间的服务层
- [ ] 隔离机制就位（编译期 / 启动期 / 部署期任选其一），生产镜像构建/部署默认不启用
- [ ] `APP_ENV=production` 防误启检测 + panic
- [ ] 七个接口（§2 列举）全部就位且返回结构符合约定
- [ ] `compose.e2e.yaml` 拉起后 `GET /test/healthz` 返回 `{ ok: true, mode: "testapi" }`
- [ ] CI 闸门：生产部署配置不含测试模式启用标志
