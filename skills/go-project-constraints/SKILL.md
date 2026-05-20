---
name: go-project-constraints
description: Go 后端项目全生命周期规范约束：贯穿编码、文档、PRD、规划、设计、review；统一三层架构、禁过度抽象、禁过渡方案、测试服从生产设计（禁为测试包装 var 或新增 interface，需要 mock 时优先用已有低层注入点）。
---

# Go 项目规范约束

适用于：Go 后端项目从需求到上线全生命周期内 AI 产出的**所有产出物**。本 skill 聚焦"**不要做什么**"与"**默认做什么**"，是项目纪律的统一来源。

> 核心理念：**一份心智、多场景映射。** 心智模型只描述一次（第一章），各产出物（代码 / 文档 / PRD / 规划 / 设计 / review）只是它在不同表达面上的应用。新增场景时只追加映射，不重复原则。

## 0. 触发场景

**TRIGGER**（命中任一即应应用本约束）：

- 编辑或新增 `.go` 源文件、`go.mod`、`go.sum`
- 编写或修改 Go 项目相关的 `README.md` / 架构文档 / 模块文档 / API 文档 / GoDoc
- 起草 / 评审 Go 项目相关的 PRD、需求拆解、用户故事
- 制定 Go 项目相关的里程碑、路线图、迭代计划、任务拆解
- 进行 Go 项目相关的架构设计、功能设计、接口契约、数据建模、并发/事务方案
- 对 Go 代码或上述任意产出物做 review、给出修改建议或重构方案
- 配置 Go 项目相关的 CI/CD、Lint、测试覆盖、目录脚手架

**SKIP**（以下情况本约束不适用）：

- `vendor/` 目录下的第三方代码
- 代码生成物（含 `//go:generate`、protobuf、mockgen 产物、`*_gen.go`）
- 非 Go 项目，或 Go 仅作为辅助脚本（如一次性数据迁移）的场景

---

## 一、心智模型（所有场景必须服从）

### 1.1 五项核心原则

1. **一致性 > 炫技**
2. **可维护性 > 抽象性**
3. **显式 > 灵活**
4. **现有模式 > 新模式**
5. **保守默认**：需求未明确时不引入额外设计

### 1.2 两条全局纪律

- **根源方案 > 过渡方案**：禁止"保留旧 X 兼容""加注释标记已废弃""新旧并列""暂时保留+后续再处理"等过渡式写法。发现更优做法直接替换，不做兼容妥协。
- **一份推荐 > 并列多方案**：任何场景下输出方案，最终只给一个推荐 + 理由；并列多方案让用户挑选属于推卸决策。

### 1.3 通用禁止项（产出物无论形态一律禁止）

- 擅自发明新的项目结构 / 分层 / 接口抽象 / 第三方依赖
- 为"优雅""通用性""复用""未来扩展"提前抽象或提前引入
- 描述/实现"未来可能" "以后扩展" "先框架后填业务"
- 以"Clean Architecture 更规范""Go 风格""社区常用"作为决策理由
- 顺手做未被要求的事（重构无关代码、升级依赖、改目录结构、抽公共层、把 concrete type 改 interface）

### 1.4 默认策略（需求未明确时）

最简单直接的实现 / 当前仓库已有模式 / 最少抽象层 / 最少文件改动 / 最容易测试的写法。

---

## 二、分层契约（跨场景共享的领域模型）

> 本章是后续所有场景的**词汇表**。代码、文档、PRD、设计稿、规划文案中提到"层"时，必须使用且仅使用以下术语，禁止生造。

### 2.1 允许的分层

`handler` / `service` / `repository` / `model`（或 `entity`）/ `dto` / `config` / `pkg`

### 2.2 禁止擅自引入

`manager` / `facade` / `adapter` / `domain` / `application` / `usecase` / `controller`（项目已用 handler 时禁止混用）。其中 `usecase` 一律禁止（§2.3）；其余除非用户明确要求。

### 2.3 service 的组合与事务

> **跨多领域协作与事务一致性统一由 service 层承担**：单一领域在**领域 service** 内解决；多领域协作 + 事务一致性在 **编排 service** 内解决。

#### 2.3.1 service 的两种形态

| 形态 | 定位 | 持有的依赖 | 命名倾向（软约定） | 示例 |
|---|---|---|---|---|
| **领域 service** | 单一领域的业务规则与数据存取编排 | 只持有**本领域的 repository**（可多个） | 名词 | `User` / `Order` / `Inventory` / `Payment` |
| **编排 service** | 跨多领域的业务流程编排 + 事务一致性 | 持有**多个领域 service** + `TxManager`；**不持有任何 repository** | 动词 / 流程名 | `Checkout` / `Register` / `Refund` / `Onboarding` |

#### 2.3.2 硬性规则

1. **领域 service 不得持有别领域的 repository**。跨领域数据访问 → 新建或使用编排 service。
2. **领域 service 不得持有别的 service**（避免领域间耦合与隐式编排）。跨领域协作一律上移到编排 service。
3. **事务只能在 service 层发起**；handler / repository 一律禁止发起事务。
4. **编排 service 必须用 `TxManager.InTx(ctx, fn)` 闭包模式**管理事务；事务句柄通过 `ctx` 在层间传递，**不通过方法参数**。
5. **repository 方法签名禁止显式传 `*sql.Tx` / `*gorm.DB`**；repo 内部从 `ctx` 取事务句柄，无事务则走默认 DB。
6. **禁止循环依赖**：编排 service → 领域 service 单向；领域 service 之间不互相依赖；领域 service 不能反向依赖编排 service。
7. **命名软约定**：编排 service 倾向动词 / 流程名；名词命名不强制违规，但读者需能在依赖结构中自然识别（"持有多个领域 service + TxManager" 即编排 service）。

#### 2.3.3 事务接口契约

```go
// pkg/tx/tx.go（或沿用项目已有事务包）
package tx

// Manager 在事务中执行 fn;事务句柄通过 ctx 传递,层间透明。
type Manager interface {
    InTx(ctx context.Context, fn func(ctx context.Context) error) error
}
```

- 实现侧（如 gorm / database/sql）在 `InTx` 内把 `*gorm.DB`（tx）或 `*sql.Tx` 塞进 ctx 的自定义 key；
- repository 统一通过 `getDB(ctx)` 这种 helper 取出事务句柄，无事务则回落到默认连接；
- service 互相调用时**只传 `context.Context`**，事务对调用方透明。

