# BB-Spec

[English](./README.md) | **中文**

> 以 **spec-driven 工作流为核心**的语言无关 Claude Code 套装——`spec → plan → exec → review → revise → git-push-pr` 是主流水线，辅以**配套技术栈约束套件**（Go / Vue + bun / TDD / Git 纪律）与**多代理对抗式 review 套件**。

> 产出**跟随你的工作语言**：skill 不硬编码输出语言——文档、注释、commit message 都用你当前的工作语言（标识符 / API 名 / 错误码保持英文）。每个 skill 同时响应中英文触发词。

---

## 核心：Workflow 工作流（`spec → ship`）

> **这是 BB-Spec 的核心价值。** 一条闭环、spec 驱动的流水线，把模糊需求一路带到经过 review、可交付的代码——每个阶段都可追溯、可断点恢复、经对抗验证。下方三个约束套件（core / backend / frontend）是**配套**，向这条流水线灌入规则；流水线本身才是主角。

```
/init  存量项目反向 spec 化（仅首次接入时跑一次；并发分区提取）
  │
  ▼
/spec  需求拆解 → 一规则一文档
  │
  ▼
/plan  spec → 函数级实施计划（大需求自动分批 ROADMAP + 懒生成）
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

**它们如何衔接。** 这条流水线是一场接力，而每一次交接物都是**磁盘上的文档**、不是会话里的临时记忆——这正是它能断点续、能换个 AI 接手、能逐级追溯的根本：`/spec` 把模糊需求落成 `.bb-spec/docs/spec/` 下的 spec 文档（**做什么**）→ `/plan` 读这些 spec、产出 `.bb-spec/docs/plan/` 下的函数级计划（**怎么做**；大需求自动切分批路线图 ROADMAP，一次只展开当前批，逐批验证门通过后再生成下一批）→ `/exec` 拿 plan 走 Test→Impl→Review、产出测试 + 代码、进度写入 `PROGRESS.md` → `/review` 审最终 diff → `/git-push-pr` 对照 spec 自查后开 PR。

两条支线让它闭环：**`/init`** 是存量项目的*入口匝道*——先反向推导出 spec，再汇入主线；**`/revise`** 是*回头路*——任何偏差都按根因把你送回**正确的那一步**（spec 缺陷 → `/spec`，实现偏离 → `/exec`），而非无脑重跑。

每个阶段，以及它的差异化所在：

- **`/init`** — *反向* spec 化存量项目：阅读现有代码 + 文档，把**已在执行的隐式规范**提炼成 ≤100 行、一文一规则的 spec，落点与 `/spec` 完全一致，让后续环节直接接力。庞大项目按分区拆 subagent 并发提取。仅首次接入时跑一次。
- **`/spec`** — 通过对话做需求拆解：先澄清模糊诉求，再拆成多条互不重叠的小规则——一文一规则、≤100 行、只说一件事 + 一个例子——由轻量 `INDEX.md` 统领，读者先扫索引再按需加载。回答**"做什么"**。
- **`/plan`** — spec → **自包含、函数级**的实施计划：每个文件只解决一个独立问题，详细到函数名与职责（但不写具体代码），任何 AI 清空上下文后仅凭该文件即可正确实现。回答**"怎么做"**。调用即进入 **plan 模式只读对齐**（规模分流 / 拆分方案 / 路线图全在批准后才落盘）；自动识别规模——单领域小需求走单 topic，多领域 / 冷启动 / 大批 spec 涌入则切到**分批路线图**：产出含依赖链和**验证门**（端到端可观察能力）的 `ROADMAP.md`、一次只展开当前批，该批 exec 验证门通过后再次 `/plan` 自动定位并展开下一批。
- **`/exec`** — **三 Agent 隔离执行。** *Test* Agent 只读 spec 规则写失败测试（Red）；*Impl* Agent 只看测试 + 函数清单写实现（Green）——它**看不到 spec**，无法"照着意图作弊"；*Review* Agent 对照 spec 检查、只读不写。每步进度写入 `PROGRESS.md`，token 耗尽也能从断点**无损续接**。
- **`/review`** — **Workflow 编排、对抗验证**的本地 PR review（当前分支 vs base）。Phase 1 并发 **5 个 finder**——代码质量、安全、简洁性 / 反包袱、文档同步、**Codex 跨模型独立** review——schema 强制结构化发现；纯代码去重后，**每条 🔴/🟡 发现交由 3 个独立怀疑视角重判**（重要性 / 根源性 / 不修风险），多数决去留。只读、绝不自动改码。要求 Claude Code ≥ 2.1.154（Workflow 工具）。
- **`/revise`** — 随时可介入的异常处理：把偏差**归因**为三类之一——*spec 缺陷*（→ 回 `/spec`）、*实现偏离*（→ 回 `/exec`）、*需求变更*——再做定向修正 + 回归验证。所有需修复的 review 发现都汇入此处。
- **`/git-push-pr`** — 用户触发的推送 + PR 流程（单 / 多仓库、批量或选择性）。当存在 spec `INDEX.md` 时，先跑**分支规范自查（pre-review）**：subagent 拿 spec 比对分支 vs main 的 diff，违规循环修复复审，再起草一份简洁的 **6 段 PR 描述**（背景 / 需求 / 方案 / 结果 / 测试 / 规范，< 50 行），直接用作 PR body。

附带 **8 个编排 subagent**（由上述环节驱动）：`test-engineer` / `impl-engineer` / `spec-reviewer` / `review-code-quality` / `review-security` / `review-simplicity` / `review-doc-sync` / `review-codex`。

被动约束（hooks，自动生效）：拦截 npm/yarn、拦截 main commit、依赖版本自检、stop 四项自检。

---

## 配套约束 Skills

向上方流水线灌入规则——只装你需要的层；每个 skill 一行带过。

### bb-spec-core — 通用纪律

- **`tdd-workflow`** — Red-Green-Refactor 纪律，覆盖增 / 改 / 删三场景标准流程
- **`version-policy`** — 官方库 / 标准库优先，新增第三方库须经用户明确同意；钉版本前先查依赖官方最新版，禁凭训练记忆
- **`git-workflow`** — 分支决策、阶段性 commit、六段式 PR 描述、合并后清理

### bb-spec-backend — 后端技术框架约束

- **`golang-constraints`** — Go 全生命周期：三层架构、禁过度抽象、测试服从生产设计
- **`golang-testing`** — Go 测试组织：table-driven、subtests、benchmark、fuzz
- **`api-design`** — REST 设计：资源命名、状态码、分页、`A-BBB-CCCC` 结构化错误码
- **`database-constraints`** — 应用层 UUIDv7 主键、软删除 + 联合 UNIQUE、DB 管理时间戳、全链路 UTC
- **`auth-constraints`** — 认证（authN）：双 token（JWT + 不透明 refresh）轮换 + 重放检测、滑动续期、argon2id
- **`authz-constraints`** — 授权（authZ）：默认拒绝、判定集中、粗粒度角色 + 细粒度资源 ownership 两级校验防 IDOR
- **`observability-constraints`** — 日志 / 链路 / 指标基于 OTel：一处装配、JSON 日志带稳定 trace_id、label 基数有限
- **`service-constraints`** — 运行时治理：env 注入密钥 fail-fast、优雅生命周期、写幂等、超时 + 安全重试

### bb-spec-frontend — 前端技术框架约束

- **`vue-constraints`** — Vue 3 + TypeScript + Vite + Tailwind + bun 技术栈强约束
- **`frontend-constraints`** — 工程约定：统一请求 client、错误码→UI 映射集中、路由守卫仅 UX、类型来自契约

---

## Claude Code 安装 / Install

BB-Spec 拆成**四个可独立安装的子 plugin**——只装你需要的约束层。

先添加一次 marketplace（在 Claude Code 里执行）：

```bash
/plugin marketplace add 0xBB2B/bb-spec
```

再按需安装对应层：

| 子 plugin | 装了得到什么 | 安装命令 |
|---|---|---|
| **bb-spec-core** _(推荐基座)_ | TDD / 版本策略 / Git 纪律 + 3 个被动 hook | `/plugin install bb-spec-core@0xbb2b` |
| **bb-spec-workflow** _(核心功能)_ | spec → plan → exec → review → revise → git-push-pr、init 反向 spec + 8 个 subagent | `/plugin install bb-spec-workflow@0xbb2b` |
| **bb-spec-backend** | Go / REST API / 数据库 / 认证 / 授权 / 可观测性 / 服务治理约束 | `/plugin install bb-spec-backend@0xbb2b` |
| **bb-spec-frontend** | Vue 3 + TS + Vite + Tailwind + bun 技术栈与工程约定（含 bun hook） | `/plugin install bb-spec-frontend@0xbb2b` |

按需取用——例如只要纪律与工作流、不要技术栈意见：装 `bb-spec-core` + `bb-spec-workflow`；想要全套：四个全装。

或手动添加到 `~/.claude/settings.json`（只 enable 你想要的）：

```json
{
  "extraKnownMarketplaces": {
    "0xbb2b": {
      "source": { "source": "github", "repo": "0xBB2B/bb-spec" }
    }
  },
  "enabledPlugins": {
    "bb-spec-core@0xbb2b": true,
    "bb-spec-workflow@0xbb2b": true,
    "bb-spec-backend@0xbb2b": false,
    "bb-spec-frontend@0xbb2b": false
  }
}
```

> **从旧的单个 `bb-spec` plugin（≤ 4.x）升级？** 它已被拆成上面四个子 plugin。先 `/plugin uninstall bb-spec` 卸掉旧的，再装你需要的层。

## 版本与更新 / Versioning

```bash
/plugin update                  # 检查并更新所有已装 plugin
/plugin update bb-spec-core     # 仅更新某个子 plugin
```

四个子 plugin 共用同一条同步版本线。

---

## 默认启用的 Hooks（开箱即用）

每个 hook 随"负责该关注点的子 plugin"一起发布——装了对应 plugin 才有。

| Hook | 所属子 plugin | 触发时机 | 作用 |
|---|---|---|---|
| `block-non-bun-pm` | bb-spec-frontend | PreToolUse(Bash) | 拦截 `npm` / `yarn` / `pnpm` 的包管理动作，强制 `bun`；既有项目已存在匹配 lockfile（如 `package-lock.json`）时放行 |
| `block-main-commit` | bb-spec-core | PreToolUse(Bash) | 拦截 `main` / `master` 分支的 `git commit` |
| `dep-version-check` | bb-spec-core | PostToolUse(Write\|Edit) | 编辑依赖文件后注入"先查官方最新版"自检提示 |
| `stop-self-check` | bb-spec-core | Stop | 任务结束前强制四项自检：临时文件 / 改动范围 / 孤立残留 / 历史包袱 |

---

## 高级选项：可选 Hooks（默认关，按需启用）

**bb-spec-workflow** 还附带两个**副作用较大**的 Stop hook，已随该 plugin 一起注册，但脚本顶部有启用门槛，**默认不跑**——必须显式启用：

| Hook | 作用 | 启用方式 |
|---|---|---|
| `stop-auto-tests.sh` | Stop 后在 Go 项目（有 `go.mod`）自动跑 `vet` / `golangci-lint` / `test -race` / `make test-integration`，失败回灌给 AI | `export CLAUDE_ENABLE_AUTO_TESTS=1` 或项目根 `touch .enable-auto-tests` |
| `stop-auto-commit.sh` | Stop 后检测到未提交的已追踪改动，回灌指令让 **AI 用语义化 message 自行 commit**（默认 `git add -u`，非 main/master，不 push） | `export CLAUDE_ENABLE_AUTO_COMMIT=1` 或仓库根 `touch .enable-auto-commit` |

环境变量是会话级 / 全局级启用（写进 shell rc），标记文件是项目级启用，二选一或并用。停用：`unset` 环境变量 或 `rm` 标记文件即可。

---

## 测试

```bash
bash tests/validate.sh
```

校验多 plugin 结构：marketplace.json 有效性与 plugin 条目一致性（每个 `source` 都指向真实存在、且 name 匹配的 plugin 目录）、各子 plugin 的 plugin.json 字段、agent frontmatter 完整性（必填字段、name 一致性、agent-type 合法值、安全基线段落）、skill SKILL.md 格式、hooks.json 有效性及脚本存在性、个人路径泄露检测。

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
| 临时允许 npm / yarn / pnpm | 暂未提供，建议临时禁用 `bb-spec-frontend` |
| 临时允许 main commit | 暂未提供，建议临时禁用 `bb-spec-core` |
| 跳过 Stop 自检 | 当前无开关——这是核心铁律，不建议跳过 |
| 启用 stop-auto-tests | `CLAUDE_ENABLE_AUTO_TESTS=1` 或项目根 `.enable-auto-tests` |
| 启用 stop-auto-commit | `CLAUDE_ENABLE_AUTO_COMMIT=1` 或仓库根 `.enable-auto-commit` |

---

## License

MIT
