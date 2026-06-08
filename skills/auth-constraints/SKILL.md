---
name: auth-constraints
description: Authentication & session constraints (authN only, not authZ) — dual-token mechanism with short-lived JWT access tokens and opaque server-side refresh tokens; mandatory refresh rotation (in-place single-row update) with replay detection, a grace window for network retries, and leak-triggered chain revocation; sliding expiry with an explicit session-max-lifetime decision (a cap, or none = active-forever); client-generated UUIDv4 device_id with UA parsed for display only (never for security decisions); argon2id password hashing; tokens carried via Bearer header, stored in localStorage / native secure storage. Pins the mechanism skeleton (hard constraints) while leaving business policy — multi-device vs single-device-kickout vs N-device-cap — to each project (soft). Session tables follow database-constraints; auth error codes follow api-design's A-BBB-CCCC. TRIGGER when designing/implementing login, token issuance/refresh/validation, session or device management, password storage, logout/revocation, or any auth-related endpoint or frontend request layer. ｜ 认证与会话机制约束（只做认证 authN，不含授权 authZ）——双 token：access 用短期 JWT、refresh 用不透明串落库；强制 refresh 轮换（原地更新单行）+ 重放检测 + 网络重试宽限窗口 + 泄露吊销整链；滑动续期，会话最长寿命由项目显式决策（设上限或不设 = 活跃即永久）；device_id 用客户端生成的 UUIDv4，UA 仅解析用于展示、禁做安全判定；密码用 argon2id；token 经 Bearer 头传输、存于 localStorage / 原生安全存储。钉死机制骨架（硬约束），把业务策略——多设备并存 / 单设备互踢 / 限 N 台——留给各项目（软约束）。会话表遵循 database-constraints，认证错误码并入 api-design 的 A-BBB-CCCC。TRIGGER：设计/实现登录、token 签发/刷新/校验、会话或设备管理、密码存储、登出/吊销，或任何认证相关端点与前端请求层。
user-invocable: false
---

# 认证与会话约束（authN）

适用于：登录/登出、token 签发与校验、会话与设备管理、密码存储等认证相关的设计、实现、文档与 review。**只做认证（authN），不含授权（authZ）**——RBAC / 资源 ownership / 权限模型不在本约束范围。

> 定位：**技术框架定型，钉死「机制骨架」（【硬】必守），不绑「业务策略」（【软】给能力、由项目按业务选）。**

## 0. 触发与跳过

**TRIGGER**：实现/设计登录注册、token 签发/刷新/校验、会话或设备管理、密码哈希、登出/吊销；前端请求层的 token 携带与自动刷新；文档 / PRD / 设计 / review 涉及认证。
**SKIP**：授权/权限判定（authZ）、纯第三方 SSO 托管（不自管会话）、与认证无关的业务端点。

---

## 1. 双 token 机制【硬】

| token | 形态 | TTL | 内容 / 落库 |
|---|---|---|---|
| **access** | **JWT**（无状态、不查库） | **5–15min**【软取值】 | 最小 claim：`sub`(user_id)、`device_id`、`jti`、`iat`、`exp`；禁塞敏感信息 |
| **refresh** | **不透明随机串**（≥256 bit） | **7–30d**【软取值】 | 落库，且**只存哈希**（如 SHA-256），禁存明文 |

- **滑动续期【硬机制】**：每次用 refresh 刷新时把 `expires_at` 顺延到 `now + refresh TTL`。只要用户活跃间隔 < refresh TTL，会话滚动有效。
- **会话最长寿命【硬决策 / 软取值】**：项目必须就「会话是否设绝对上限」**显式决策**，框架不替你选、但禁糊里糊涂：
  - 设上限 → `absolute_expires_at` = 首次登录起最长寿命（如 30–90d），与滑动续期**取先到**，到点强制重登。
  - 显式不设（`absolute_expires_at` 留空）→ **活跃即永久**，活跃用户永不被动踢出（消费级常见）。此时**必须**靠 rotation + 重放检测（第 2 节）兜泄露——长期有效的 refresh 被盗后才可被察觉并吊销。

---

## 2. refresh 会话落库 + 轮换【硬】

- **一行 / 会话，原地更新**：一个 `(user_id, device_id)` 登录会话**就是一行**。rotation = 在**同一行**上把 `refresh_token_hash` 换新、`expires_at` 顺延，**禁插新行**——表大小 = 活跃设备数，与刷新次数无关。
- **轮换 + 宽限窗口 + 泄露吊销**：保留上一个 token 哈希（`prev_token_hash`）以容错网络重试 / 并发。收到 refresh，比对哈希分三种：

| 命中 | 判定 | 动作 |
|---|---|---|
| = `refresh_token_hash`（current） | 正常刷新 | `prev ← current`、`current ← 新`、`rotated_at ← now`、顺延 `expires_at`，返回新 token 对 |
| = `prev_token_hash` 且 `now - rotated_at ≤ 宽限窗口`（如 30–60s【软取值】） | 网络重试 / 并发，非攻击 | 幂等放行、签发可用 token，**不踢人** |
| 两者都不命中，或 = prev 但超窗口 | 真重放 / 泄露 | 吊销该 `(user_id, device_id)` 全部会话（置 `deleted`） |

- 会话表遵循 `database-constraints`（UUIDv7 主键、`deleted` 软删除、DB 管理时间戳、全链路 UTC）。`deleted != 0` 表达会话**作废/登出/吊销**；有效会话 = `deleted = 0 AND now < expires_at AND (absolute_expires_at IS NULL OR now < absolute_expires_at)`。