#### 2.3.4 何时抽编排 service（判定条件）

满足以下**任一**即抽编排 service，不要塞进某个领域 service：

- 业务流程需要修改 **≥ 2 个领域** 的数据（跨 ≥ 2 个领域的 repository 写操作）
- 业务流程需要 **跨领域事务一致性**（任一步失败要回滚其他领域的写）
- 业务流程的**语义本身是动词/流程**（结账、退款、入职、注册激活、对账等），而非"某领域的操作"

只读的跨领域查询（报表、聚合展示）不强制：简单场景放任一领域 service 即可；复杂的再开编排 service。

#### 2.3.5 禁用理由集合（都不成立）

- 「跨 repo 就该新起一层」→ 同领域多 repo 就在该领域 service 内解决；跨领域才上编排 service，仍在 service 层
- 「Clean Architecture 更规范」→ 一致性 > 炫技
- 「以后业务会复杂」→ 按需演进，现在不预抽象
- 「领域 service 方法太长」→ 先在该领域 service 内拆方法，不是加新层

### 2.4 各层职责一句话定义

| 层 | 允许 | 禁止 |
|---|---|---|
| handler | 参数绑定与基础校验 / 调用 service / 响应转换 / 设置 HTTP/gRPC 状态码 | 写业务逻辑 / 写 DB 逻辑 / 直接访问 repository / 起 goroutine / 拼复杂 SQL |
| service（领域） | 本领域业务规则判断 / 调用本领域 repository（可多个）/ 在单领域内开事务（`TxManager.InTx(ctx, fn)`，内部覆盖本领域多 repo 写操作） | 持有别领域的 repository 或别的 service / 处理 HTTP 细节 / 依赖 `gin.Context` 等框架对象 / 写原始 SQL / 无业务语义的格式转换 |
| service（编排） | 持有多个领域 service + `TxManager` / 用 `TxManager.InTx(ctx, fn)` 闭包编排跨领域事务一致性 / 串联领域 service 调用顺序 / 跨领域 DTO 组装 | 持有任何 repository / 写业务规则（归属领域 service）/ 处理 HTTP 细节 / 反向依赖：领域 service 不得依赖编排 service |
| repository | 数据存取 / 封装 DB 查询 / **从 ctx 中取事务句柄**（有则走 tx,无则走默认 DB）/ 返回明确数据结构 | 承载业务规则 / 依赖 handler 对象 / 返回模糊 `map[string]any`（除非历史已是如此）/ 方法签名显式传 `*sql.Tx` / `*gorm.DB` |
| dto | 输入输出 | 同时承担 DB 模型 |
| model/entity | 内部领域对象或 DB 对象 | 同时承担响应模型 |

### 2.5 目录结构

优先遵守现有结构；若无则使用**扁平分层包**结构：

```text
/internal
  /handler          // 扁平:同一个包内按领域分文件
    user.go         // type User, func NewUser(...), method CreateUser/GetUser/...
    order.go        // type Order, func NewOrder(...), method CreateOrder/GetOrder/...
  /service
    user.go         // type User, func NewUser(...), method CreateUser/GetUser/...
    order.go        // type Order, func NewOrder(...)
  /repository
    user.go         // type User, func NewUser(...), method InsertUser/FindUserByID/...
    order.go        // type Order, func NewOrder(...)
  /config           // 独立单领域包:整个包就代表"配置"领域,只有一个核心类型
    config.go       // type Config, func New(...), method Load/Reload/...(无需 Config 后缀)
  /dto
  /model
  /pkg
/cmd
```

**不强制拆子包**。子包会让 `main` 初始化时 `import` 膨胀（要导 `handler/user`、`handler/order`、`service/user` 一大堆），弊大于利。仅当某个领域**显著独立**（有自己的子类型/子选项/子错误、被跨模块复用）时才拆为独立包（典型例子:`config`、`mailer`、`dbclient`）。

### 2.6 包与文件命名

**文件命名（扁平分层包内）**：

- `handler/user.go` / `service/user.go` / `repository/user.go`
- 按领域拆文件,一个文件一个核心类型
- **禁止带层级后缀**:`user_handler.go` / `user_service.go`(包名已表达层级,后缀冗余)
- **禁止**:`handlerUser.go` / `UserServiceImpl.go` / `userSrv.go` / `user_repo_impl.go`

**类型命名、构造函数、方法**:

| 场景 | 类型名 | 构造函数 | 方法名 |
|---|---|---|---|
| 扁平分层包（`handler/` / `service/` / `repository/` 下多领域共存；`service/` 内还可能同时有领域 service 与编排 service） | `User` / `Order` / `Checkout`（**只写领域名或流程名,不加 `Handler`/`Service` 后缀**） | `NewUser(...)` / `NewOrder(...)` / `NewCheckout(...)` | **保留领域词**:`CreateUser` / `GetUser` / `CreateOrder` / `DoCheckout`（同包内多领域/多流程类型都有 Create/Do,必须用领域或流程词区分语义） |
| 独立单领域包（`config`、`mailer`、`dbclient` 等，整个包只有 1 个核心类型） | `Config` / `Mailer` / `Client` | `New(...)` | **省略领域词**:`config.Load()` / `mailer.Send()`(包名已表达领域,方法名重复就 stutter) |

**核心原则**:贯彻 Go 社区的 **avoid stuttering**——**包名 + 标识符 = 完整语义,任一侧不重复另一侧已有的信息**。

**示例对比**:

```go
// 扁平分层包:类型名与构造函数都省略层级后缀;方法名保留领域词(同包多领域)
// service/user.go
package service
type User struct{ repo *repository.User }
func NewUser(repo *repository.User) *User { ... }
func (s *User) CreateUser(ctx, req) (*dto.UserResp, error) { ... }  // 因 service 里还有 *Order 需 CreateOrder

// 独立单领域包:方法名也省略领域词
// config/config.go
package config
type Config struct{ ... }
func New(path string) (*Config, error) { ... }
func (c *Config) Load() error { ... }      // 不是 LoadConfig
func (c *Config) Reload() error { ... }    // 不是 ReloadConfig
```

**调用处读感**:

