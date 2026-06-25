---
name: service-constraints
description: 后端服务运行时治理——启动 fail-fast；优雅生命周期（SIGTERM→排空→超时强退→LIFO 释放）；非幂等写经幂等键；跨进程必设超时、重试仅幂等且退避。触发：启动/关闭、健康检查、写幂等、下游超时/重试、错误传播。跳过：配置载体与密钥分层（→config-constraints）、代码风格（→golang-constraints）、API 契约（→api-design）、可观测性（→observability）。
user-invocable: false
---

# 后端服务工程约束

适用于：后端服务的启动/关闭生命周期、写操作幂等、超时重试、错误传播等**运行时治理**的设计、实现、文档与 review。**原则技术栈无关**，示例用 Go。

> 边界（去耦合，避免重复）：配置载体选择 / 密钥分层 / 热更 fail-safe → `config-constraints`；代码风格 / 三层架构 → `golang-constraints`；对外错误响应格式与 `A-BBB-CCCC` 错误码体系 → `api-design`；日志 / 链路 / 指标 → `observability-constraints`；认证 / 授权 → `auth-constraints` / `authz-constraints`。本 skill 只管它们未覆盖的「服务运行时骨架」。

> 定位：**技术框架定型，钉死「机制骨架」（【硬】必守），不绑「业务策略」（【软】给能力、由项目按业务选）。**

## 0. 触发与跳过

**TRIGGER**：搭建启动/关闭流程、健康检查；实现写操作幂等、下游调用超时/重试；设计 error 传播与边界转码；文档 / PRD / 设计 / review 涉及上述。
**SKIP**：配置载体与密钥分层（→ config-constraints）、纯代码风格/架构（→ golang-constraints）、对外 API 契约（→ api-design）、可观测性信号装配（→ observability）。

---

## 1. 启动校验 fail-fast【硬】

- **单点加载 + 启动校验 fail-fast**：配置在进程启动时一次性加载并校验，缺失/非法即**启动失败**，禁带病运行到首次使用才报错。

---

## 2. 优雅生命周期【硬】

- **启动**：依赖（DB/缓存/下游）就绪前不对外提供服务。
- **健康检查分离**：`liveness`（进程是否活着，挂了重启）与 `readiness`（是否可接流量，未就绪摘流量）**语义分开**，禁混为一个。
- **优雅关闭（收到 SIGTERM）**：停止接收新请求 → **排空在途请求** → 超时上限后强退 → 资源 **LIFO 释放**（在途 → 连接池 → 上报通道）。
- **关闭必须有超时兜底**，禁无限等待在途；释放错误聚合上报、不阻断后续释放。

---

## 3. 写操作幂等【硬】

- 非幂等写（POST 创建、扣款、发消息等）必须支持**幂等键**（`Idempotency-Key`）。
- **首次结果落库 + 重放**：同一幂等键的重复请求**返回首次执行结果**，不重复执行副作用。
- **至少一次投递场景必去重**：MQ 消费、支付回调、客户端重试都可能重复送达，消费侧按业务唯一键/幂等键去重。
- 呼应 `api-design`：`PUT`/`DELETE` 语义天然幂等，`POST` 靠幂等键补齐。

```go
// 幂等键命中已存在记录 → 直接返回首次结果，不重复扣款
if rec, ok := idem.Lookup(ctx, key); ok {
    return rec.Result, nil
}
```

---

## 4. 超时、取消与重试【硬】

- **每个跨进程调用（DB / RPC / HTTP / 缓存）必设超时**，禁无限等待。
- **context 传播 deadline / cancel**：上游超时或取消，向下游透传，及时释放资源（呼应 `observability` 的 ctx 透传）。
- **重试四条件**：指数退避 + 抖动、有次数上限、**仅对幂等操作或带幂等键**、只重试**可重试错误**（超时 / 5xx / `Unavailable`），不可重试错误（4xx / 参数错）直接失败。
- 禁裸重试放大故障（重试风暴）；高频失败下游考虑熔断（fail-fast）。

---

## 5. 错误传播【硬】

- **wrapping 保留链**：`fmt.Errorf("...: %w", err)`，禁 `%v` 断链、禁丢弃原 err。
- **边界层统一转码**：内部 error 在服务边界（handler / 拦截器）统一映射为 `api-design` 的 `A-BBB-CCCC`，**内部传播保留原始 error，禁在底层提前裸抛错误码字符串**。
- **禁吞错误**（`_ = doSomething()` 静默丢弃）；**禁裸 panic 扩散**——拦截器 recover 并转 ERROR（呼应 `observability` 级别语义）。
- 哨兵错误判定用 `errors.Is`、类型提取用 `errors.As`，禁字符串比对 error message。

---

## 6. 留给项目的【软】

框架不钉死，由各项目按业务/规模定：具体超时时长与重试次数/退避参数、健康检查端点路径与就绪判定项、幂等键存储介质（Redis / DB）与 TTL、熔断阈值与策略。

---

## 7. 自检清单

- [ ] 配置启动时单点加载 + 校验 fail-fast
- [ ] liveness 与 readiness 语义分离；未就绪不接流量
- [ ] SIGTERM 优雅关闭：停接收 → 排空在途 → 超时强退 → LIFO 释放，且有超时兜底
- [ ] 非幂等写有幂等键 + 首次结果重放；至少一次投递场景已去重
- [ ] 每个跨进程调用设了超时；context deadline/cancel 向下游传播
- [ ] 重试满足"退避+抖动+上限+仅幂等+仅可重试错误"，无重试风暴
- [ ] error 用 `%w` 保留链、未吞错误；错误码只在边界层转、走 `api-design` 的 `A-BBB-CCCC`
- [ ] 具体超时/重试/健康检查/幂等存储选型已按项目定（框架不替你选）
