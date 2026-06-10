---
name: golang-constraints
description: Whole-lifecycle constraints for Go backend projects — spanning coding, docs, PRD, planning, design, and review; a unified three-layer architecture, no over-abstraction, no transitional schemes, tests subordinate to production design (no wrapping production vars or adding interfaces just for tests — when a mock is needed, prefer an existing low-level injection point). ｜ Go 后端项目全生命周期规范约束：贯穿编码、文档、PRD、规划、设计、review；统一三层架构、禁过度抽象、禁过渡方案、测试服从生产设计（禁为测试包装 var 或新增 interface，需要 mock 时优先用已有低层注入点）。
user-invocable: false
---

# Go 项目规范约束

适用于：Go 后端项目从需求到上线全生命周期内 AI 产出的**所有产出物**（代码 / 文档 / PRD / 规划 / 设计 / review）。

## 0. 触发与跳过

**TRIGGER**：编辑 `.go` / `go.mod` / `go.sum`；编写 Go 项目相关文档 / PRD / 规划 / 设计 / review。
**SKIP**：`vendor/`、代码生成物（`*_gen.go`、protobuf）、非 Go 项目。

---

## 一、核心原则

1. 一致性 > 炫技 ｜ 2. 可维护性 > 抽象性 ｜ 3. 显式 > 灵活 ｜ 4. 现有模式 > 新模式 ｜ 5. 需求未明确时不引入额外设计

- **根源方案 > 过渡方案**：禁止"保留旧 X 兼容""新旧并列""暂时保留"等过渡式写法。
- **一份推荐 > 并列多方案**：任何场景只给一个推荐 + 理由。

**通用禁止**：擅自发明新分层 / 接口抽象 / 第三方依赖；为"优雅""通用性""未来扩展"提前抽象；顺手做未被要求的事。

**默认策略**：最简单直接的实现 / 当前仓库已有模式 / 最少抽象层 / 最少文件改动。

---

## 二、分层契约

### 2.1 允许的分层

`handler` / `service` / `repository` / `model`（或 `entity`）/ `dto` / `config` / `pkg`

**禁止擅自引入**：`manager` / `facade` / `adapter` / `domain` / `application` / `controller`。**`usecase` 一律禁止**。

### 2.2 service 的两种形态

| 形态 | 定位 | 持有的依赖 | 命名倾向 |
|---|---|---|---|
| **领域 service** | 单一领域业务规则 | 只持有**本领域 repository** | 名词：`User` / `Order` |
| **编排 service** | 跨领域流程编排 + 事务一致性 | 多个**领域 service** + `TxManager`；**不持有 repository** | 动词：`Checkout` / `Refund` |

**硬性规则**：
1. 领域 service 不得持有别领域的 repository 或别的 service
2. 事务只能在 service 层发起；handler / repository 禁止
3. 编排 service 必须用 `TxManager.InTx(ctx, fn)` 闭包；事务句柄通过 `ctx` 传递，**不通过方法参数**
4. repository 方法签名禁止显式传 `*sql.Tx` 等事务句柄；从 `ctx` 取
5. 禁止循环依赖：编排 → 领域单向

**何时抽编排 service**：修改 ≥ 2 个领域数据 / 需跨领域事务一致性 / 语义本身是动词流程。

### 2.3 各层职责

| 层 | 允许 | 禁止 |
|---|---|---|
| handler | 参数绑定、调用 service、响应转换 | 写业务逻辑、直接访问 repository |
| service（领域） | 本领域业务规则、调用本领域 repository | 持有别领域依赖、写 SQL、依赖框架对象 |
| service（编排） | 持有多个领域 service + TxManager、编排跨领域事务 | 持有 repository、写业务规则 |
| repository | 数据存取、从 ctx 取事务句柄 | 承载业务规则、返回 `map[string]any` |

### 2.4 目录结构与命名

优先遵守现有结构；若无则用**扁平分层包**：`/internal/{handler,service,repository,config,dto,model,pkg}`，同包按领域拆文件（`user.go` / `order.go`）。不强制拆子包。

**命名贯彻 avoid stuttering——包名已表达的语义不在标识符里重复**：

| 包形态 | 类型名 | 构造函数 | 方法名 |
|---|---|---|---|
| 扁平分层包（多领域共存） | `User` / `Checkout`（不加 Handler/Service 后缀） | `NewUser` / `NewCheckout` | 保留领域词：`CreateUser` / `DoCheckout` |
| 独立单领域包（`config` 等） | `Config` | `New(...)` | 省略领域词：`Load()`（不是 `LoadConfig`） |