```go
h := handler.NewUser(svc)            // *handler.User
s := service.NewUser(repo)           // *service.User
r := repository.NewUser(db)          // *repository.User
cfg, _ := config.New("./app.yaml")   // *config.Config
cfg.Load()                           // 而不是 cfg.LoadConfig()
```

**禁止**:

- 类型名:`UserHandler` / `UserService` / `UserRepository` / `CheckoutUsecase`(后缀重复包名)
- 构造函数:`handler.NewUserHandler` / `service.NewUserService`(同上)
- 独立包里的 stutter 方法:`config.LoadConfig()` / `mailer.SendMail()`
- 反向:在独立单领域包内把类型也省略成领域外层词(如 `config` 包里 `type C struct`)——过度缩略失可读性

例外:仓库历史已使用其他命名风格 → 沿用历史风格,不混用。

---

## 三、场景应用

### 3.1 编码场景（写/改 `.go` 文件）

#### 3.1.1 interface

**默认不创建。** 仅在以下任一情况允许：

1. 已有代码明确依赖 interface 注入
2. 需要单测替身，**且**已有的"低层接口注入点"（被测对象依赖的 repository、`http.Client`、外部 SDK 已暴露接口、time/random 等通过依赖注入的参数）无法满足 mock 需求，**且**项目已有这套模式
3. 存在 **≥ 2 个当前已落地的具体实现**（必须已在仓库中存在，不能是"未来可能"）

**硬性要求**：新增 interface 前必须在改动说明中列出仓库内 ≥ 2 个已落地实现的文件路径与类型名。只能列出 1 个 → 不得新增；等第二种实现真正出现时再重构。

**对测试触发场景额外要求**：以"为测试 mock"为理由新增 interface 时，必须在改动说明中说明"为什么不能在已有低层注入点完成 mock"——例如该层无 interface 注入、外部依赖未通过参数传入。如果答案是"因为上层不持有可替换的依赖" → 这是生产代码缺依赖注入的设计问题，先补依赖注入，**不是**为上层加新 interface。详见 §3.1.10。

依赖注入优先具体类型：

```go
// service/user.go
package service

// 推荐（默认）:扁平分层包,类型名只写领域词(不加 Service 后缀)
type User struct {
    repo *repository.User
}
```

#### 3.1.2 构造函数与依赖注入

**构造函数名按包形态决定**（核心：包名已表达的语义不在构造函数名里重复）：

- **独立单领域包**（包内只 1 个对外类型）→ `New(...)`；调用处读作 `config.New(...)`
- **扁平分层包**（包内多类型，层级语义在包名里）→ `NewXxx(...)`，但 **`Xxx` 只写领域名**，不重复层级后缀

```go
// 独立单领域包 internal/config/config.go
package config
type Config struct{ ... }
func New(path string) (*Config, error) { ... }
func (c *Config) Load() error { ... }       // 不是 LoadConfig —— 包名已表达
// 调用:config.New("./app.yaml") / cfg.Load()

// 扁平分层包 internal/service/user.go
package service
type User struct{ ... }                             // 不是 UserService
func NewUser(repo *repository.User) *User { ... }   // 不是 NewUserService
func (s *User) CreateUser(ctx, req) (*dto.UserResp, error) { ... }  // 方法名保留领域词
// 调用:service.NewUser(repo) → *service.User;svc.CreateUser(ctx, req)

// 同理
// handler/user.go:     func NewUser(svc *service.User) *User  (handler.User)
// repository/user.go:  func NewUser(db *sql.DB) *User         (repository.User)
// service/checkout.go: func NewCheckout(...) *Checkout        (service.Checkout,编排 service)
```

**方法名规则**:

- **扁平分层包(多领域共存)**:方法名**保留领域词**,如 `CreateUser` / `GetUser` / `CreateOrder` / `GetOrder`。因为同包里 `*User` 和 `*Order` 都可能有 "Create"、"Get" 等方法,不带领域词会丢失语义区分
- **独立单领域包(单一核心类型)**:方法名**省略领域词**,如 `config.Load()` / `mailer.Send()` / `dbclient.Query()`。包名已表达领域,`LoadConfig`/`SendMail` 是 stutter

**禁止**：

- `handler.NewUserHandler` / `service.NewUserService` / `repository.NewUserRepo`（后缀重复了包名已表达的层级）
- `config.LoadConfig()` / `mailer.SendMail()`(独立包内方法名 stutter)
- 同一个类型同时存在两套构造（`NewUser()` + `BuildUser()`）
- 构造函数内写复杂逻辑
- 公开字段后置赋值：

```go
// 禁止
svc := &User{}
svc.Repo = repo
```

**Functional Options 模式（多参数/可选项/选实现时的默认姿势）**

入参 ≥ 3 个 / 含可选项 / 需在多种实现间选择时，**必须**使用 functional options。最自然的载体是独立单领域包：

```go
// internal/config/config.go
package config

type Option func(*Config)

func WithLogger(l *slog.Logger) Option      { return func(c *Config) { c.logger = l } }
func WithTimeout(d time.Duration) Option    { return func(c *Config) { c.timeout = d } }
func WithReloadInterval(d time.Duration) Option {
    return func(c *Config) { c.reloadInterval = d }
}

// driver 这种"必填且决定实现选择"的关键参数走位置参数;其余可选走 Option
func New(source string, opts ...Option) (*Config, error) {
    c := &Config{source: source, timeout: 5 * time.Second}
    for _, opt := range opts { opt(c) }
    if err := c.load(); err != nil { return nil, err }
    return c, nil
}
```

调用：

```go
cfg, err := config.New("file://./app.yaml",
    config.WithTimeout(3 * time.Second),
    config.WithLogger(logger),
)
```

**扁平分层包要用 Options 时**，Option 类型名与 With 函数名必须带领域前缀避免同包冲突：

```go
// internal/service/user.go
package service

type UserOption func(*User)
func WithUserCache(c *cache.Cache) UserOption { return func(s *User) { s.cache = c } }

func NewUser(repo *repository.User, opts ...UserOption) *User { ... }
```

**入参 ≤ 2 个且语义清晰**时，直接位置参数（不强行套 Option）：

```go
func NewUser(repo *repository.User) *User { ... }
```

**禁止**：

