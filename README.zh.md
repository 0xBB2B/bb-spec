# BB-Spec

[English](./README.md) | **中文**

> 语言无关的 Claude Code 工作流约束套装：**Go + Vue + bun 技术栈强约束**、**TDD / 反历史包袱铁律**、**多代理本地 review 套件**。

> 产出**跟随你的工作语言**：skill 不硬编码输出语言——文档、注释、commit message 都用你当前的工作语言（标识符 / API 名 / 错误码保持英文）。每个 skill 同时响应中英文触发词。

---

## Claude Code 安装 / Install

在 Claude Code 里执行：

```bash
/plugin marketplace add 0xBB2B/bb-spec
/plugin install bb-spec@0xbb2b
```

或手动添加到 `~/.claude/settings.json`：

```json
{
  "extraKnownMarketplaces": {
    "0xbb2b": {
      "source": { "source": "github", "repo": "0xBB2B/bb-spec" }
    }
  },
  "enabledPlugins": {
    "bb-spec@0xbb2b": true
  }
}
```

## 版本与更新 / Versioning

更新已安装插件：

```bash
/plugin update              # 检查并更新所有已装 plugin
/plugin update bb-spec   # 仅更新本 plugin
```

---

## 默认启用的 Hooks（开箱即用）

| Hook | 触发时机 | 作用 |
|---|---|---|
| `block-non-bun-pm` | PreToolUse(Bash) | 拦截 `npm` / `yarn` / `pnpm` 的包管理动作，强制 `bun`；既有项目已存在匹配 lockfile（如 `package-lock.json`）时放行 |
| `block-main-commit` | PreToolUse(Bash) | 拦截 `main` / `master` 分支的 `git commit` |
| `dep-version-check` | PostToolUse(Write\|Edit) | 编辑依赖文件后注入"先查官方最新版"自检提示 |
| `stop-self-check` | Stop | 任务结束前强制四项自检：临时文件 / 改动范围 / 孤立残留 / 历史包袱 |

---

## 高级选项：可选 Hooks（默认关，按需启用）

仓库还附带两个**副作用较大**的 Stop hook，已随 plugin 一起注册，但脚本顶部有启用门槛，**默认不跑**——必须显式启用：

| Hook | 作用 | 启用方式 |
|---|---|---|
| `stop-auto-tests.sh` | Stop 后在 Go 项目（有 `go.mod`）自动跑 `vet` / `golangci-lint` / `test -race` / `make test-integration`，失败回灌给 AI | `export CLAUDE_ENABLE_AUTO_TESTS=1` 或项目根 `touch .enable-auto-tests` |
| `stop-auto-commit.sh` | Stop 后检测到未提交的已追踪改动，回灌指令让 **AI 用语义化 message 自行 commit**（默认 `git add -u`，非 main/master，不 push） | `export CLAUDE_ENABLE_AUTO_COMMIT=1` 或仓库根 `touch .enable-auto-commit` |

环境变量是会话级 / 全局级启用（写进 shell rc），标记文件是项目级启用，二选一或并用。停用：`unset` 环境变量 或 `rm` 标记文件即可。

---

## 工作流

```
/init  存量项目反向 spec 化（仅首次接入时跑一次；并发分区提取）
  │
  ▼
/spec  需求拆解 → 一规则一文档
  │
  ▼
/plan  spec → 函数级实施计划
  │
  ▼
/exec  三 Agent 隔离执行
  │  Test Agent (Red)   — 只读 spec 规则 → 写测试
  │  Impl Agent (Green) — 只看测试+函数清单 → 写实现
  │  Review Agent       — 对照 spec 检查 → 只读不写
  │  PROGRESS.md 持久化（断点恢复）
  │
  ▼
/review  Workflow 编排：多 finder 并行 + 对抗验证
  │  质量 / 安全 / 反包袱 / 过度设计 / Codex
  │  每条 🔴/🟡 经 3 个独立怀疑视角多数决
  │
  ▼
/git-push-pr  pre-review → 推送 → 开 PR

  ┌────────────────────────────┐
  │  /revise 异常处理（随时介入） │
  │  诊断归因 → 定向修正 → 回归   │
  └──┬──────────┬───────────┬──┘
     ↓          ↓           ↓
   /spec      /exec      /review
  （spec-defect 回 spec，impl-defect 回 exec，review 发现问题回修）
```

被动约束（hooks，自动生效）：拦截 npm/yarn、拦截 main commit、依赖版本自检、stop 四项自检。

---

## Skills 一览（19 个）

### 通用纪律

