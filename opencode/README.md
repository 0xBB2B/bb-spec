# opencode-bb-spec

BB-Spec 的 [opencode](https://opencode.ai) 插件版：一个 npm 包交付全部 26 个 skills、11 个编排 subagent、11 个 slash command 与 4 个流程守卫 hook，覆盖 Claude Code 插件版除「跨插件引用 `codex:codex-rescue`」外的全部功能。

## 安装

```jsonc
// 全局 ~/.config/opencode/opencode.json，或项目 opencode.json
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["opencode-bb-spec"]
}
```

未发布 npm 时用本地路径（clone 本仓库后指向 `opencode/` 目录，先在该目录 `bun install`）：

```jsonc
{
  "plugin": ["file:///绝对路径/bb-spec/opencode"]
}
```

保存后重启 opencode 生效。验证：`opencode debug skill` 应列出 26 个 bb-spec skill，`opencode debug agent bb-spec-test-engineer` 应返回 agent 配置。

## 交付内容

| 类别 | 数量 | 说明 |
|---|---|---|
| skills | 26 | 按域分组：core（TDD/代码纪律/git 流程/版本策略）、backend（Go/API/DB/认证/授权/配置/可观测/服务治理）、frontend（Vue 栈/工程约定）、product（PRD）、workflow（spec→plan→exec→review→revise→git-push 及 test-api/test-webview/doc-update/git-clone） |
| subagents | 11 | `bb-spec-` 前缀注册：test-engineer、impl-engineer、spec-reviewer、pre-reviewer、review-code-quality/security/simplicity/robustness/doc-sync/codex、webview-test-runner；审查类一律 `edit: deny` 权限硬化 |
| commands | 11 | `/prd` `/spec` `/plan` `/exec` `/revise` `/review` `/git-push` `/git-clone` `/doc-update` `/test-api` `/test-webview`，每个 command 先加载同名 skill 再按其流程执行 |
| hooks | 4 | 见下表 |

### hooks 行为

| 守卫 | 挂载点 | 行为 |
|---|---|---|
| git-workflow-guard | `tool.execute.before` / `tool.execute.after`（bash） | main/master 上 `git commit` → 拦截；`git worktree add` 目标不在 `~/.bb-spec/worktrees/` 下 → 拦截；其余 git/gh pr 流程动作放行并在工具输出尾部注入 git-workflow 纪律 + 实时分支状态 |
| block-non-bun-pm | `tool.execute.before`（bash） | npm/yarn/pnpm 的包管理动作 → 拦截并给 bun 等价命令；向上找到匹配 lockfile 的既有项目放行 |
| dep-version-check | `tool.execute.after`（write/edit） | 改动 package.json/go.mod/Dockerfile/CI/IaC 等钉版本文件后，注入「版本号须经官方渠道查询」自检提示 |
| stop-self-check | `event`（session.idle） | 主会话每轮结束注入一次「临时文件清理/改动范围/孤立残留/历史包袱」四项自检 + 简报格式要求；同一轮内重复 idle 不再注入，直到新的用户消息解除，子会话不注入 |

## 与 Claude Code 插件版的对应关系

| Claude Code 机制 | opencode 等价实现 |
|---|---|
| SKILL.md 自动触发 + `/skill` 调用 | 原生 `skill` 工具加载；用户入口另配 11 个 command |
| `AskUserQuestion` 结构化提问 | 选项式提问（对话中列出编号选项等待用户选择） |
| `EnterPlanMode` / `ExitPlanMode` | 只读对齐阶段纪律：不写盘，方案获用户明确批准后落盘 |
| `Agent` 工具 + `subagent_type` 派工 | `task` 工具 + 注册 subagent，输入写进自包含任务消息 |
| `Workflow` 编排（/review） | `task` 同批并行派工两阶段（Find/Verify）+ 纯代码去重脚本 |
| hooks.json + shell 脚本协议 | TypeScript 插件钩子（`src/index.ts` + `src/guards.ts`） |
| `codex:codex-rescue` 跨插件 agent | `bb-spec-review-codex` 经 bash 直连本机 `codex` CLI（`--sandbox read-only`），`which codex` 失败整体降级 |

## 开发

```bash
cd opencode
bun install
bun test              # guards 逻辑单测
bun x tsc --noEmit    # 类型检查
```