- 一个类型暴露多个 New 变体（`NewUser` + `NewUserWithLogger` + `NewUserWithTimeout`）→ 用 Option 合并
- 把 Option 放在必填参数位置（例如 `New(opts ...Option)` 但内部却要求必须传某个 `WithDSN`）→ 必填参数走位置参数
- 跨包共享 `Option` 类型（每个包定义自己的 `Option` / `UserOption`，避免选项泄漏与污染）

---

#### 3.1.3 方法命名 avoid stuttering

**同一原则,两种落地**:

```go
// ❌ stutter:包名已表达领域,方法名又带一次
config.LoadConfig()     // config 包,方法带 Config
mailer.SendMail()       // mailer 包,方法带 Mail
client.CloseClient()    // client 包,方法带 Client

// ✅ 正确
config.Load()
mailer.Send()
client.Close()
```

**但扁平分层包必须保留领域词**:`handler.User` 的方法如果写成 `Create`、`Get`、`Update`,同包里 `handler.Order` 也有 `Create`、`Get`,会导致:

1. 代码搜索噪音大(`grep "Create"` 命中所有 handler)
2. 方法值(method value)作为参数传递时不带类型信息难辨识
3. 看到 `svc.Create(ctx, req)` 时需回溯 `svc` 声明才能知道是"创建什么"

因此:

```go
// service/user.go(扁平分层包)
func (s *User) CreateUser(ctx context.Context, req dto.CreateUserReq) (*dto.UserResp, error)
func (s *User) GetUserByID(ctx context.Context, id int64) (*dto.UserResp, error)

// service/order.go(同包)
func (s *Order) CreateOrder(ctx context.Context, req dto.CreateOrderReq) (*dto.OrderResp, error)
```

**判定公式**:

> 方法所在类型**所在的包**是否**只承载这一个领域**?
> - 是(如 `config`、`mailer`) → 方法名**省略领域词**
> - 否(如 `service` 同时有 User/Order) → 方法名**保留领域词**

#### 3.1.3 context

- 请求链路中的 service / repository 方法**必须**以 `context.Context` 作为第一个参数
- 禁止：业务代码用 `context.Background()` 替代上游 ctx / 把 `gin.Context` 直接传入 repository / 把 ctx 存入 struct 字段长期保存

#### 3.1.4 错误处理

- 必须显式处理；禁止用 `_` 忽略
- 只在**补充上下文**时用 `fmt.Errorf("...: %w", err)`
- 禁止：无意义包装（`fmt.Errorf("error: %w", err)`）/ `panic` / `log.Fatal` 处理常规业务错误 / 同一错误在多层重复包装 / 丢失原始错误链

#### 3.1.5 日志

只记录：关键业务节点 / 外部依赖失败 / 非预期错误 / 调试最小上下文。
禁止：每个函数入口都打印 / 正常流程刷屏 / 记录敏感信息（密码、token、完整身份证/银行卡号）/ 既返回错误又在每层重复打印（只在"最终消费错误"的边界打印）。

#### 3.1.6 并发

**没有明确性能需求时，默认不用并发。**
允许条件：用户明确要求 / 已证明是性能热点 / 项目已有固定并发模式。
优先级：`errgroup` > `sync.Mutex` > `channel`。禁止为"Go 风格"强行使用 channel。
禁止：handler 中裸起 goroutine / 忽略 goroutine 生命周期 / 无 ctx 取消控制 / 无错误收集 / 无并发安全说明地共享 map/slice。

#### 3.1.7 数据库访问

- 所有 DB 访问**必须**收敛到 repository 层
- 已有 ORM 则继续 ORM；已有 SQL builder 则继续 SQL builder
- 禁止在同一仓库混入第二套 DB 访问风格
- 禁止：service 直接写 SQL / handler 直接访问 ORM / SQL 拼接散落多层

#### 3.1.8 第三方库

默认：标准库 → 项目已有依赖 → 不新增。
允许新增的唯一情况：用户明确要求 / 仓库已有同类依赖 / 标准库明显无法满足且收益显著。
禁止理由：「代码更短」「更优雅」「社区常用」「我觉得更现代」。

- **官方库优先（强约束）**：SQL 操作使用 `database/sql`、HTTP 操作使用 `net/http` 等 Go 官方标准库；**禁止**引入第三方封装替代官方库的等价能力。
- 涉及版本号选择的依赖引入或升级，遵循 `dependency-version-policy` skill（先查官方最新版本）。

#### 3.1.9 util 包

谨慎创建 `util`/`utils`。只允许**纯通用、无业务语义、复用明确**的函数进入。
禁止塞入：业务逻辑 / 模块特定转换 / repository helper / handler response helper（除非项目已统一如此）。

#### 3.1.10 测试（编码场景的强制纪律）

- 命名统一：`TestUser_CreateUser`、`TestValidateName`（格式 `Test<类型名>_<方法名>`,类型名已省略层级后缀)
- 优先级：service 业务逻辑 → 关键纯函数 → 错误分支 → 边界条件
- **测试服从生产设计，不得反向破坏生产**：测试压力不应成为给生产代码加抽象的理由。需要 mock 时按以下优先级处理，**绝不**跳级：
  1. **第一选择 —— 利用已有的低层接口注入点**：被测对象依赖的 repository 通常已是接口、外部 HTTP 调用走可注入的 `http.Client`、外部 SDK 已暴露 client 接口、time/random/IO 等不确定性应通过参数注入。在这些注入点替换 fake/stub 即可完成 mock，无需动生产侧的抽象层级
  2. **第二选择 —— 重构生产代码补依赖注入**：若上层硬编码持有具体依赖、或不确定性藏在函数体内 → 把依赖改为构造函数参数、把 time/rand/IO 改为方法参数或字段。这是补足缺失的依赖注入，不是为测试加抽象
  3. **第三选择 —— 在低层引入 interface**：仅当低层确实存在 ≥ 2 个已落地实现（满足 §3.1.1 第 3 条），才在该层（如 repository、外部 client）引入 interface
  - **禁止**："为了让 service 好测，给 service 自己包一层 interface" / "为了让 handler 好测，把 service 抽成 interface" / "为了 mock time，加 `var timeNow = time.Now`" / "在被测层之上再叠一个 facade 接口给测试用"
  - **判定问题**：如果有人说"这层没法测，所以要加 interface" → 反问"低层依赖已经能注入吗？没法注入是因为什么？" 95% 的情况答案都是"上层硬编码了具体依赖"——那是依赖注入缺失，先补依赖注入，不是加新接口
