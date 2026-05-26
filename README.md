# BB-Spec

> 中文优先的 Claude Code 工作流约束套装：**Go + Vue + bun 技术栈强约束**、**TDD / 反历史包袱铁律**、**多代理本地 review 套件**。

**English TL;DR**: A Claude Code plugin for opinionated, Chinese-first dev workflow. Hard guards against `npm`/`yarn`/`pnpm` & direct `main` commits, mandatory dependency-version checks, anti-legacy-baggage discipline, and a local multi-agent code review suite. Skills cover Go backend, Vue 3 + bun frontend, TDD, REST API design, and Git workflow.

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

本 plugin 采用 **SemVer + Git tag** 版本模式。`plugin.json` 里的 `version` 必须与 Git tag 去掉 `v` 前缀后保持一致；例如当前首个版本是 `0.1.0`，对应 tag 是 `v0.1.0`。

发布新版本时，在 GitHub Actions 里手动运行 `Release Plugin Version`，输入 `0.1.0` 或 `v0.1.0`。该 workflow 会完成三件事：

1. 同步更新 `.claude-plugin/plugin.json` 的 `version`
2. 提交 `release: vX.Y.Z`
3. 在该提交上创建并推送 `vX.Y.Z` tag

更新已安装插件：

```bash
/plugin update              # 检查并更新所有已装 plugin
/plugin update bb-spec   # 仅更新本 plugin
```

---

## 默认启用的 Hooks（开箱即用）

| Hook | 触发时机 | 作用 |
|---|---|---|
| `block-non-bun-pm` | PreToolUse(Bash) | 拦截 `npm` / `yarn` / `pnpm` 的包管理动作，强制 `bun` |
| `block-main-commit` | PreToolUse(Bash) | 拦截 `main` / `master` 分支的 `git commit` |
| `dep-version-check` | PostToolUse(Write\|Edit) | 编辑依赖文件后注入"先查官方最新版"自检提示 |
| `stop-self-check` | Stop | 任务结束前强制四项自检：临时文件 / 改动范围 / 孤立残留 / 历史包袱 |

---

## 高级选项：可选 Hooks（默认关，按需启用）

仓库还附带两个**副作用较大**的 Stop hook，已随 plugin 一起注册，但脚本顶部有启用门槛，**默认不跑**——必须显式启用：

| Hook | 作用 | 启用方式 |
|---|---|---|
| `stop-auto-tests.sh` | Stop 后在 Go 项目（有 `go.mod`）自动跑 `vet` / `golangci-lint` / `test -race` / `make test-integration`，失败回灌给 AI | `export CLAUDE_ENABLE_AUTO_TESTS=1` 或项目根 `touch .enable-auto-tests` |
| `stop-auto-commit.sh` | Stop 后在 git 仓库自动 commit 已追踪改动（仅 `git add -u`，非 main/master，不 push） | `export CLAUDE_ENABLE_AUTO_COMMIT=1` 或仓库根 `touch .enable-auto-commit` |

环境变量是会话级 / 全局级启用（写进 shell rc），标记文件是项目级启用，二选一或并用。停用：`unset` 环境变量 或 `rm` 标记文件即可。

---

## 工作流

```
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
/review  5 agent 并行 PR 级 review
  │  质量 / 安全 / 反包袱 / 过度设计 / Codex
  │
  ▼
/git-push-pr  pre-review → 推送 → 开 PR
```

被动约束（hooks，自动生效）：拦截 npm/yarn、拦截 main commit、依赖版本自检、stop 四项自检。

---

## Skills 一览（12 个）

### 通用纪律

- **`tdd-workflow`** — 通用 TDD 纪律：Red-Green-Refactor、增/改/删三场景标准流程
- **`version-policy`** — 引入/升级依赖前必须官方渠道查最新版，禁凭训练记忆
- **`git-workflow`** — 分支决策、阶段性 commit、PR 三段式描述、合并后清理
- **`git-push-pr`** — 用户主动触发的多仓库批量/选择性推送 PR 流程
- **`spec`** — 需求拆解与文档化：一文一规则、≤100 行、输出至 `.bb-spec/docs/spec/`
- **`plan`** — 读取 spec 产出分步实施计划：一文一单元、函数级详细、输出至 `.bb-spec/docs/plan/`
- **`exec`** — 三 Agent 隔离执行 plan（Test→Impl→Review），PROGRESS.md 断点恢复
- **`api-design`** — REST API 设计：资源命名、状态码、分页、错误响应、版本化

### Go 后端

- **`golang-constraints`** — Go 项目全生命周期约束：三层架构、禁过度抽象、测试服从生产设计
- **`golang-testing`** — Go 测试组织：table-driven、subtests、benchmark、fuzz

### 前端

- **`vue-constraints`** — Vue 3 + TypeScript + Vite + Tailwind + bun 强约束

### 本地 Review

- **`review`** — 当前分支 vs base：5 代理并行（质量/安全/反包袱/过度设计/Codex 跨模型）

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
