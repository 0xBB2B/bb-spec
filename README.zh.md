<p align="center">
  <img src="./assets/banner.jpg" alt="bb-spec — A light-weight protocol for building trust" width="100%" />
</p>

<h1 align="center">📐 BB-Spec</h1>

<p align="center">
  <strong>一条 PRD 驱动的 Claude Code 流水线,把模糊需求一路带到可交付的代码。</strong>
</p>

<p align="center">
  每个阶段可追溯、可断点恢复、经对抗验证 —— 辅以 Go / Vue + bun / TDD / Git 纪律的技术栈约束套件。
</p>

<p align="center">
  <a href="https://github.com/0xBB2B/bb-spec/actions/workflows/ci.yml?query=branch%3Amain"><img src="https://img.shields.io/github/actions/workflow/status/0xBB2B/bb-spec/ci.yml?branch=main&style=for-the-badge&logo=github&label=CI" alt="CI 状态" /></a>
  <a href="https://github.com/0xBB2B/bb-spec/releases"><img src="https://img.shields.io/github/v/release/0xBB2B/bb-spec?include_prereleases&style=for-the-badge&logo=github&color=blue" alt="GitHub release" /></a>
  <a href="https://github.com/0xBB2B/bb-spec/stargazers"><img src="https://img.shields.io/github/stars/0xBB2B/bb-spec?style=for-the-badge&color=yellow&logo=github" alt="GitHub Stars" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge" alt="MIT License" /></a>
  <a href="https://docs.anthropic.com/en/docs/claude-code/overview"><img src="https://img.shields.io/badge/Claude%20Code-Plugin-D97757?style=for-the-badge&logo=anthropic&logoColor=white" alt="Claude Code Plugin" /></a>
</p>

<p align="center">
  <a href="./README.md">English</a> · <strong>简体中文</strong> · <a href="./README.zh-TW.md">繁體中文</a> · <a href="./README.ja.md">日本語</a> · <a href="./README.ko.md">한국어</a>
</p>

<p align="center">
  <a href="#-30-秒上手">快速开始</a> ·
  <a href="#-核心流水线-prd--ship">流水线</a> ·
  <a href="#-阶段一览">阶段一览</a> ·
  <a href="#-配套约束-skills">约束 Skills</a> ·
  <a href="#-claude-code-安装--install">安装</a> ·
  <a href="#-默认启用的-hooks">Hooks</a> ·
  <a href="#-设计渊源借鉴与对比">设计渊源</a>
</p>

---

## 🚀 30 秒上手

```bash
/plugin marketplace add 0xBB2B/bb-spec
/plugin install bb-spec-core@0xbb2b
/plugin install bb-spec-workflow@0xbb2b
```

主流水线 5 条命令:

| 命令 | 做什么 | 何时用 |
|---|---|---|
| `/prd` | 质疑→澄清→拆解,批准一次后落盘 PRD + AGENTS.md,并自动跑 plan → exec | 新需求开工 |
| `/plan` | PRD → 函数级实施计划,做完自动跑 exec | 由 `/prd` 自动调用 |
| `/exec` | 三 Agent 隔离跑 Test→Impl→Review,收尾自动 doc-update | 由 `/plan` 自动调用;中断后手动续接 |
| `/review` | 多 finder 并行 + 对抗验证 | 提 PR 前 |
| `/git-push` | pre-review 自查 + 推 + 开 PR | 准备发版 |

三条支线随时可介入:`/git-clone`（拉远程项目到本地 + 落 `.bb-spec.yaml` 一次性 onboarding）、`/revise`（任何偏差按根因回到正确阶段）、`/doc-update`（文档与代码一致性体检;`/exec` 与 `/revise` 收尾时会自动跑一遍本次改动的范围）。

---

## 🔁 核心流水线 `prd → ship`

```
 (可选) /git-clone ──► 拉远程 + 落 .bb-spec.yaml
   │
 /prd ══► /plan ══► /exec ══► /doc-update ──► /review ──► /git-push
 做什么    怎么做    Red→Green  文档追平代码    并发+对抗    pre-review+开 PR
 (唯一一次批准)        →Review
 ══► 自动衔接,不再询问(仅新增第三方依赖或需设计裁决时停下)
                                                          │
        ┌─────────────────────────────────────────────────┘
        │
        ▼ /revise(随时介入,按根因路由)
          PRD 缺陷 → 改本分支 PRD   ·   实现偏离 → TDD 修复   ·   大的需求变更 → /prd

 (可选) /test-webview · /test-api — 前端 / 后端 e2e,挂在 /exec 与 /review 之间
 /doc-update(定期 / 按需)— 扫文档与代码的漂移 → 默认改文档,代码违反项目约束才停下问 → 挂 /revise
```