- **严禁为了可测试把函数/方法/变量包装成 `var` 以便替换**：

```go
// 禁止：monkey-patch 风格
var timeNow = time.Now
var osExit  = os.Exit
var httpGet = http.Get
var doWork  = realDoWork
var defaultTimeout = 30 * time.Second  // 原本应是 const
```

危害：破坏不变性、制造隐式耦合（污染并行测试与后续用例）、掩盖真正的设计问题（缺失依赖注入）。
**正确做法**：构造函数注入 clock/rand/httpClient；时间、随机、IO 类不确定性做成参数；只有满足 3.1.1 interface 例外条件时才引入接口抽象。

- 禁止：无断言测试 / 只覆盖 happy path / 用超大集成测试代替基础单测 / 为过测试反向修改业务语义 / "函数被调用一次"当通过
- 测试不可达时**先重构实现**（加参数、提纯函数、注入依赖），不要用 `var` 替换或 monkey patch；若重构超出任务范围，先与用户确认

#### 3.1.11 代码风格

必须：`gofmt` / 命名简洁明确 / 缩小作用域 / 提前 return 减少嵌套 / 单个函数职责单一。
禁止：过长函数 / 过深嵌套 / 无说明的魔法数字 / 单字母命名（除短生命周期循环变量）/ 用"聪明写法"替代可读写法。

#### 3.1.12 数据库持久化与字段约定（MySQL）

适用于：所有使用 MySQL 作为主存储的 Go 后端项目。约定层级覆盖**字段类型 / 软删除 / 时间戳 / 时区 / 字符集**五个维度。

##### 3.1.12.1 UUIDv7 主键

业务主键统一使用 **UUIDv7**，跨层映射规则：

| 层 | 类型 |
|---|---|
| Go 业务层 | `github.com/google/uuid` 的 `uuid.UUID` |
| 数据库存储 | `BINARY(16)` |
| Proto / 对外接口 | `string`（标准格式） |

**双向转换约定**：在 **handler 层**完成 `uuid.Parse()`（请求入参 string → uuid.UUID）与 `.String()`（响应出参 uuid.UUID → string）。service / repository 层只接受 `uuid.UUID` 类型，**禁止**透传 string。

##### 3.1.12.2 软删除

所有业务表必须支持软删除：

- 必须包含 `deleted BIGINT NOT NULL DEFAULT 0` 列，`deleted=0` 表示存活
- 删除标记**必须是 UTC 微秒级时间戳**：
  - Go：`time.Now().UTC().UnixMicro()`
  - SQL：`CAST(UNIX_TIMESTAMP(UTC_TIMESTAMP(6)) * 1000000 AS UNSIGNED)`
- 所有 UNIQUE KEY 必须与 `deleted` 列联合：`UNIQUE KEY uk_xxx (原字段, deleted)`
- 常规查询必须显式带 `WHERE deleted = 0`
- **禁止秒级精度的删除标记**（同一秒内的重复软删除会冲突）

##### 3.1.12.3 时间戳自动赋值

`created_at` / `updated_at` 由 MySQL 自动管理：

- 建表 DDL：
  ```sql
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)
  ```
- **禁止**：INSERT / UPDATE SQL 显式写这两列
- **禁止**：Service 层手动赋值这两个字段
- Repository 写入后**必须回读**以获取数据库生成值（写完即查，将 DB 生成的时间戳带回到 Go 结构体）

##### 3.1.12.4 时区统一 UTC

- 数据库 DSN 固定参数：`?parseTime=true&loc=UTC&time_zone=%27%2B00:00%27`
- Go 写入时间使用 `time.Now().UTC()`
- SQL 取当前时间使用 `UTC_TIMESTAMP(6)`
- **禁止**混用本地时区（`time.Now()` 不带 `.UTC()`、`NOW()` / `CURRENT_TIMESTAMP` 不带 `UTC_` 前缀）

##### 3.1.12.5 字符集

建库、建表必须显式声明：