- **`tdd-workflow`** — 通用 TDD 纪律：Red-Green-Refactor、增/改/删三场景标准流程
- **`version-policy`** — 引入/升级依赖前必须官方渠道查最新版，禁凭训练记忆
- **`git-workflow`** — 分支决策、阶段性 commit、PR 三段式描述、合并后清理
- **`git-push-pr`** — 用户主动触发的多仓库批量/选择性推送 PR 流程
- **`init`** — 存量项目反向 spec 化：阅读现有代码与文档反推规则，按分区并发提取，落点与 `/spec` 完全对齐（仅首次接入时使用）
- **`spec`** — 需求拆解与文档化：一文一规则、≤100 行、输出至 `.bb-spec/docs/spec/`
- **`plan`** — 读取 spec 产出分步实施计划：一文一单元、函数级详细、输出至 `.bb-spec/docs/plan/`
- **`exec`** — 三 Agent 隔离执行 plan（Test→Impl→Review），PROGRESS.md 断点恢复
- **`revise`** — 产出修订（修 bug / 优化 / 需求变更）：三类归因（spec-defect / impl-defect / requirement-change）→ 定向修正 → 回归验证
- **`api-design`** — REST API 设计：资源命名、状态码、分页、错误响应与 `A-BBB-CCCC` 结构化错误码、版本化
- **`database-constraints`** — 关系型数据库约定：应用层生成 UUIDv7 主键、软删除 + 联合 UNIQUE、DB 管理时间戳、全链路 UTC；方言无关原则 + MySQL / PostgreSQL 落地表
- **`auth-constraints`** — 认证与会话（只做 authN）：双 token（access 短期 JWT + refresh 不透明串落库）、强制 refresh 轮换 + 重放检测、滑动续期 + 绝对过期上限、UUIDv4 device_id（UA 仅展示）、argon2id；钉死机制骨架，多设备策略留给项目
- **`authz-constraints`** — 授权（authZ，与 auth-constraints 配对）：默认拒绝 / fail-close、后端必校而前端权限仅 UX、判定集中（禁散落 `if role==`）、两级检查（粗粒度角色/权限 + 细粒度资源 ownership 防 IDOR）、多租户时租户隔离下沉数据层、401/403 语义 + 枚举防护、拒绝审计；钉死机制骨架，权限模型（RBAC/ABAC/ReBAC）/ 策略引擎 / 角色 / 租户模型留给项目
- **`observability-constraints`** — 后端可观测性（日志 / 链路 / 指标）：三信号一处装配 + 全局注册，OTel 为标准、各信号 exporter 可独立开关（本地 provider 常驻保证 trace_id 稳定），JSON 日志带 trace_id / span_id，级别语义（WARN=业务 / ERROR=系统），分布式链路传播，指标命名 + label 基数有限，body 截断 + 凭证脱敏；钉死机制骨架，采样率 / 后端 / 指标 / 告警阈值留给项目
- **`service-constraints`** — 后端服务运行时治理（区别于 golang-constraints）：配置与密钥经 env 注入 + 启动校验 fail-fast（禁硬编码 secret），优雅生命周期（readiness vs liveness、SIGTERM 排空 + LIFO 释放），写操作幂等键，跨进程调用必设超时 + context 取消传播 + 安全重试（退避 / 抖动 / 上限、仅幂等），错误传播保留链（%w）、仅边界层转 api-design 错误码；钉死机制骨架，具体超时 / 重试 / 健康检查 / 配置中心选型留给项目

### Go 后端

- **`golang-constraints`** — Go 项目全生命周期约束：三层架构、禁过度抽象、测试服从生产设计
- **`golang-testing`** — Go 测试组织：table-driven、subtests、benchmark、fuzz

### 前端

- **`vue-constraints`** — Vue 3 + TypeScript + Vite + Tailwind + bun 强约束

### 本地 Review

- **`review`** — 当前分支 vs base：Workflow 编排，5 finder 并行（质量/安全/反包袱/过度设计/Codex 跨模型），每条 🔴/🟡 发现经 3 个独立怀疑视角（重要性/根源性/不修风险）对抗验证、多数决定去留。要求 Claude Code ≥ 2.1.154（Workflow 工具）

---

## 测试

```bash
bash tests/validate.sh
```

校验 126 项结构性规则：agent frontmatter 完整性（必填字段、name 一致性、agent-type 合法值、安全基线段落）、skill SKILL.md 格式、hooks.json 有效性及脚本存在性、plugin.json 字段、个人路径泄露检测。

CI 在 PR 和 push 到 main 时自动运行（`.github/workflows/ci.yml`）。

---

## 推荐配套

### CLAUDE.md 模板

仓库根目录的 [`CLAUDE.template.md`](./CLAUDE.template.md) 是配套的"铁律索引"参考。**不会自动安装**——按需复制到你的 `~/.claude/CLAUDE.md` 或项目根 `CLAUDE.md`，按需裁剪。

### .bb-spec.yaml 项目配置

`/spec` 和 `/plan` 默认输出至 `.bb-spec/docs/spec/`、`.bb-spec/docs/plan/`。在项目根目录创建 `.bb-spec.yaml` 可覆盖基础路径：

```yaml
docs_dir: my/custom/docs  # → my/custom/docs/spec/、my/custom/docs/plan/
```

参考模板：[`.bb-spec.template.yaml`](./.bb-spec.template.yaml)。

---

## Hook 开关速查

| 场景 | 开关 |
|---|---|
| 临时允许 npm / yarn / pnpm | 暂未提供，建议临时禁用 plugin |
| 临时允许 main commit | 同上 |
| 跳过 Stop 自检 | 当前无开关——这是核心铁律，不建议跳过 |
| 启用 stop-auto-tests | `CLAUDE_ENABLE_AUTO_TESTS=1` 或项目根 `.enable-auto-tests` |
| 启用 stop-auto-commit | `CLAUDE_ENABLE_AUTO_COMMIT=1` 或仓库根 `.enable-auto-commit` |

---

## License

MIT
