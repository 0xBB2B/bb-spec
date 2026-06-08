---
name: authz-constraints
description: Authorization constraints (authZ — the companion to auth-constraints' authN) for backend services — deny by default / fail-close; the backend always enforces while frontend permission gating is UX only (never trusted); centralized policy decision (no scattered `if role==`); two-tier checks = coarse role/permission at the edge + fine-grained resource ownership in the service layer (middleware can't stop horizontal / IDOR escalation); tenant isolation enforced at the data layer when multi-tenant; 401-vs-403 semantics with an existence-enumeration guard, error codes via api-design's A-BBB-CCCC; authorization denials and sensitive actions audited via observability. Pins the mechanism skeleton (hard) while leaving the permission model (RBAC / ABAC / ReBAC), policy engine (homegrown / Casbin / OPA), concrete roles & permission points, and tenancy model to each project (soft). Principles are stack-agnostic; examples use Go + SQL. TRIGGER when designing / implementing permission checks, role / permission models, resource ownership, multi-tenant isolation, admin gating, or any authZ-related endpoint / middleware / doc / review. ｜ 后端服务授权约束（authZ，与 auth-constraints 的认证 authN 配对）——默认拒绝 / fail-close；后端必校、前端权限仅 UX（不可信）；授权判定集中（禁散落 `if role==`）；两级检查 = 入口粗粒度角色/权限 + service 层细粒度资源 ownership（中间件拦不住横向越权 / IDOR）；多租户时租户隔离在数据层强制；401/403 语义 + 存在性枚举防护、错误码走 api-design 的 A-BBB-CCCC；授权拒绝与敏感操作经 observability 审计。钉死机制骨架（硬），把权限模型（RBAC/ABAC/ReBAC）、策略引擎（自研/Casbin/OPA）、具体角色与权限点、租户模型留给项目（软）。原则技术栈无关，示例用 Go + SQL。TRIGGER：设计/实现权限校验、角色/权限模型、资源归属、多租户隔离、管理员鉴权，或任何 authZ 相关端点/中间件/文档/review。
user-invocable: false
---

# 授权约束（authZ）

适用于：后端服务的权限校验、角色/权限模型、资源归属、多租户隔离等授权相关的设计、实现、文档与 review。**接在 `auth-constraints`（认证 authN）之后**——authN 确认「你是谁」，本约束判定「你能不能做这件事」。**原则技术栈无关**，示例用 Go + SQL。

> 定位：**技术框架定型，钉死「机制骨架」（【硬】必守），不绑「业务策略」（【软】给能力、由项目按业务选）。**

## 0. 触发与跳过

**TRIGGER**：设计/实现权限校验、角色或权限模型、资源 ownership、多租户隔离、管理员/后台鉴权；文档 / PRD / 设计 / review 涉及"谁能访问什么"。
**SKIP**：身份认证与会话（属 `auth-constraints`）、纯公开资源（无访问控制）、与权限无关的业务逻辑。

---

## 1. 默认拒绝 / fail-close【硬】

- **无显式授权即拒绝**：新端点默认视为「需授权」，必须显式声明放行规则才可访问；漏配的后果是拒绝，不是放行。
- **策略加载/判定异常时拒绝**：权限数据查不到、策略引擎报错、规则缺失 → **fail-close**（拒绝），禁 fail-open（出错就放行）。

---

## 2. 后端必校，前端权限仅 UX【硬】

- 前端按角色隐藏菜单/按钮**只是体验优化**，**禁作为安全边界**。后端对**每个**敏感操作独立校验，不依赖"前端没显示这个按钮"。
- **判定主体只信服务端会话**：authZ 的 subject 取自 authN 验证过的会话身份（`user_id` 等），**禁采信前端请求体里自称的 `role` / `is_admin` / `user_id`**——这些一律视为不可信输入。

---

## 3. 集中决策【硬】

- 授权判定走**统一 enforcer / policy 层**，禁业务代码里散落 `if user.Role == "admin"`、`if user.ID == owner`。
- 判定入参标准化为 **(subject, action, resource, context)** 四元组，规则集中定义、单点维护——同 `observability` 的"级别映射单点维护"。

```go
// ✅ 集中判定
if err := authz.Enforce(ctx, sub, "order:delete", order); err != nil {
    return err // 统一返回 403 错误码
}
// ❌ 业务代码散落角色判断，规则漂移、漏点难查
if sub.Role != "admin" && sub.ID != order.OwnerID { ... }
```

---

## 4. 两级检查【硬】