```sql
CREATE DATABASE `xxx` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE TABLE `xxx` (...) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

**不得**依赖 MySQL 实例默认字符集（不同环境默认值可能不同，导致 emoji / 特殊字符插入失败）。

#### 3.1.13 错误码格式

错误码统一为 `A-BBB-CCCC` 格式：

| 段 | 含义 | 取值 |
|---|---|---|
| `A` | 来源类别 | `1` = 用户端错误（参数错误、未授权等）<br>`2` = 系统内部错误（DB 异常、逻辑 bug 等）<br>`3` = 第三方依赖错误（外部 API、消息队列等） |
| `BBB` | 模块号 | 三位数字，按项目模块清单分配 |
| `CCCC` | 模块内错误编号 | 四位数字，模块内单调递增 |

示例：`1-001-0001` = 用户模块的"用户名格式非法"。

- **禁止**自由格式错误码（如 `USER_NAME_INVALID` / `err_001`）
- **禁止**跨模块复用错误码

#### 3.1.14 模块依赖同步（go mod tidy）

每次新增 / 删除 / 修改 `import` 声明（含 `_` 匿名导入、`replace`、`go get` 升降级）后，必须立即在模块根目录运行：

```bash
go mod tidy
```

同步 `go.mod` 与 `go.sum`。**禁止**手动编辑 `go.mod` 的 `require` 块或 `go.sum` 内容。

- **执行时机**：改完 `import` 后**立刻跑**，不要攒到提交前——攒着会让中间的编译 / 测试基于不一致的依赖状态，掩盖问题。
- **提交前自检**：`git commit` 之前必须确认 `go.mod` / `go.sum` 已随源码改动一并 `git add`，禁止出现「`.go` 改了但 `go.mod` 未同步」的脏提交。
- **多模块仓库**：每个含 `go.mod` 的子模块都要**单独**执行；不要在父目录跑指望递归生效。

---

### 3.2 文档输出场景（README / 架构文档 / 模块文档 / GoDoc / API 文档）

- **语言**：必须中文（全局指令）；技术名词、代码标识符保留原文
- **函数/类型注释**：GoDoc 风格（注释以函数/类型名开头），中文描述
- **分层词汇**：必须使用 §2 的术语，禁止描述"manager 层""facade 层"等未授权分层
- **反历史包袱**：
  - 禁止"旧版支持 X，新版不支持 X"且无切换路径的描述 → 直接删除旧版描述
  - 禁止"迁移指南"章节若迁移已完成
  - 禁止"暂时保留 + 后续再处理"措辞
  - 禁止无负责人无时间表的 TODO / 占位
- **代码示例**：必须能 `gofmt`，必须满足 §3.1 全部约束（不得用 var monkey-patch、不得过早抽象 interface 等）
- **不描述未落地的设计**：禁止文档先行写出"未来计划的分层""规划中的接口"——文档只描述当前已存在或本次同步落地的代码
- **API 文档**：错误码必须与 service 返回的错误一一对应；禁止文档列出代码未实现的字段

---

### 3.3 PRD / 需求场景（需求拆解 / 用户故事 / 行为契约）

- **行为先行**：必须先用可测试句式描述行为（"当 X 时，系统应返回 Y / 触发 Z"），再讨论实现路径，与 TDD 衔接
- **禁止预指定过度实现**：需求文档不得出现"用 facade 模式封装""引入 manager 层调度""抽个 interface 方便扩展"等实现绑架
- **领域显式**：需求文档中凡涉及跨实体协作必须点名涉及的领域（User / Order / Inventory / Payment 等）。只涉及 1 个领域 → 实现归该领域 service；涉及 ≥ 2 个领域且需要事务一致性 → 实现阶段应抽编排 service（§2.3）。**任何场景下都禁止引入 usecase 层**。
- **错误路径必写**：每个用户故事必须列出失败/边界情况；只写 happy path 视为不完整
- **延迟决策**：性能、并发、缓存、批处理等优化点未给出量化目标时，归入"非本期"，不进入需求范围

---

### 3.4 项目规划场景（里程碑 / 路线图 / 迭代计划 / 任务拆解）

- **垂直切分优先**：每个里程碑/迭代必须是"端到端可独立验证的行为"（包含 handler + service + repository + 测试）
- **禁止"先框架后业务"**：禁止出现"第一期搭通用基础设施 / manager 层 / 抽象层""第二期填业务"这种规划。基础设施按需在第一个用得上的业务里随附产出
- **禁止以"未来"作为规划依据**："以后可能扩展""未来需要灵活性"不构成本期任务
- **任务粒度**：单个任务必须可在一次提交内完成，且自带验收标准（行为 + 测试）
- **改造任务的根源化**：技术债清理任务必须直接根除，禁止"先标注 + 下一期再改"的过渡安排
- **冻结/发布约束**：涉及发布窗口、合规截止等硬约束时必须显式标注影响面

---

### 3.5 架构设计 / 功能设计场景（设计稿 / 接口契约 / 数据建模 / 事务方案）

- **分层选型**：只允许 handler-service-repository；**禁止引入 `usecase`**。跨领域编排 → 在 `service/` 下新建**编排 service**（命名倾向动词/流程名），持有多个领域 service + `TxManager`，参见 §2.3
- **interface 抽象**：设计稿提出新 interface 必须列出 ≥ 2 个本设计内必然同时落地的实现；只有 1 个 → 删除 interface 章节，改为具体类型
- **事务边界**：设计文档必须显式标注：(a) 事务发起者是哪个 service（领域 service 或编排 service）；(b) `TxManager.InTx` 闭包内覆盖哪些 service / repository 调用；(c) 回滚语义（哪些领域的写会一起回滚）。禁止留白；禁止出现"在 repository 层开事务""handler 里 Begin/Commit"之类写法
- **并发方案**：必须给出性能证据（QPS/延迟目标 + 现状基线）或用户明确诉求；缺一律默认串行
- **DTO / Model / Entity 三分**：设计稿必须分别给出形态；禁止"一个 struct 走天下"
- **依赖选型**：默认标准库 → 项目已有依赖 → 引入新依赖必须在设计稿"取舍"段列出标准库为何不够
- **演进式起点**：禁止"先抽象再演进"；起点必须是最简单可运行
- **错误模型**：必须设计错误分类（业务错误 / 系统错误 / 第三方错误）与 HTTP/gRPC 映射；禁止留作"实现时再说"

---

### 3.6 Code Review / 建议场景

- **根源方案**：每条建议必须是根源解；禁止"先注释标弃 + 下期再改"的过渡建议
- **作用域纪律**：发现现有代码违反红线但不在本次任务范围 → 只标注、不扩大 diff；提示用户单独立项
- **单一推荐**：每个问题给一个推荐改法 + 理由；不并列多方案
- **不顺手做事**：审查中不得提议"顺便重构无关模块""顺便升级依赖""顺便抽公共层"
- **测试评审**：发现 var monkey-patch、无断言、只覆盖 happy path → 直接判失败，必须重写
- **文档与代码同步**：代码改动若使文档失实，review 必须把文档同步纳入同一改动

---

## 四、输出格式（适配不同产出物）

| 产出物 | 格式要求 |
|---|---|
| 代码 | 先 3-6 句改动说明（指出遵循了哪些现有模式）→ 文件级改动；多方案时只保留推荐方案；不留伪代码占位；可直接 `gofmt` |
| 文档 | 三级以内目录 → 章节正文；中文；代码示例满足 §3.1；禁止"过渡式""新旧并列"措辞 |
| PRD/需求 | 先行为契约（可测试句式）→ 边界与错误路径 → 非本期项；不指定实现细节 |
| 规划 | 先目标 → 里程碑（垂直切分）→ 验收标准（行为 + 测试）；禁止"先框架后业务" |
| 设计 | 先目标与约束 → 方案（含分层/接口/事务/DTO/错误模型/依赖选型）→ 验证方法；只给一个推荐 |
| Review | 按文件/段落标注问题 → 给一个推荐改法 + 理由；越权的不在本次改 |

---

## 五、典型反例对比

### 5.1 编码反例：handler 越权写业务

**反例**（`handler/user.go`）：

```go
package handler

