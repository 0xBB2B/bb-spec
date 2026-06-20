---
name: database-constraints
description: 关系型数据库 schema 与访问约定——UUIDv7 应用层主键；`deleted` 微秒时间戳软删 + UNIQUE 联合；created_at/updated_at 由 DB 管理；全链路 UTC。触发：编写/修改 .sql、migration、DDL；设计表结构或数据模型。跳过：非关系型存储（Redis/MongoDB/ES）、不动 schema 的查询调优、代码生成物。
user-invocable: false
---

# 数据库规范约束

适用于：关系型数据库的表结构设计、migration / DDL 编写，以及文档 / PRD / 设计 / review 中涉及数据模型的部分。只约束 DB 侧，语言无关。

## 0. 触发与跳过

**TRIGGER**：编写 / 修改 `.sql`、migration 文件、DDL；设计表结构 / 数据模型；文档 / PRD / 设计 / review 涉及持久层 schema。
**SKIP**：非关系型存储（Redis / MongoDB / ES 等）、不动 schema 的纯查询调优、代码生成物。

---

## 一、通用原则（方言无关）

1. **主键 = 应用层生成的 UUIDv7**：时间有序、利于索引局部性。禁止 DB 端生成主键、禁止自增 ID 对外暴露。
2. **软删除**：`deleted BIGINT NOT NULL DEFAULT 0`，删除标记 = UTC 微秒时间戳。**所有 UNIQUE KEY 必须与 `deleted` 联合**；常规查询必须带 `WHERE deleted = 0`。
3. **时间戳由 DB 管理**：`created_at` / `updated_at` 由数据库自动维护。禁止 INSERT / UPDATE 显式写入、禁止应用层手动赋值；写入后**必须回读**获取 DB 生成值。
4. **全链路 UTC**：连接会话、SQL 函数、应用层取时三处统一 UTC，禁止依赖服务器本地时区。
5. **显式字符集**：建库建表显式声明，禁止依赖实例默认配置。

**禁止的软删除变体**：`is_deleted BOOL`（同一自然键只能软删一次，第二次撞联合 UNIQUE）/ `deleted_at DATETIME NULL`（NULL 不参与唯一性比较，活跃行约束失效）。必须用非空微秒时间戳整型。

---

## 二、方言落地

| 约定 | MySQL | PostgreSQL |
|---|---|---|
| UUIDv7 主键列 | `BINARY(16)` | `uuid` |
| 时间戳列 | `DATETIME(6)` | `timestamptz(6)` |
| created_at | `DEFAULT CURRENT_TIMESTAMP(6)` | `DEFAULT now()` |
| updated_at | `DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)` | `moddatetime` trigger（见下） |
| 会话时区 | `time_zone = '+00:00'` | `TimeZone = 'UTC'` |
| SQL 取当前 UTC | `UTC_TIMESTAMP(6)` | `now()`（`timestamptz` 存储即瞬时值） |
| 字符集 | 库表声明 `utf8mb4` + `utf8mb4_0900_ai_ci` | 建库声明 `ENCODING 'UTF8'` |

**PostgreSQL 维护 updated_at**（PG 无 `ON UPDATE` 等价物，统一用 contrib 扩展 `moddatetime`）：

```sql
CREATE EXTENSION IF NOT EXISTS moddatetime;
CREATE TRIGGER set_updated_at BEFORE UPDATE ON <table>
  FOR EACH ROW EXECUTE FUNCTION moddatetime(updated_at);
```

---

## 三、建表示例（MySQL）

```sql
CREATE TABLE user (
  id         BINARY(16)   NOT NULL,
  email      VARCHAR(255) NOT NULL,
  deleted    BIGINT       NOT NULL DEFAULT 0,
  created_at DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  UNIQUE KEY uk_email (email, deleted)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```