**为什么这条流水线靠得住**——每次交接物都是**磁盘上的文档**、不是会话里的临时记忆,这是它能断点续、能换 AI 接手、能逐级追溯的根本。

### 🎯 阶段一览

- **`/git-clone`** — *一次性 onboarding*:把远程仓库拉到本地、写好 `.bb-spec.yaml`。
  - **AskUserQuestion 两连**:① 单 repo / 多 repo 工作区(决定目录结构) ② `base_dir`(决定后续所有 bb-spec 交付物落点)
  - **多 repo 工作区**建统一父目录 + 各成员仓库独立 clone(复原构建工具期待的相对布局),禁嵌套、禁覆盖
  - 职责严格收敛:**只**拿代码 + 写 `base_dir`,不读代码、不装依赖

- **`/prd`** — 新需求的唯一入口,回答**「做什么、为什么」**。
  - 质疑前置(允许结论是「不值得做」)→ 递进澄清 → 拆解,全程在 **plan 模式只读对齐**;用户**只批准这一次**,之后自动跑完 `/plan` → `/exec` → `/doc-update`
  - 落盘 **PRD**(`docs/prd/<日期>.<主题>/`:背景、目标、非目标、用户故事、可测的约束与验收、决策记录)和 **AGENTS.md**(对整个项目生效的约束,如「禁止泛型」)
  - PRD 在本分支内可改(实施中发现方案问题直接改它),合并后冻结;**代码是「现在做什么」的唯一来源**,PRD 只回答「为什么」
  - 之后每个 commit 带 `Requirement: <PRD 目录名>` 标记:`git log -L :函数:文件` 就能列出改过这个函数的需求,读对应 PRD 的决策记录就知道当时为什么这样设计
  - 支持多仓库工作区(如 `docs/` 与各服务是独立仓库):PRD 与 AGENTS.md 放在文档仓库,每个仓库的 commit 都带标记

- **`/plan`** — PRD → 自包含、**函数级**实施计划,回答**「怎么做」**。
  - 每文件一独立问题,详细到函数名与职责;声明式产物(DDL / API 契约 / 配置)**直接内联最终成品**,exec 原样落盘
  - 由 `/prd` 自动调用,不再单独批准;只有需要**新增第三方依赖**时才停下请用户同意,同意即视为 version-policy 要求的授权
  - plan 只在执行期间存在,全部完成后由 `/exec` 删除,避免和 PRD 重复

- **`/exec`** — **三 Agent 隔离执行**,核心反作弊设计。
  - *Test* Agent 只读 PRD 约束写失败测试(Red)
  - *Impl* Agent **看不到 PRD**,只看测试 + 函数清单写实现(Green),无法「照着意图作弊」;新增第三方库受 plan 已批依赖清单约束
  - *Review* Agent 对照 PRD 验收与 AGENTS.md 检查并过一遍鲁棒性/安全视角,只读不写
  - 每步进度写 `PROGRESS.md`,token 耗尽也能**无损续接**
  - 实施中发现方案有问题,停下让你选:改代码 / 改本次 PRD / 暂停;小改就地改,大改回到 `/prd` 重新批准
  - 全部完成后自动跑 `/doc-update` 收尾模式,让本次 PRD 和 README 等文档追平实际交付

- **`/test-webview`** — 前端 / 网页项目的**交互验收**。
  - Docker 整栈拉起(首次确认后记住,跑完 `down -v` 清理),浏览器 MCP 驱动真实浏览器
  - **每个用例派隔离串行 subagent**,几百用例也不爆主上下文;全程串行(浏览器单实例)
  - 用例自动从本分支 PRD 的验收与验证路径归纳生成(不读已合并的历史 PRD);跑前**覆盖对齐**,缺口不静默漏测;失败转 `/revise`
  - 需浏览器 MCP(playwright / chrome-devtools)