func (h *User) CreateUser(c *gin.Context) {
    var req dto.CreateUserReq
    c.ShouldBindJSON(&req)

    if req.Age < 18 {                          // 业务规则写在 handler
        c.JSON(400, gin.H{"error": "未成年"})
        return
    }
    exists, _ := h.repo.ExistsByEmail(c, req.Email)  // 直接访问 repository
    if exists {
        c.JSON(409, gin.H{"error": "邮箱已存在"})
        return
    }
    u := &model.User{Email: req.Email, Age: req.Age}
    h.repo.InsertUser(c, u)
    c.JSON(200, u)
}
```

**正例**：

```go
// handler/user.go
package handler

type User struct{ svc *service.User }
func NewUser(svc *service.User) *User { return &User{svc: svc} }

func (h *User) CreateUser(c *gin.Context) {
    var req dto.CreateUserReq
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(400, gin.H{"error": err.Error()})
        return
    }
    resp, err := h.svc.CreateUser(c.Request.Context(), req)
    if err != nil {
        c.JSON(mapErrStatus(err), gin.H{"error": err.Error()})
        return
    }
    c.JSON(200, resp)
}

// service/user.go
package service

type User struct{ repo *repository.User }
func NewUser(repo *repository.User) *User { return &User{repo: repo} }

func (s *User) CreateUser(ctx context.Context, req dto.CreateUserReq) (*dto.UserResp, error) {
    if req.Age < 18 {
        return nil, ErrUnderAge
    }
    exists, err := s.repo.ExistsUserByEmail(ctx, req.Email)
    if err != nil {
        return nil, fmt.Errorf("check email: %w", err)
    }
    if exists {
        return nil, ErrEmailTaken
    }
    u := &model.User{Email: req.Email, Age: req.Age}
    if err := s.repo.InsertUser(ctx, u); err != nil {
        return nil, fmt.Errorf("insert user: %w", err)
    }
    return dto.FromUser(u), nil
}
```

**要点**：业务规则下沉到 service；handler 只做参数绑定 / 调用 / 响应转换。命名上：
- 类型名省略层级后缀 → `handler.User` / `service.User` / `repository.User`
- 构造函数省略层级后缀 → `NewUser`
- 方法名保留领域词 → `CreateUser` / `InsertUser` / `ExistsUserByEmail`（同包还有 `Order`/`Product` 类型的 `CreateOrder`/`CreateProduct` 需要区分）

### 5.2 编码反例：过早抽象 interface

**反例**（`repository/user.go`）：

```go
package repository

// 只有一个实现却先抽 interface
type User interface {
    InsertUser(ctx context.Context, u *model.User) error
    FindUserByID(ctx context.Context, id int64) (*model.User, error)
}
type mysqlUser struct{ db *sql.DB }
// service 接受 interface,"方便未来切换"
type UserSvc struct{ repo User }  // ← 又为了避免同名冲突违反命名规则
```

**正例**：

```go
// repository/user.go
package repository

type User struct{ db *sql.DB }
func NewUser(db *sql.DB) *User { return &User{db: db} }
func (r *User) InsertUser(ctx context.Context, u *model.User) error { ... }
func (r *User) FindUserByID(ctx context.Context, id int64) (*model.User, error) { ... }

// service/user.go
package service

type User struct{ repo *repository.User }
func NewUser(repo *repository.User) *User { return &User{repo: repo} }
```

**要点**：只有一个实现时不引入 interface；扁平分层包类型名只写领域词（`User`），方法名保留领域词（`InsertUser`）。调用：

```go
repo := repository.NewUser(db)
svc  := service.NewUser(repo)
```

### 5.3 编码正例：跨领域编排统一归 service 层

**反例一**：塞进 OrderService（领域 service 持有别领域 repository）

```go
// service/order.go
type Order struct {
    orderRepo     *repository.Order
    inventoryRepo *repository.Inventory   // ❌ 持有别领域 repo
    paymentRepo   *repository.Payment     // ❌
    tx            tx.Manager
}
func (s *Order) CreateOrder(ctx context.Context, req dto.CheckoutReq) error {
    return s.tx.InTx(ctx, func(ctx context.Context) error {
        s.inventoryRepo.Reserve(ctx, req.Items)   // 库存业务规则外泄到 Order
        s.orderRepo.Insert(ctx, ...)
        s.paymentRepo.Charge(ctx, ...)
        return nil
    })
}
```

**反例二**：领域 service 直接持有别的领域 service

```go
// service/order.go
type Order struct {
    orderRepo    *repository.Order
    inventorySvc *service.Inventory   // ❌ 领域 service 持有别的领域 service
    paymentSvc   *service.Payment     // ❌ 事实上已是编排,但伪装成领域 service
    tx           tx.Manager
}
```

**正例**：新建编排 service（`service.Checkout`，动词/流程名软约定）

```go
// service/checkout.go —— 编排 service:持有多个领域 service + TxManager,不持有 repository
package service

type Checkout struct {
    orderSvc     *Order
    inventorySvc *Inventory
    paymentSvc   *Payment
    tx           tx.Manager
}

func NewCheckout(
    orderSvc *Order,
    inventorySvc *Inventory,
    paymentSvc *Payment,
    txm tx.Manager,
) *Checkout {
    return &Checkout{orderSvc: orderSvc, inventorySvc: inventorySvc, paymentSvc: paymentSvc, tx: txm}
}

// service 包内还有 Register/Refund 等编排 → 方法名保留流程词
func (s *Checkout) DoCheckout(ctx context.Context, req dto.CheckoutReq) (*dto.CheckoutResp, error) {
    var resp *dto.CheckoutResp
    err := s.tx.InTx(ctx, func(ctx context.Context) error {
        if err := s.inventorySvc.ReserveInventory(ctx, req.Items); err != nil {
            return err
        }
        order, err := s.orderSvc.CreateOrder(ctx, req)
        if err != nil {
            return err
        }
        if err := s.paymentSvc.ChargePayment(ctx, order.ID, req.Payment); err != nil {
            return err
        }
        resp = dto.FromCheckout(order)
        return nil
    })
    return resp, err
}

// 领域 service 保持单一职责:只持有本领域 repo,方法签名只接 ctx(事务透明)
// service/order.go
type Order struct{ repo *repository.Order }
func (s *Order) CreateOrder(ctx context.Context, req dto.CheckoutReq) (*model.Order, error) { ... }

// service/inventory.go
type Inventory struct{ repo *repository.Inventory }
func (s *Inventory) ReserveInventory(ctx context.Context, items []dto.Item) error { ... }

