---
name: observability-constraints
description: 可观测性约束（日志/链路/指标）——三信号一处装配 + OTel 统一标准；JSON 日志 + trace_id 从 ctx 自动注入（无 trace 输出空串）；指标 `<domain>_<noun>_<unit>` + label 基数有限；body 凭证脱敏。触发：搭建/修改日志/链路/指标、新增指标或日志字段、接入 OTel/OTLP、设计日志级别或告警。跳过：前端埋点/RUM、纯三方托管 APM。
user-invocable: false
---

# 可观测性约束（日志 / 链路 / 指标）

适用于：后端服务的日志、分布式链路、指标三类可观测性信号的设计、装配、实现、文档与 review。**原则技术栈无关**，落地示例用 Go + OpenTelemetry（OTel）。

> 定位：**技术框架定型，钉死「机制骨架」（【硬】必守），不绑「业务策略」（【软】给能力、由项目按业务选）。**

## 0. 触发与跳过

**TRIGGER**：搭建/修改日志、链路追踪、指标；新增一个指标或日志字段；接入 OTel / OTLP collector；设计日志级别或告警；文档 / PRD / 设计 / review 涉及可观测性。
**SKIP**：前端埋点 / RUM、与可观测性无关的业务逻辑、纯三方托管 APM（不自管信号装配）。

---

## 1. 三信号统一装配【硬】

- **一处装配 + 全局注册**：Logger / Tracer / Meter 由**单一装配入口**一次性创建并注册到进程全局，消灭散装初始化导致的遗漏与顺序错误。业务层与基础设施层**不得**另起 provider / propagator / exporter。
- **OTel 为统一标准**：三信号统一走 OpenTelemetry SDK + OTLP 上报。
- **exporter 可独立开关、本地 provider 常驻**：每个信号的 OTLP 上报由开关（如环境变量 `OTEL_{LOGS,TRACES,METRICS}_EXPORTER=otlp`）控制，**默认关闭**；关闭的只是「远端上报」，对应**本地 SDK provider 仍必须装配**——Traces 关仍维持 span 父子让 `trace_id` 稳定输出、Metrics 关仍保留 MeterProvider 避免 nil。
- **propagator 注册先于任何下游客户端构造**；自举/上报连接独立装配，**禁复用业务 RPC client**（防自我递归 instrument）。
- **生命周期**：装配资源注册到统一 closer，按 LIFO 释放，错误聚合不阻断后续。任一装配步骤失败，已建资源回滚、不泄漏连接。

---

## 2. 结构化日志【硬】

JSON 输出，固定必填字段，让日志后端按固定 schema 检索：

| 字段 | 说明 |
|---|---|
| `service` | 服务名，装配时自动注入 |
| `level` | DEBUG / INFO / WARN / ERROR |
| `msg` | 日志消息 |
| `time` | RFC 3339 微秒精度 |
| `trace_id` / `span_id` | 从请求 context 提取，**无 trace 时稳定输出 `""`** |

- **WARN / ERROR 追加**：`error`（`err.Error()`）、`error_code`（结构化错误码，对齐 `api-design` 的 `A-BBB-CCCC`，无则 `""`），由统一 helper 生成，禁各处自行拼装。
- **字段名常量化**：引用统一字段常量，禁字面量散布。
- **禁第三方日志库**（Go：禁 `log` / `logrus` / `zap`，统一 `log/slog`）。
- **身份字段时机**：仅在身份可信化（验签 / identity 注入）之后，才允许记录**脱敏后**的主体标识（如 `user_id`）；验签前禁带身份字段。

---

## 3. 日志与 trace 关联【硬】

- `trace_id` / `span_id` 由日志 handler **从请求 context 自动注入**，调用方不手动传、不逐层透传 logger 实例（全局 default logger + 包级写法）。
- **业务路径必须携带 ctx**：handler / service / repository / 中间件 / 拦截器等位置，日志调用必须传入当前 ctx，否则 trace 字段为空、链路在日志侧断裂。
- **CI 强制**（Go：`slog.*Context` + golangci-lint `sloglint` `context: scope`）：在 ctx 已存在的现场漏传即报错。仅进程级启动/关闭、共享库无 ctx 处可例外。

```go
// ✅ 业务路径传 ctx —— trace_id 自动关联
slog.InfoContext(ctx, "order created", "order_id", order.ID)
// ❌ 漏 ctx —— trace_id 断裂，sloglint 报错
slog.Info("order created", "order_id", order.ID)
```

---

## 4. 日志级别语义【硬】

避免业务预期反馈污染 ERROR 告警，也避免系统故障被降级漏告警：

| 级别 | 语义 | 例 |
|---|---|---|
| **ERROR** | 系统级阻断故障 | DB 不可达、panic、OOM、下游连接拒绝 |
| **WARN** | 业务非阻断错误（系统本身健康） | 参数不合法、token 过期、资源不存在、缓存 miss 回源 |
| **INFO** | 关键业务事件 | 订单创建、回调到达、配置变更成功 |
| **DEBUG** | 调试细节，默认不开 | dev/test 按需启用 |