- **`/test-api`** — 后端**接口 e2e**。
  - `compose.e2e.yaml` 拉起整栈,md 用例**机械渲染为单文件 Bun TS runner**,`bun run` 一次跑完
  - **零 subagent、零并发**——HTTP 是确定性脚本,时钟共享禁并发
  - **时间敏感规则**(token 过期、订单超时、积分过期)经 `/test/advance-time`、`/test/backdate`、`/test/trigger-job` 协议测
  - 应用侧**产双 image**:test image 带 `/test/*` 路由 + `ENV TESTAPI=1`;生产 image **物理排除** `/test/*` 源码;`/test/healthz` 探测失败即中止、禁降级

- **`/review`** — Workflow 编排、**对抗验证**的本地 PR review。
  - Phase 1 diff 按 ≤1500 行分片,每片 diff 落盘一次供所有 agent 共读,每片并发 **3 个 finder**:缺陷(安全 / 鲁棒性 / 正确性)/ 设计(质量 / 简洁性 / 文档同步)/ **Codex 跨模型独立** review,schema 强制结构化
  - Phase 2 每片 **1 个仲裁者**对本片全部 🔴/🟡 做三视角裁决(重要性 / 根源性 / 不修风险),多数决去留
  - Phase 3 每片 **1 个扫描者**为全部确认项在本片内**同类扫描**兄弟位点,交 `/revise` 一次修一类;NIT 可一键批量清
  - 三个阶段都按片派 agent,成本约 300 tokens / diff 行(15k 行 diff ≈ 50 agent / 5M tokens)
  - 修复落地后对修复 diff **自动复审一轮**;报告落盘 `.bb-spec/.cache/review/`,下一轮据此标记复发、跳过已否决项
  - 只读、绝不自动改码;要求 Claude Code ≥ 2.1.154

- **`/revise`** — 随时介入的异常处理。
  - 先读代码确认现状、经 `git log -L` 查回相关 PRD,再把偏差**归因**为三类:*PRD 缺陷*、*实现偏离*、*需求变更*
  - 本分支 PRD 可改;已合并 PRD 不改,修订原因写进 commit 正文
  - 所有需修复的 review 发现都汇入此处
  - 修完自动跑 `/doc-update` 收尾模式

- **`/git-push`** — 用户触发的推送 + PR 流程(单 / 多仓库)。
  - 存在 AGENTS.md 或本分支 PRD 时先跑**分支规范自查(pre-review)**:subagent 比对项目约束与 PRD vs 分支 diff,违规循环修复
  - PR 描述带 `Requirement:` 标记;squash 合并需设为「PR 标题和描述」或「PR 标题和 commit 详情」,否则标记会丢
  - 起草 **6 段 PR 描述**(背景 / 需求 / 方案 / 结果 / 测试 / 规范,< 50 行)直接用作 PR body

- **`/doc-update`** — 文档与代码**一致性体检**。
  - 四类发现:doc-stale(根文档过期)/ prd-stale(本分支 PRD 与交付不符)/ code-violation(代码违反 AGENTS.md)/ agents-conflict(项目约束互相矛盾)
  - **代码是事实、文档追平代码**;改代码一律先问、挂回 `/revise` 走 TDD;已合并的 PRD 任何模式都不碰
  - **收尾模式**(`--tail`):`/exec`、`/revise` 结束时自动调用,只处理本分支改动涉及的范围

**附带产物**

- **8 个编排 subagent**(被上述环节驱动):`test-engineer` / `impl-engineer` / `prd-reviewer` / `webview-test-runner` / `review-defect` / `review-design` / `review-codex` / `pre-reviewer`
- **4 个被动 hook**(自动生效):拦截 npm/yarn、拦截 main commit、依赖版本自检、Stop 四项自检

---

## 🧩 配套约束 Skills

向流水线灌入规则——只装你需要的层。

### bb-spec-core — 通用纪律

- **`tdd-workflow`** — Red-Green-Refactor 纪律,覆盖增 / 改 / 删三场景标准流程
- **`version-policy`** — 官方库 / 标准库优先,新增第三方库须经用户明确同意(`/plan` 阶段用户同意的依赖清单视为已同意);钉版本前先查依赖官方最新版,禁凭训练记忆
- **`git-workflow`** — 分支决策、阶段性 commit、六段式 PR 描述、合并后清理

### bb-spec-backend — 后端技术框架约束