// service/payment.go
type Payment struct{ repo *repository.Payment }
func (s *Payment) ChargePayment(ctx context.Context, orderID int64, p dto.PaymentInfo) error { ... }

// repository 侧:从 ctx 取事务句柄,方法签名禁止显式传 tx
// repository/order.go
func (r *Order) Insert(ctx context.Context, o *model.Order) error {
    db := getDB(ctx, r.db)   // ctx 有事务就用事务,没有就走默认 DB
    return db.WithContext(ctx).Create(o).Error
}
```

**要点**：

- 跨领域 = 抽编排 service
- 编排 service 只持有领域 service + `tx.Manager`，**从不直接持有 repository**
- 事务通过 `TxManager.InTx` 闭包发起，句柄经 ctx 在 repo 取出；service 与 repo 的方法签名里都看不到 tx

### 5.4 文档反例：保留过渡式描述

**反例**：

```markdown
## 用户服务

> 旧版（v1）使用 manager 层调度，新版（v2）已迁移至 service 层。
> v1 接口仍暂时保留，待下一版彻底移除。
```

**正例**：

```markdown
## 用户服务

业务编排在 `service/user.go`（`service.User`）；HTTP 协议层位于 `handler/user.go`（`handler.User`）；数据访问位于 `repository/user.go`（`repository.User`）。
```

（说明：v1 已无切换路径就直接删除；保留它会持续诱导新代码继续兼容旧分层。）

### 5.5 规划反例：先框架后业务

**反例**：

```markdown
- M1（第 1-2 周）：搭建通用 manager 框架、抽象基础 interface、统一中间件
- M2（第 3-4 周）：在框架上实现用户注册、登录
```

**正例**：

```markdown
- M1：用户注册端到端（handler + service + repository + 测试）
- M2：用户登录端到端（复用 M1 中沉淀出的真实公共逻辑，不预设抽象）
```

### 5.6 设计反例：预抽象 + 事务留白

**反例（设计文档片段）**：

```markdown
- 抽象 PaymentGateway interface（未来支持多家支付通道）
- 事务边界：实现时再决定
```

**正例**：

```markdown
- 当前仅接入 AlipayClient（具体类型注入），暂不抽 interface;
  接入第二家时再重构为 interface。
- 事务边界:编排 service `service.Checkout.DoCheckout` 发起事务(`TxManager.InTx`),
  闭包内覆盖 `service.Inventory.ReserveInventory` / `service.Order.CreateOrder` / `service.Payment.ChargePayment` 三处调用;
  任一步失败整体回滚,事务句柄经 ctx 传递至各领域 repository。
```

---

## 六、简版硬约束（可作为提示词前缀）

```text
你正在维护一个 Go 后端项目。无论产出物是代码、文档、PRD、规划、设计还是 review，
首要目标都不是"最优雅"，而是"与现有仓库最一致、最稳定、最容易维护"。

通用必须遵守：
1. 默认不新增 interface、第三方依赖、分层
2. 分层只用 handler / service / repository / model / dto / config / pkg;
   **禁止 usecase**。跨多领域协作与事务一致性由 service 层统一承担:
   - **领域 service**:单一领域业务,只持有本领域 repository(可多个);不持有别领域 repo 或别 service
   - **编排 service**(命名倾向动词/流程名 `Checkout`/`Register`/`Refund`):持有多个领域 service + `TxManager`,不持有任何 repository,用 `TxManager.InTx(ctx, fn)` 闭包编排跨领域事务
   - 事务只能在 service 层发起;事务句柄经 `ctx` 传递,repo 方法签名禁止出现 `*sql.Tx`/`*gorm.DB`
3. **扁平分层包 + 按领域拆文件**:`handler/user.go`、`service/user.go`、
   `repository/user.go`;编排 service 同样在 `service/` 下拆文件如 `service/checkout.go`;
   禁止 `user_handler.go` / `UserServiceImpl.go` 等带层级后缀的文件名;不强制拆子包(会让 main import 膨胀)
4. **命名贯彻 avoid stuttering——包名已表达的语义不在标识符里重复**:
   - **独立单领域包**(`config` / `mailer` 等,一个核心类型):类型 `Config`、构造 `New()`、方法 `Load()`(不是 LoadConfig)
   - **扁平分层包**(`handler`/`service`/`repository`,多领域/多流程共存):类型只写领域词或流程词 `User`/`Order`/`Checkout`(不加 Handler/Service 后缀)、构造 `NewUser`/`NewCheckout`、**方法保留领域/流程词** `CreateUser`/`DoCheckout`(同包多类型需区分)
5. **入参 ≥ 3 个 / 含可选项 / 需在多种实现间选择时必须用 functional options**:
   `config.New(path, config.WithTimeout(3*time.Second), config.WithLogger(l))`
6. 依赖注入默认注入具体类型
7. 请求链路方法首参 context.Context
8. 没有性能证据时默认不用并发
9. 错误显式处理,仅在补上下文时包装;同一错误不重复打印
10. 优先复用现有模式;多方案只给一个推荐
11. DTO / Model / Entity 必须分开
12. **测试服从生产设计**:需要 mock 时第一选择是利用已有的低层接口注入点(repository、`http.Client`、外部 SDK 已暴露接口、time/random 注入参数);其次重构生产补依赖注入;只有低层确有 ≥ 2 实现时才在低层加 interface。**禁止**为了让上层好测就给上层包 interface 或 var,也禁止把函数/变量/常量包装成 var 替换
13. 文档使用中文,函数注释 GoDoc 风格
14. 文档/PRD/设计中分层词汇必须与代码层一致

通用禁止:
- 为未来扩展提前抽象、为优雅引入 interface、为 Go 风格强用 channel
- handler 写业务、service 写 SQL、repository 返回 HTTP DTO
- util 当杂物堆;输出多并行方案让用户选
- 重构无关代码、顺手升级依赖、顺手改目录
- 为凑测试改业务语义或写无断言测试
- 过渡式写法:"保留旧 X 兼容""标记已废弃""新旧并列""暂时保留 + 后续再处理"
- 文档/规划描述未落地的设计或"先框架后业务"

输出前先用 3-6 句话说明实现/方案思路,并明确指出遵循了哪些现有模式。
```