授权必须同时覆盖两个粒度，缺一不可：

| 粒度 | 校验内容 | 位置 | 漏掉的后果 |
|---|---|---|---|
| **粗粒度** | 角色/权限：有没有「删除订单」这个能力 | 入口中间件 / 拦截器 | 越权调用受限接口 |
| **细粒度** | 资源 ownership：**这一单**是不是你的 / 在你租户内 | **service / 数据层**（中间件拿不到具体资源） | **横向越权（IDOR）**——有权限但操作了别人的数据 |

> 核心提醒：中间件只能拦"有没有这类权限"，拦不住"操作了不属于你的那一个"。**ownership 必须在取到资源后、在业务/数据层显式校验**。

---

## 5. 多租户隔离【硬 · 条件适用】

仅当系统是多租户（SaaS）时适用，但一旦适用即为硬约束：

- **租户边界贯穿全链路**：`tenant_id` 从会话身份带入，所有数据访问**强制带租户过滤**。
- **过滤下沉到数据层默认作用域**：在 repository / ORM 全局 scope 强制 `WHERE tenant_id = ?`，**禁靠每个 handler 记得手写 `if`** 兜底（漏一个就跨租户泄露）——同 `database-constraints` 软删除"所有查询带 `deleted = 0`"的思路。
- 跨租户访问一律视为**越权**，按 403 处理并审计。

```sql
-- 任何业务查询都必须带租户与软删除双过滤
SELECT * FROM orders WHERE tenant_id = ? AND deleted = 0 AND id = ?;
```

---

## 6. 错误语义与枚举防护【硬】

- **401 vs 403**：未认证 → `401`（属 authN）；已认证但无权 → `403`。错误码并入 `api-design` 的 `A-BBB-CCCC`，**禁另起体系**。
- **不泄露内部细节**：拒绝响应禁回显"因缺少 `xxx` 权限"等内部规则；对**敏感资源**可用 `404` 替代 `403`（假装不存在）以**防存在性枚举**——`403`/`404` 的取舍是【软】，由项目按资源敏感度定。

---

## 7. 授权审计【硬】

- **拒绝必记**：授权拒绝（403）与**敏感/高危操作**（提权、删除、跨租户、后台操作）落结构化日志，对齐 `observability-constraints`。
- 字段含 `subject` / `action` / `resource` / `decision` / `reason`；授权拒绝用 **WARN**（业务非阻断），不污染 ERROR 告警。
- **禁只记成功不记拒绝**——拒绝日志才是越权排查与告警的关键。

---

## 8. 实现边界【硬】

- 授权判定封装在**统一中间件 / enforcer**，业务侧只**声明**「这个操作需要什么权限」，不自己实现判定逻辑。
- 权限点 / 规则**集中定义**，禁字面量散布在各 handler。
- 授权依赖 authN 的产出（会话身份）、产出审计交给 observability、错误码用 api-design——**不重复造**。

---

## 9. 留给项目的【软】

框架不钉死，由各项目按业务定：

- **权限模型**：RBAC（角色，**推荐起步**，最普适）→ 需要细到属性/条件时升 ABAC → 需要复杂关系（组织树、共享）时用 ReBAC（Zanzibar 风格）。
- **策略引擎**：自研 / Casbin / OPA（OpenPolicyAgent）等，由规模与复杂度决定。
- **具体角色、权限点清单、角色-权限映射**。
- **租户模型**：是否多租户、隔离粒度（共享库带 `tenant_id` / 独立 schema / 独立库）。

---

## 10. 自检清单

- [ ] 默认拒绝：新端点未显式放行即不可访问；策略/数据异常时 fail-close
- [ ] 后端对每个敏感操作独立校验；subject 取自服务端会话，未采信前端自称的 role/id
- [ ] 授权判定集中在 enforcer，无业务代码散落 `if role==` / `if id==owner`
- [ ] 粗粒度（角色/权限）+ 细粒度（**资源 ownership**）两级都覆盖，无 IDOR 横向越权
- [ ] 多租户（如适用）：`tenant_id` 强制过滤下沉数据层默认作用域，非逐 handler 手写
- [ ] 未认证 401 / 无权 403；错误码走 `api-design` 的 `A-BBB-CCCC`；敏感资源已决定 403/404 策略
- [ ] 授权拒绝 + 敏感操作有审计日志（WARN，含 subject/action/resource/decision），对齐 `observability`
- [ ] 权限模型 / 策略引擎 / 角色定义已按业务明确选定（框架不替你选）