- **`golang-constraints`** — Go 全生命周期:三层架构、禁过度抽象、测试服从生产设计
- **`golang-testing`** — Go 测试组织:table-driven、subtests、benchmark、fuzz
- **`api-design`** — REST 设计:资源命名、状态码、分页、`A-BBB-CCCC` 结构化错误码
- **`database-constraints`** — 应用层 UUIDv7 主键、软删除 + 联合 UNIQUE、DB 管理时间戳、全链路 UTC
- **`auth-constraints`** — 认证(authN):双 token(JWT + 不透明 refresh)轮换 + 重放检测、滑动续期、argon2id
- **`authz-constraints`** — 授权(authZ):默认拒绝、判定集中、粗粒度角色 + 细粒度资源 ownership 两级校验防 IDOR
- **`observability-constraints`** — 日志 / 链路 / 指标基于 OTel:一处装配、JSON 日志带稳定 trace_id、label 基数有限
- **`service-constraints`** — 运行时治理:env 注入密钥 fail-fast、优雅生命周期、写幂等、超时 + 安全重试
- **`config-constraints`** — 配置载体三分:env/secret 装启动必需且不热更、yaml/configmap 装可热更默认值、DB 装动态业务配置;核心凭据仅 secret/KMS,下沉 DB 须 envelope encryption

### bb-spec-frontend — 前端技术框架约束

- **`vue-constraints`** — Vue 3 + TypeScript + Vite + Tailwind + bun 技术栈强约束
- **`frontend-constraints`** — 工程约定:统一请求 client、错误码→UI 映射集中、路由守卫仅 UX、类型来自契约

---

## 📦 Claude Code 安装 / Install

BB-Spec 拆成**四个可独立安装的子 plugin**——只装你需要的约束层。

先添加一次 marketplace(在 Claude Code 里执行):

```bash
/plugin marketplace add 0xBB2B/bb-spec
```

再按需安装对应层:

| 子 plugin | 装了得到什么 | 安装命令 |
|---|---|---|
| **bb-spec-core** _(推荐基座)_ | TDD / 版本策略 / Git 纪律 + 3 个被动 hook | `/plugin install bb-spec-core@0xbb2b` |
| **bb-spec-workflow** _(核心功能)_ | prd → plan → exec → doc-update → review → revise → git-push(+ 可选 test-webview / test-api e2e)、git-clone 一次性初始化 + 8 个 subagent | `/plugin install bb-spec-workflow@0xbb2b` |
| **bb-spec-backend** | Go / REST API / 数据库 / 认证 / 授权 / 可观测性 / 服务治理 / 配置约束 | `/plugin install bb-spec-backend@0xbb2b` |
| **bb-spec-frontend** | Vue 3 + TS + Vite + Tailwind + bun 技术栈与工程约定(含 bun hook) | `/plugin install bb-spec-frontend@0xbb2b` |

按需取用——例如只要纪律与工作流、不要技术栈意见:装 `bb-spec-core` + `bb-spec-workflow`;想要全套:四个全装。

或手动添加到 `~/.claude/settings.json`(只 enable 你想要的):

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

## 🔄 版本与更新 / Versioning

```bash
/plugin update                  # 检查并更新所有已装 plugin
/plugin update bb-spec-core     # 仅更新某个子 plugin
```

四个子 plugin 共用同一条同步版本线。

---

## 🪝 默认启用的 Hooks

每个 hook 随「负责该关注点的子 plugin」一起发布——装了对应 plugin 才有。

| Hook | 所属子 plugin | 触发时机 | 作用 |
|---|---|---|---|
| `block-non-bun-pm` | bb-spec-frontend | PreToolUse(Bash) | 拦截 `npm` / `yarn` / `pnpm` 的包管理动作,强制 `bun`;既有项目已存在匹配 lockfile(如 `package-lock.json`)时放行 |
| `git-workflow-guard` | bb-spec-core | PreToolUse(Bash) | 拦截 `main` / `master` 分支的 `git commit`;其余 git 流程动作(开分支 / push / worktree / merge / PR)放行并注入 git-workflow 纪律与实时 git 状态 |
| `dep-version-check` | bb-spec-core | PostToolUse(Write\|Edit) | 编辑依赖文件后注入「先查官方最新版」自检提示 |
---

## 🧪 测试

```bash
bash tests/validate.sh
```

校验多 plugin 结构:marketplace.json 有效性与 plugin 条目一致性(每个 `source` 都指向真实存在、且 name 匹配的 plugin 目录)、各子 plugin 的 plugin.json 字段、agent frontmatter 完整性(必填字段、name 一致性、agent-type 合法值、安全基线段落)、skill SKILL.md 格式、hooks.json 有效性及脚本存在性、个人路径泄露检测。

