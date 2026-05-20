# bb-channel

> 中文优先的 Claude Code 工作流约束套装：**Go + Vue + bun 技术栈强约束**、**TDD / 反历史包袱铁律**、**多代理本地 review 套件**。

**English TL;DR**: A Claude Code plugin for opinionated, Chinese-first dev workflow. Hard guards against `npm`/`yarn`/`pnpm` & direct `main` commits, mandatory dependency-version checks, anti-legacy-baggage discipline, and a local multi-agent code review suite. Skills cover Go backend, Vue 3 + bun frontend, TDD, REST API design, and Git workflow.

---

## 安装 / Install

在 Claude Code 里执行：

```bash
/plugin marketplace add 0xBB2B/skills
/plugin install bb-channel@0xbb2b
```

或手动添加到 `~/.claude/settings.json`：

```json
{
  "extraKnownMarketplaces": {
    "0xbb2b": {
      "source": { "source": "github", "repo": "0xBB2B/skills" }
    }
  },
  "enabledPlugins": {
    "bb-channel@0xbb2b": true
  }
}
```

## 更新 / Update

本 plugin 采用 **commit-SHA 版本模式**——`main` 上每个 commit 即为可发布版本，无需 bump 版本号。在 Claude Code 里执行：

```bash
/plugin update              # 检查并更新所有已装 plugin
/plugin update bb-channel   # 仅更新本 plugin
```

不会自动拉取，需主动触发。

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

仓库还附带两个**副作用较大**的 hook 脚本，**未自动注册**，需自己加进 `~/.claude/settings.json`：

| Hook | 作用 | 逃生开关 |
|---|---|---|
| `stop-run-tests.sh` | Stop 后在 Go 项目（有 `go.mod`）自动跑 `vet` / `golangci-lint` / `test -race` / `make test-integration`，失败回灌给 AI | `CLAUDE_SKIP_STOP_TESTS=1` 或项目根 `.skip-stop-tests` |
| `stop-auto-commit.sh` | Stop 后在 git 仓库自动 commit 已追踪改动（仅 `git add -u`，非 main/master，不 push） | `CLAUDE_SKIP_AUTO_COMMIT=1` 或仓库根 `.skip-auto-commit` |

启用方式（追加到 `settings.json` 的 `hooks.Stop`）：

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "${HOME}/.claude/plugins/cache/0xbb2b/bb-channel/<version>/hooks/stop-run-tests.sh" },
          { "type": "command", "command": "${HOME}/.claude/plugins/cache/0xbb2b/bb-channel/<version>/hooks/stop-auto-commit.sh" }
        ]
      }
    ]
  }
}
```

---

## Skills 一览（12 个）

### 通用纪律

- **`tdd-workflow`** — 通用 TDD 纪律：Red-Green-Refactor、增/改/删三场景标准流程
- **`dependency-version-policy`** — 引入/升级依赖前必须官方渠道查最新版，禁凭训练记忆
- **`git-workflow-discipline`** — 分支决策、阶段性 commit、PR 三段式描述、合并后清理
- **`git-push-pr`** — 用户主动触发的多仓库批量/选择性推送 PR 流程
- **`api-design`** — REST API 设计：资源命名、状态码、分页、错误响应、版本化

### Go 后端

- **`go-project-constraints`** — Go 项目全生命周期约束：三层架构、禁过度抽象、测试服从生产设计
- **`golang-patterns`** — Go 惯用模式与最佳实践
- **`golang-testing`** — Go 测试组织：table-driven、subtests、benchmark、fuzz

### 前端

- **`frontend-vue-constraints`** — Vue 3 + TypeScript + Vite + Tailwind + bun 强约束

### 本地 Review 套件（差异化亮点）

- **`local-ultrareview`** — 当前分支 vs base：5 代理并行（质量/安全/反包袱/过度设计/Codex 跨模型）
- **`review-quality`** — 任意仓库整体质量审视：5 代理并行
- **`review-doc`** — Markdown 文档审查：机械层自动修复 + 语义层双代理
- **`review-code-doc-consistency`** — 代码与文档一致性审查

---

## 推荐配套：CLAUDE.md 模板

仓库根目录的 [`CLAUDE-template.md`](./CLAUDE-template.md) 是配套的"铁律索引"参考。**不会自动安装**——按需复制到你的 `~/.claude/CLAUDE.md` 或项目根 `CLAUDE.md`，按需裁剪。

---

## 逃生开关速查

| 场景 | 开关 |
|---|---|
| 临时允许 npm / yarn / pnpm | 暂未提供，建议临时禁用 plugin |
| 临时允许 main commit | 同上 |
| 跳过 Stop 自检 | 当前无开关——这是核心铁律，不建议跳过 |
| 跳过 stop-run-tests | `CLAUDE_SKIP_STOP_TESTS=1` 或 `.skip-stop-tests` |
| 跳过 stop-auto-commit | `CLAUDE_SKIP_AUTO_COMMIT=1` 或 `.skip-auto-commit` |

---

## License

MIT
