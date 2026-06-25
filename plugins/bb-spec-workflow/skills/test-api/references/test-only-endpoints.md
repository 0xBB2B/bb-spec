# 应用侧 /test/* 协议契约（与语言/框架无关）

`/test-api` 的前置依赖。后端须暴露一组以 `/test/` 开头的 HTTP 接口，让测试 runner 可控制时钟、回填数据、触发后台 job。**本契约只规定 HTTP wire（URL / 请求体 / 响应体 / 状态码）与隔离约束**——具体用什么语言、框架、时钟库实现，由各项目按本语言惯例自选。

## 1. 隔离契约（硬约束，无协商空间）

测试接口在**生产环境必须不可达**。本契约采用「打包闸门 + 运行时门控 + CI 闸门」三件套，**全部强制、缺一不可**。

### 1.1 打包闸门（唯一主防线）

生产镜像里**物理上不含** `/test/*` 路由代码——image 里没有这段源码，运行时怎么配也触发不了。

典型部署模型是 build 阶段产出**两个 image**：

| Image | 用途 | `/test/*` 代码 | `TESTAPI` env |
|---|---|---|---|
| **A（test 镜像）** | 部署到 test 环境跑 `/test-api` | ✅ 含 | Dockerfile `ENV TESTAPI=1` 写死 |
| **B（生产镜像，sand + prod 共用）** | 部署到 sand / staging / prod | ❌ 物理不含 | 不写 |

具体「如何让 Image B 不含 `/test/*` 代码」按所选语言生态自选（见 §3 样板表）：编译期排除（Go build tag / Rust feature）、多 stage Dockerfile 生产 stage 不 COPY testapi 源码、build 时 `rm -rf` 兜底等。

> 即使 sand / prod 运维误注入 `TESTAPI=1`，Image B 里无路由代码可挂载，`/test/healthz` 直接 404——fail-close 默认。

### 1.2 运行时门控（强制）

应用启动时**仅当**环境变量 `TESTAPI=1` 时挂载 `/test/*` 路由；否则 `/test/healthz` 返回 404 / 不存在（**不是返回 503**——404 才能让 skill 在探测时立刻判定"未启用 testapi 协议"）。

**不查任何生产 env 名**（`APP_ENV` / `NODE_ENV` / `RAILS_ENV` / `SPRING_PROFILES_ACTIVE` / `DEPLOY_ENV` / ...）——生产 env 命名因栈/团队习惯而异，穷举不完；image 物理排除已经是主防线，运行时再加 env 黑/白名单徒增跨栈耦合且无新增防御。

### 1.3 CI 闸门（强制）

生产部署配置（Helm values / k8s manifest / Terraform / 生产 Dockerfile 默认 stage）禁止出现：

- 环境变量 `TESTAPI=1`
- testapi build flag / feature / sourceSet 启用标志（按所选语言机制）

并对生产 image 做**物理验证**：构建完成后 grep 镜像内无 testapi 路由源码目录。具体 grep / find 样板见 §5。

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

| 语言 / 框架 | 打包期排除（产 Image B 时让 `/test/*` 源码不进 image） | 运行时门控（Image A 内，检测 `TESTAPI=1` 才挂载路由） | 时钟抽象 |
|---|---|---|---|
| Go | `//go:build testapi` build tag；生产 `go build ./...` 不带 tag | `os.Getenv("TESTAPI") == "1"` 才注册 testapi router | `github.com/jonboulle/clockwork` / `github.com/benbjohnson/clock` |
| Python (FastAPI / Flask) | 多 stage Dockerfile，生产 stage 不 `COPY app/test_endpoints/`；或 `.dockerignore` 排除该目录 | `if os.getenv("TESTAPI") == "1": app.include_router(test_router)` | `freezegun` 库 或 自家 `Clock` Protocol 注入 |
| Node / TS (Express / Fastify / NestJS) | 多 stage Dockerfile，生产 stage 不 `COPY src/test-endpoints/`；或 build 时 `rm -rf` 兜底 | `if (process.env.TESTAPI === "1") app.register(testRouter)` | `@sinonjs/fake-timers` 或 自家 `Clock` interface 注入 |
| Java (Spring Boot) | Gradle 拆 source set `testapiMain`，生产 jar 不含该 sourceSet | `@ConditionalOnProperty("TESTAPI=1")` 自动装配 testapi `@Configuration` | `java.time.Clock` bean 注入，`Clock.fixed` / 自家 `MutableClock` |
| Kotlin (Ktor) | 同 Java（Gradle source set） | `if (System.getenv("TESTAPI") == "1") routing { testRoutes() }` | 同 Java |
| Rust (Actix / Axum) | cargo feature `testapi`，生产 `cargo build --release` 不带 feature | `if std::env::var("TESTAPI").as_deref() == Ok("1") { ... }` | `mock_instant` crate 或自家 `Clock` trait |
| C# (.NET) | `#if TESTAPI` 预处理 + `csproj` 双 Configuration（生产 Configuration 无 `TESTAPI` 常量） | `Environment.GetEnvironmentVariable("TESTAPI") == "1"` 才 `app.MapTestEndpoints()` | `ITimeProvider`（.NET 8+ 内置）或自家接口 |
| Ruby / PHP（无编译期机制） | 多 stage Dockerfile，生产 stage 不 `COPY` testapi 目录；或 build 时 `rm -rf` 兜底 | `ENV['TESTAPI'] == '1'` 才挂载 testapi 路由 | 自家 `Clock` 接口注入 |

