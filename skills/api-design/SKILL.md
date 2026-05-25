---
name: api-design
description: REST API design patterns including resource naming, status codes, pagination, filtering, error responses, versioning, and rate limiting for production APIs.
---

# REST API 设计规范

## 触发场景

设计新 API 端点、审查 API 契约、实现分页/过滤/排序、处理 API 错误、规划版本策略。

---

## 1. URL 结构

- 资源用**复数名词**，kebab-case：`/api/v1/team-members`
- 子资源表达所属关系：`/api/v1/users/:id/orders`
- 非 CRUD 动作谨慎用动词：`POST /api/v1/orders/:id/cancel`
- 禁止：URL 中带动词（`/getUsers`）、单数资源名、snake_case

---

## 2. HTTP 方法与状态码

| Method | 幂等 | 用途 |
|---|---|---|
| GET | 是 | 读取 |
| POST | 否 | 创建、触发动作 |
| PUT | 是 | 整体替换 |
| PATCH | 否* | 部分更新 |
| DELETE | 是 | 删除 |

**成功**：200（GET/PUT/PATCH）、201+Location（POST 创建）、204（DELETE/无 body）
**客户端错误**：400 校验失败、401 未认证、403 无权限、404 不存在、409 冲突、422 语义无效、429 限流
**服务端错误**：500 内部错误（不暴露细节）、502 上游失败、503 暂不可用（带 Retry-After）

禁止：200 包一切（`{"success":false}`）、500 表示校验错误。

---

## 3. 响应格式

**单资源**：直接返回资源对象，禁止 `data` 包装。
```json
{ "id": "abc", "name": "...", "created_at": "..." }
```

**集合（带分页）**：
```json
{
  "items": [...],
  "meta": { "total": 142, "page": 1, "per_page": 20, "total_pages": 8 },
  "links": { "self": "...", "next": "...", "last": "..." }
}
```

**错误**：
```json
{
  "error": {
    "code": "validation_error",
    "message": "Request validation failed",
    "details": [{ "field": "email", "message": "Must be valid", "code": "invalid_format" }]
  }
}
```

---

## 4. 分页

| 场景 | 方式 |
|---|---|
| 后台管理、小数据集 (<10K) | Offset：`?page=2&per_page=20` |
| 无限滚动、大数据集、公共 API | Cursor：`?cursor=xxx&limit=20`（多查一条判断 has_next） |

---

## 5. 过滤、排序、搜索

- **过滤**：`?status=active&price[gte]=10&price[lte]=100`
- **排序**：`?sort=-created_at,price`（`-` 前缀降序）
- **搜索**：`?q=wireless+headphones`
- **稀疏字段**：`?fields=id,name,email`

---

## 6. 认证与授权

- Bearer token：`Authorization: Bearer <token>`
- API key（server-to-server）：`X-API-Key: sk_live_xxx`
- 资源级权限检查 ownership / 角色级检查 RBAC

---

## 7. 限流

响应头：`X-RateLimit-Limit` / `X-RateLimit-Remaining` / `X-RateLimit-Reset`
超限返回 429 + `Retry-After`。

| 层级 | 限额 | 维度 |
|---|---|---|
| 匿名 | 30/min | Per IP |
| 认证用户 | 100/min | Per user |
| 付费 | 1000/min | Per API key |
| 内部服务 | 10000/min | Per service |

---

## 8. 版本策略

推荐 URL 路径版本：`/api/v1/users`。最多维护 2 个活跃版本。

**非破坏性变更**（不需要新版本）：新增响应字段、新增可选参数、新增端点。
**破坏性变更**（需要新版本）：删除/重命名字段、改类型、改 URL 结构、改认证方式。

---

## 9. 上线检查清单

- [ ] URL 命名规范（复数、kebab-case、无动词）
- [ ] 正确 HTTP 方法与状态码
- [ ] 输入校验（schema 验证）
- [ ] 错误响应标准格式
- [ ] 列表端点有分页
- [ ] 认证 + 授权
- [ ] 限流配置
- [ ] 不泄露内部细节（stack trace、SQL 错误）
- [ ] 与既有端点命名风格一致