- **状态码→级别映射单点维护**：HTTP `5xx`→ERROR / `4xx`→WARN / 其余→INFO；RPC 系统类码（如 gRPC `Internal/Unavailable`）→ERROR、其余业务码→WARN。映射逻辑集中一处，入站中间件、出站、RPC 拦截器三处共用。
- **禁调用点局部覆盖**（如 `if status==404 { level=WARN }`）；改映射改本体并补单测。

---

## 5. 分布式追踪【硬】

- **入口建根 span**：边缘服务（Gateway / API 入口）在入站时创建根级 span，`traceparent` 经 RPC metadata / HTTP header 向下游传播。
- **下游续接不新建根**：下游服务续接上游 trace，全链路 `trace_id` 一致可查。
- **本地无 collector 仍维持 span 父子**：让日志 `trace_id` / `span_id` 输出真值而非空串。
- 各服务统一通过全局 Tracer 使用，**禁自行构造 TracerProvider / 调 `SetTracerProvider`**；下游 client 要求 tracer 非 nil，nil 时 fail-fast。

---

## 6. 指标规范【硬】

- **命名**：`<domain>_<noun>_<unit>`，全 snake_case，与 Prometheus 生态对齐。`_total` 用于 Counter、`_duration_ms` 用于 Histogram。禁 CamelCase。例：`cache_get_total`、`order_create_duration_ms`。
- **label 基数必须有限可枚举**【最易踩坑】：
  - 允许：`result="hit|miss|error"`、`method="GET|POST"`、`grpc_code="OK|NotFound"`。
  - **禁止**：`id`（用户/订单 ID）、完整 cache key、实例化 URL 作 label——会撑爆时序库。路由 label 必须用 pattern（`/api/v1/orders/{id}`）而非实例化 URL。
- **业务指标归服务自身**：各服务用全局 Meter 注册自己的指标，定义与业务逻辑共处；基础设施层只提供 MeterProvider 与装配原语，**禁自行调 `SetMeterProvider`**。
- 业务指标一律自定义前缀，禁与 OTel SDK 内置指标（`rpc.server.duration` 等）冲突。

```go
orderCreateTotal.Add(ctx, 1, metric.WithAttributes(
    attribute.String("result", "success"),   // ✅ 有限枚举
    attribute.String("game_id", req.GameId),  // ❌ ID 基数不可控
))
```

---

## 7. body 日志与脱敏【硬】

- **按环境控量**：dev/test 全量 body 便于排查；sand/prod **默认仅 WARN/ERROR 带 body**，正常请求只输出占位（如 `[N bytes]`）。开关在装配时一次性确定，禁运行期动态切换。
- **跨协议统一截断**：HTTP 与 RPC 路径共用同一截断上限常量（由基础设施层统一定义、禁服务侧覆写），超限截断并标记。
- **凭证脱敏**：日志 / body 中的凭证（密码、token、密钥等）由 redactor **自动脱敏**，**不依赖「prod 关 body」兜底安全**；脱敏产出**副本**，禁污染原对象影响下游业务流转。
- 同一字段始终输出（带内容或占位），便于上游按字段过滤；禁明文凭证 / 完整 token 落日志。

---

## 8. 实现边界【硬】

- 可观测性装配封装在**基础设施 / 共享库层**，业务服务不再维护装配代码。
- 禁在统一装配入口之外另起 OTLP 连接、注册 Provider / Propagator、派生级别映射函数。
- 装配原语（provider 构造、字段常量、脱敏、截断、错误码辅助）归基础设施层；**业务指标与业务事件日志归服务自身**。

---

## 9. 留给项目的【软】

以下由各项目按业务 / 规模 / 成本自定，框架不钉死：采样率与采样策略、collector 与后端选型（Jaeger / Tempo / Prometheus / Loki / 云厂商 APM）、具体业务指标集与告警阈值、各 profile（dev/test/sand/prod）的 body-on 与 exporter 开关取值、截断上限的**具体数值**（机制「统一定义、禁覆写」是硬，数值是软）。

---

## 10. 自检清单

- [ ] 三信号一处装配 + 全局注册；无服务在装配入口外自行 `SetTracerProvider` / `SetMeterProvider` / set default logger
- [ ] exporter 全关时进程正常启动，日志走 stdout、`trace_id` 仍输出有效值（本地 provider 常驻）
- [ ] 日志 JSON 含全部必填字段；无 trace 时 `trace_id`/`span_id` 为 `""` 而非字段缺失
- [ ] 业务路径日志均携带 ctx（CI lint 通过）；未逐层透传 logger
- [ ] 级别语义正确（WARN=业务非阻断、ERROR=系统阻断）；状态码→级别单点映射，无调用点局部覆盖
- [ ] 跨进程 `trace_id` 一致；propagator 注册先于下游 client 构造
- [ ] 指标命名 `<domain>_<noun>_<unit>`；**所有 label 基数有限可枚举，无 ID / 完整 URL**
- [ ] prod 仅异常带 body + 跨协议统一截断；凭证自动脱敏且产副本
- [ ] 错误码字段对齐 `api-design` 的 `A-BBB-CCCC`，未另起体系