**禁止**：`UserHandler` / `NewUserService` / `config.LoadConfig()` / `user_handler.go`。

---

## 三、编码规则

### 3.1 interface

**默认不创建。** 仅允许：已有代码依赖 interface 注入 / 需要 mock 且已有低层注入点无法满足 / 仓库内已有 **≥ 2 个落地实现**。新增前必须列出 ≥ 2 个已落地实现的文件路径。

### 3.2 构造函数与依赖注入

- 独立单领域包 → `New(...)`；扁平分层包 → `NewXxx(...)`（只写领域名）
- 入参 ≥ 3 个 / 含可选项 → **必须用 functional options**
- 依赖注入默认注入具体类型
- 禁止公开字段后置赋值、多套 New 变体

### 3.3 context

请求链路方法**必须**以 `context.Context` 作为第一参数。禁止用 `context.Background()` 替代上游 ctx、把 Web 框架专属 context 传入 repository、把 ctx 存入 struct。

### 3.4 错误处理

必须显式处理；仅在补上下文时用 `fmt.Errorf("...: %w", err)`。禁止 `_` 忽略、无意义包装、`panic` 处理业务错误、多层重复包装。

### 3.5 日志

只记录：关键业务节点 / 外部依赖失败 / 非预期错误。禁止每函数入口打印、正常流程刷屏、记录敏感信息、既返回错误又每层重复打印。

### 3.6 并发

没有明确性能需求时**默认不用**。优先级：`errgroup` > `sync.Mutex` > `channel`。禁止 handler 中裸起 goroutine。

### 3.7 数据库访问

所有 DB 访问收敛到 repository 层。禁止混入第二套访问风格、service 直接写 SQL。

### 3.8 第三方库

默认：标准库 → 项目已有依赖 → 不新增。**官方库优先**（`database/sql`、`net/http` 等）；禁止第三方封装替代。确需新增第三方库时，**必须先向用户说明理由（标准库 / 已有依赖为何不满足、候选库是什么）并获明确同意**，才能写入 `import` 或 `go.mod`；用户主动点名的库视为已同意。涉及版本号遵循 `version-policy` skill。

### 3.9 测试

- 命名：`TestUser_CreateUser`
- **测试服从生产设计，不得反向破坏生产**。需要 mock 时按优先级：
  1. 利用已有低层接口注入点（repository 接口、`http.Client`、外部 SDK 接口）
  2. 重构生产代码补依赖注入
  3. 仅当低层确有 ≥ 2 实现时才在低层加 interface
- **禁止**：为上层包 interface / var monkey-patch（`var timeNow = time.Now`）/ 无断言测试 / 只覆盖 happy path

### 3.10 代码风格

`gofmt` / 命名简洁明确 / 缩小作用域 / 提前 return 减少嵌套 / 单函数单职责。统一用 `any` 替代 `interface{}`。禁止过长函数、过深嵌套、魔法数字。

### 3.11 go mod tidy

每次改 `import` 后**立即**运行 `go mod tidy`。禁止手动编辑 `go.mod` 的 `require` 块。

---

## 四、数据库访问（Go 侧绑定）

### 4.1 UUIDv7 主键

应用层生成 UUIDv7：Go 层 `uuid.UUID` / 接口层 `string`。handler 层做双向转换，service/repository 只接受 `uuid.UUID`。

### 4.2 软删除

软删除标记用 `time.Now().UTC().UnixMicro()` 写入 `deleted` 列。常规查询必须带 `WHERE deleted = 0`。

### 4.3 时间戳

`created_at` / `updated_at` 由 DB 自动管理。禁止 INSERT/UPDATE 显式写、Service 层手动赋值。写入后**必须回读**获取 DB 生成值。

### 4.4 时区

MySQL DSN 固定 `?parseTime=true&loc=UTC&time_zone=%27%2B00:00%27`。Go 用 `time.Now().UTC()`，SQL 用 `UTC_TIMESTAMP(6)`。

---

## 五、跨场景通用约束

以下规则不仅适用于编码，也适用于文档 / PRD / 规划 / 设计 / review：

- 文档 / 代码示例必须满足上述编码规则
- 分层词汇必须与 §二 一致，禁止描述未授权分层
- PRD 行为先行（可测试句式），禁止预指定实现细节
- 规划垂直切分，禁止"先框架后业务"
- 设计必须显式标注事务边界、错误模型；interface 必须列 ≥ 2 实现
- Review 每条建议必须是根源解；发现范围外违规只标注不扩大 diff
- 禁止文档描述未落地的设计、过渡式表述、无时间表的 TODO