**通用约束（不论语言）**：

- 业务代码**禁止**直接调标准库的 `now()`（`time.Now()` / `Date.now()` / `Instant.now()` / `System.currentTimeMillis()` / `DateTime.Now` / `Date()`）——一律走应用自家 Clock 抽象。建议 CI 加 lint / grep 闸门。
- `/test/*` 接口必须与业务路由**同进程**（共享内存中的 Clock 实例），不能拆成独立进程。
- **Image A 推荐在 Dockerfile 里 `ENV TESTAPI=1` 写死**——image 自带、部署不需手动注入、出错面最小。

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
      APP_ENV: e2e                                # 仅作环境标识，不参与隔离判断（§1.2 不检测任何生产 env 名）
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

按 §1.3 约束，生产部署配置**禁止出现**测试模式启用标志，且生产 image 必须**物理不含** testapi 源码。在 CI 加三道闸门：

```bash
# 闸门 1：生产部署配置（helm / k8s / terraform / 生产 Dockerfile 默认 stage）禁含 TESTAPI=1
if grep -rE "TESTAPI[: =]+['\"]?1['\"]?" deploy/prod/ helm/prod/ k8s/prod/ 2>/dev/null; then
  echo "FATAL: TESTAPI=1 leaked into production deploy config" >&2
  exit 1
fi

# 闸门 2：生产 build 命令禁带 testapi 启用标志（按所选语言机制调整关键字）
# - Go:    禁 `-tags testapi`
# - Rust:  禁 `--features testapi`
# - Docker multi-stage: 禁 `--target testapi-*`
# - Gradle: 禁 `-PtestapiEnabled=true` / 含 testapiMain sourceSet 的 build 命令
if grep -rE "(-tags[[:space:]]+testapi|--features[[:space:]]+testapi|--target[[:space:]]+testapi)" deploy/prod/ Dockerfile 2>/dev/null; then
  echo "FATAL: testapi build flag leaked into production build" >&2
  exit 1
fi

# 闸门 3：生产 image 物理验证（最强一道——直接看镜像 layer 无 testapi 源码）
# 在生产 image 构建后跑（路径名按本项目实际命名调整）：
LEAKS=$(docker run --rm prod-image:latest sh -c '
  find / -path /proc -prune -o -path /sys -prune -o \
    \( -type d \( -name "test_endpoints" -o -name "testapi" -o -name "test-endpoints" \) -print \)
')
if [ -n "$LEAKS" ]; then
  echo "FATAL: testapi source dir found in prod image:" >&2
  echo "$LEAKS" >&2
  exit 1
fi
```

闸门 1、2 防配置层泄漏，闸门 3 是**事实层兜底**——配置可能漏改、build 命令可能本地误改，但镜像内容是不可抵赖的事实，任一闸门未过即生产部署阻断。

## 6. 改造检查清单

接入 `/test-api` 前，应用须满足：

- [ ] 业务代码**零** `now()` 直接调用（lint / grep 通过）
- [ ] 自家 Clock 抽象就位、注入到所有用时间的服务层
- [ ] **双 image 产出**：test image 含 `/test/*` 路由代码 + Dockerfile `ENV TESTAPI=1` 写死；生产 image（sand + prod 共用）物理不含 `/test/*` 源码
- [ ] **运行时门控**：应用启动时仅当 `TESTAPI=1` 时挂载 `/test/*` 路由；其他情况 `/test/healthz` 返回 404
- [ ] **生产 image 物理验证**：`find` / `grep` 生产 image 内**无** testapi 路由源码目录（§5 闸门 3）
- [ ] 七个接口（§2 列举）全部就位且返回结构符合约定
- [ ] test image 拉起后 `GET /test/healthz` 返回 `{ ok: true, mode: "testapi" }`
- [ ] CI 闸门：生产部署配置不含 `TESTAPI=1` 或 testapi build flag（§5 三道闸门全部就位）