CI 在 PR 和 push 到 main 时自动运行(`.github/workflows/ci.yml`)。

---

## 🛠️ 推荐配套

### AGENTS.md:项目约束与查询规矩

`/prd` 把对整个项目生效的约束(如「禁止泛型」「SQL join 不超过 3 张表」)写进项目根的 `AGENTS.md`,只属于某个功能的约束写进 PRD,同一条约束不会写两处。`AGENTS.md` 里还有一节「查功能、查问题的规矩」:回答「系统现在怎么做」必须先读代码并给出 `文件:行号`;查「为什么」用 `git log -L` 找到改过该函数的需求再读 PRD;PRD 和代码不一致时以代码为准。Claude Code 只读 `CLAUDE.md`、不直接读 `AGENTS.md`,所以 `/prd` 会确保项目根 `CLAUDE.md` 含一行 `@AGENTS.md` 把它导入。

### .bb-spec.yaml 项目配置

`/prd` 和 `/plan` 默认输出至 `.bb-spec/docs/` 下(`.bb-spec/docs/prd/`、`…/plan/`);运行时瞬态产物(如 webview 截图)落在与之平级的 `.bb-spec/.cache/`(自动 gitignore)。在项目根创建 `.bb-spec.yaml` 可覆盖 bb-spec 根目录:

```yaml
base_dir: my/bb  # → my/bb/docs/{prd,plan,test}/ 与 my/bb/.cache/;填 ./ 则直接落项目根
```

参考模板:[`.bb-spec.template.yaml`](./.bb-spec.template.yaml)。

---

## ⚙️ Hook 开关速查

| 场景 | 开关 |
|---|---|
| 临时允许 npm / yarn / pnpm | 临时禁用 `bb-spec-frontend` |
| 临时允许 main commit | 临时禁用 `bb-spec-core` |
| 跳过 Stop 自检 | 当前无开关——这是核心铁律,不建议跳过 |

---

## 💡 设计渊源:借鉴与对比

BB-Spec 站在三个优秀项目的肩上。它们各自塑造了 BB-Spec 设计的不同部分——下表致谢其所长,并说明 BB-Spec 借鉴了什么、又把这个想法推进到了哪一步。

| 项目 | 它最擅长 | BB-Spec 借鉴并强化的点 |
|---|---|---|
| [**Superpowers**](https://github.com/obra/Superpowers)(obra)—— 一套完整的编码代理方法论 | 端到端分阶段工作流、子代理驱动开发 + 分阶段审查、TDD 红-绿-重构、git worktree 隔离、苏格拉底式头脑风暴、可组合技能库 | 整条 `prd → ship` 流水线骨架、按角色拆分子 Agent 协作、强制 TDD、多阶段 / 对抗式审查、对话先行的需求澄清 |
| [**ECC**](https://github.com/affaan-m/ECC)(affaan-m)—— 一个 agent harness「操作系统」 | agents / skills / hooks / rules 的大规模分层体系、被动 hook 自动强制、规则即基础设施、跨会话记忆持久化 | 分层、可独立安装的子插件套件、用被动 hook 强制纪律、把工程规范沉淀为可加载的约束 skill |
| [**skills**](https://github.com/mattpocock/skills)(mattpocock)——「Skills For Real Engineers」 | 直击真实失败模式(需求不对齐 / 冗长 / 质量 / 架构)、深度提问对齐意图、共享域语言、用户调用 vs 模型调用双形态 skill、垂直切片 | 质疑前置、动手前先对话锁定需求、双触发 skill(slash 命令 + 模型自动触发)、只留一份事实来源的极简组织 |

**BB-Spec 自己的取舍**——三者都未同时具备的差异化:

- **三 Agent 隔离执行**——Impl Agent *物理上看不到 PRD*,只看测试,无法「照着意图蒙混」;测试、实现、审查由互相看不见的三方分别完成。
- **磁盘文档作为唯一交接物**——每阶段交接的是文件而非会话记忆,因此跨会话、`/clear` 乃至换一个模型接手都能无损续接。
- **代码 ⇄ PRD 经 git 双向可查**——代码是唯一事实来源,PRD 只写为什么;每个 commit 带需求标记,从功能能找到代码,从函数能查回当时的需求与取舍,中间没有需要人工同步、会过时的规则文档。

---

## 📜 License

MIT —— 详见 [LICENSE](./LICENSE)。

<p align="center">
  <sub>Built with ❤️ for the Claude Code community.</sub>
</p>