```sql
CREATE TABLE auth_session (
  id                  BINARY(16)   NOT NULL,             -- UUIDv7（应用层生成）
  user_id             BINARY(16)   NOT NULL,
  device_id           BINARY(16)   NOT NULL,             -- 客户端生成的 UUIDv4
  refresh_token_hash  BINARY(32)   NOT NULL,             -- 当前有效 refresh 哈希（原地更新，禁存明文）
  prev_token_hash     BINARY(32)   NULL,                 -- 上一个 refresh 哈希，配合宽限窗口容错
  rotated_at          DATETIME(6)  NULL,                 -- 上次轮换时间，判是否在宽限窗口内
  user_agent          VARCHAR(512) NULL,                 -- 仅展示用，禁做安全判定
  expires_at          DATETIME(6)  NOT NULL,             -- 滑动过期
  absolute_expires_at DATETIME(6)  NULL,                 -- 会话最长寿命；NULL = 不设上限（活跃即永久）
  deleted             BIGINT       NOT NULL DEFAULT 0,   -- 作废/登出/吊销，UTC 微秒
  created_at          DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at          DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  UNIQUE KEY uk_refresh (refresh_token_hash, deleted),
  KEY idx_user_device (user_id, device_id, deleted)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

---

## 3. 设备识别【硬机制】

- `device_id` = **客户端首次启动生成的 UUIDv4**，持久化（Web 存本地、移动端存原生存储），每次刷新随 refresh 绑定上送。
- **UA 仅解析用于「展示」**（给用户看「Chrome on macOS」），**禁用于任何安全判定**——UA 正被浏览器精简（UA Reduction）且易伪造/雷同。

---

## 4. 多设备策略【软 — 项目自选】

同一套 `auth_session` 机制天然支持三种策略，skill 给能力、**不强制选哪种**：

| 策略 | 实现（同一套机制） |
|---|---|
| 多设备并存 | 每 `(user_id, device_id)` 一条有效会话，互不影响 |
| 单设备互踢 | 新登录时把该 user 其余会话 `deleted` 掉 |
| 限最多 N 台 | 登录时统计有效会话数，超 N 删最旧 |

---

## 5. 密码与登录凭证【硬下限】

- **哈希用 argon2id**：推荐 `m=19456 KiB, t=2, p=1` 起步【软参数，按硬件压测调】；**禁明文 / MD5 / SHA1 / 无盐快速哈希**。
- **登录失败限流 / 锁定【硬机制】**：失败计数 + 退避或锁定防爆破，阈值与策略【软】由项目定。

---

## 6. token 传输与存储【硬】

- **传输**：`Authorization: Bearer <access>`（对齐 `api-design`）；refresh 仅在专用刷新端点提交，禁随业务请求广播。
- **存储**：Web = `localStorage`、移动端 = Keychain / Keystore 等原生安全存储；**禁把明文 token 写日志 / URL query**。

---

## 7. 前端刷新流程【硬机制】

1. access 放运行时内存，请求拦截器附加 `Authorization: Bearer <access>`。
2. 响应 `401`（access 过期）→ 调刷新端点用 refresh 换新 token 对 → 重放原请求。
3. **并发 single-flight**：多个请求同时 401 只发起**一次**刷新，其余复用同一刷新结果，禁并发打爆刷新端点。
4. 刷新失败（refresh 也失效）→ 清本地凭证 → 跳登录。

---

## 8. 登出与吊销【硬机制 / 软范围】

| 操作 | 实现 |
|---|---|
| 单设备登出 | 当前会话 `deleted` |
| 全端登出 | 该 user 所有会话 `deleted` |
| 管理员踢出 | 指定会话 / 用户 `deleted` |

> **JWT access 的取舍**：access 无状态，吊销后仍有效至自然过期（≤ access TTL），靠**短 TTL** 收敛窗口。如需即时吊销 access，需另上 `jti` 黑名单——本框架默认不做，需要时项目自行扩展。

---

## 9. 错误码【硬】

认证类错误**归入一个模块号**，统一走 `api-design` 的 `A-BBB-CCCC`，**禁另起体系**。模块号 `BBB` 由项目按 `api-design` 分配（下表占位 `0xx`）：

| 场景 | HTTP | code 示例 |
|---|---|---|
| access 过期 | 401 | `1-0xx-0001` |
| token 签名无效 | 401 | `1-0xx-0002` |
| refresh 失效 / 已轮换 / 重放 | 401 | `1-0xx-0003` |
| 设备不匹配 | 401 | `1-0xx-0004` |
| 账号或密码错误 | 401 | `1-0xx-0005` |
| 登录失败过多 / 锁定 | 429 | `1-0xx-0006` |

> 错误响应禁泄露内部细节（是否存在该账号、stack trace 等）。

---

## 10. 自检清单

- [ ] access=JWT 短期（5–15min、最小 claim）；refresh=不透明串落库且只存哈希
- [ ] 滑动续期；已就会话最长寿命显式决策（设上限值，或显式不设 = 活跃即永久）
- [ ] refresh 轮换 = 原地更新同一行（不插行）；prev_token_hash + 宽限窗口容错网络重试；超窗口重放 → 吊销整链
- [ ] 会话表遵循 `database-constraints`（UUIDv7 / `deleted` 软删除 / DB 时间戳 / UTC）
- [ ] device_id 用客户端 UUIDv4；UA 仅展示、未做安全判定
- [ ] 多设备策略已按业务明确选定（机制不替你选）
- [ ] 密码用 argon2id；有登录失败限流/锁定
- [ ] token 经 Bearer 头传输；未写入日志 / URL；前端刷新 single-flight
- [ ] 认证错误码并入 `api-design` 的 `A-BBB-CCCC`，未另起体系
