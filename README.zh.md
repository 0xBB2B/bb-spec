<p align="center">
  <img src="./assets/banner.jpg" alt="bb-spec — A light-weight protocol for building trust" width="100%" />
</p>

<h1 align="center">📐 BB-Spec</h1>

<p align="center">
  <strong>一条 spec 驱动的 Claude Code 流水线,把模糊需求一路带到可交付的代码。</strong>
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
  <a href="#-核心流水线-spec--ship">流水线</a> ·
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
| `/spec` | 把需求拆成一规则一文档 | 新需求开工 |
| `/plan` | spec → 函数级实施计划 | spec 就绪 |
| `/exec` | 三 Agent 隔离跑 Test→Impl→Review | plan 就绪 |
| `/review` | 多 finder 并行 + 对抗验证 | 提 PR 前 |
| `/git-push` | pre-review 自查 + 推 + 开 PR | 准备发版 |

四条支线随时可介入:`/git-clone`（拉远程项目到本地 + 落 `.bb-spec.yaml` 一次性 onboarding）、`/init-spec`（存量项目反向 spec 化）、`/revise`（任何偏差按根因回到正确阶段）、`/doc-update`（全仓 spec/文档/代码一致性体检）。

可选上游:`/prd`(PM / 需求方头脑风暴 PRD,由 bb-spec-product 单独提供)。

---

## 🔁 核心流水线 `spec → ship`

```
 (可选) /git-clone ──► 拉远程 + 落 .bb-spec.yaml
                  │
 (可选) /prd ──► PRD 文档
                  │
 /init-spec ──►  /spec ──► /plan ──► /exec ──► /test-* ──► /review ──► /git-push
 (存量项目)      做什么     怎么做    Red→Green→Review  e2e        并发+对抗     pre-review+开 PR
                                                                                       │
        ┌──────────────────────────────────────────────────────────────────────────────┘
        │
        ▼ /revise(随时介入,按根因路由)
          spec 缺陷 → /spec   ·   实现偏离 → /exec   ·   review 问题 → 定向修复

 /doc-update(定期 / 按需)— 扫全仓漂移 → 默认改 spec/文档,代码明显不合理才停下问 → 挂 /revise
```

**为什么这条流水线靠得住**——每次交接物都是**磁盘上的文档**、不是会话里的临时记忆,这是它能断点续、能换 AI 接手、能逐级追溯的根本。

### 🎯 阶段一览

- **`/git-clone`** — *一次性 onboarding*:把远程仓库拉到本地、写好 `.bb-spec.yaml`。
  - **AskUserQuestion 两连**:① 单 repo / 多 repo 工作区(决定目录结构) ② `base_dir`(决定后续所有 bb-spec 交付物落点)
  - **多 repo 工作区**建统一父目录 + 各成员仓库独立 clone(复原构建工具期待的相对布局),禁嵌套、禁覆盖
  - 职责严格收敛:**只**拿代码 + 写 `base_dir`,不读代码、不装依赖、不触发 `/init-spec`

- **`/init-spec`** — *反向* spec 化存量项目。
  - 读现有代码 + 文档,把**已在执行的隐式规范**提炼成 ≤100 行、一文一规则的 spec,落点与 `/spec` 一致
  - 庞大项目按分区拆 subagent 并发提取;仅首次接入跑一次

- **`/spec`** — 通过对话做需求拆解,回答**「做什么」**。
  - 一文一规则、≤100 行、只说一件事 + 一个例子,互不重叠
  - 轻量 `INDEX.md` 统领,读者先扫索引再按需加载

- **`/plan`** — spec → 自包含、**函数级**实施计划,回答**「怎么做」**。
  - 每文件一独立问题,详细到函数名与职责;声明式产物(DDL / API 契约 / 配置)**直接内联最终成品**,exec 原样落盘
  - 调用即进入 **plan 模式只读对齐**,批准后才落盘;**新增第三方依赖单独成节**,批准即视为 version-policy 要求的用户同意
  - 自动识别规模:小需求单 topic;多领域 / 大批 spec 涌入切**分批 ROADMAP**——含依赖链 + 验证门,一次只展开当前批,过门后自动展开下一批

- **`/exec`** — **三 Agent 隔离执行**,核心反作弊设计。
  - *Test* Agent 只读 spec 规则写失败测试(Red)
  - *Impl* Agent **看不到 spec**,只看测试 + 函数清单写实现(Green),无法「照着意图作弊」;新增第三方库受 plan 已批依赖清单约束
  - *Review* Agent 对照 spec 检查,只读不写
  - 每步进度写 `PROGRESS.md`,token 耗尽也能**无损续接**

- **`/test-webview`** — 前端 / 网页项目的**交互验收**。
  - Docker 整栈拉起(首次确认后记住,跑完 `down -v` 清理),浏览器 MCP 驱动真实浏览器
  - **每个用例派隔离串行 subagent**,几百用例也不爆主上下文;全程串行(浏览器单实例)
  - 用例自动从 spec / plan / PRD 归纳生成;跑前**覆盖对齐**,缺口不静默漏测;失败转 `/revise`
  - 需浏览器 MCP(playwright / chrome-devtools)

- **`/test-api`** — 后端**接口 e2e**。
  - `compose.e2e.yaml` 拉起整栈,md 用例**机械渲染为单文件 Bun TS runner**,`bun run` 一次跑完
  - **零 subagent、零并发**——HTTP 是确定性脚本,时钟共享禁并发
  - **时间敏感规则**(token 过期、订单超时、积分过期)经 `/test/advance-time`、`/test/backdate`、`/test/trigger-job` 协议测
  - 应用侧**产双 image**:test image 带 `/test/*` 路由 + `ENV TESTAPI=1`;生产 image **物理排除** `/test/*` 源码;`/test/healthz` 探测失败即中止、禁降级

- **`/review`** — Workflow 编排、**对抗验证**的本地 PR review。
  - Phase 1 并发 **6 个 finder**:代码质量 / 安全 / 简洁性 / 鲁棒性 / 文档同步 / **Codex 跨模型独立** review,schema 强制结构化
  - Phase 2 每条 🔴/🟡 由 **3 个独立怀疑视角**重判(重要性 / 根源性 / 不修风险),多数决去留
  - 只读、绝不自动改码;要求 Claude Code ≥ 2.1.154

- **`/revise`** — 随时介入的异常处理。
  - 把偏差**归因**为三类:*spec 缺陷*(→ `/spec`)、*实现偏离*(→ `/exec`)、*需求变更*
  - 所有需修复的 review 发现都汇入此处

- **`/git-push`** — 用户触发的推送 + PR 流程(单 / 多仓库)。
  - 存在 spec `INDEX.md` 时先跑**分支规范自查(pre-review)**:subagent 比对 spec vs 分支 diff,违规循环修复
  - 起草 **6 段 PR 描述**(背景 / 需求 / 方案 / 结果 / 测试 / 规范,< 50 行)直接用作 PR body

- **`/doc-update`** — 全仓 spec / 文档 / 代码**一致性体检**。
  - 六类漂移定位:spec-stale / doc-stale / code-violation / spec-conflict / orphan-index / uncovered-rule
  - **代码是事实、spec/文档追平代码**;代码明显违背硬约束才停下问、挂回 `/revise` 走 TDD
  - 与 `/init-spec`(零→有)、`/revise`(单点)、`/review` 的 `review-doc-sync`(PR diff)划清边界

**附带产物**

- **12 个编排 subagent**(被上述环节驱动):`test-engineer` / `impl-engineer` / `spec-reviewer` / `webview-test-runner` / `review-code-quality` / `review-security` / `review-simplicity` / `review-robustness` / `review-doc-sync` / `review-codex` / `pre-reviewer` / `rule-extractor`
- **4 个被动 hook**(自动生效):拦截 npm/yarn、拦截 main commit、依赖版本自检、Stop 四项自检

---

## 🧩 配套约束 Skills

向流水线灌入规则——只装你需要的层。

### bb-spec-product — 产品需求(流水线上游)

- **`prd`** — PM / 需求方与 AI 头脑风暴:质疑前置(允许否决)→ 发散 → 收敛,产出自包含 PRD——目标 / 非目标、带优先级的用户故事(每条 P0 挂具体用例与验收标准)、留给工程师的开放问题;不依赖 git 仓库与代码上下文,`/spec` 直接消费

> **PM 不用装 Claude Code**:每次发版自动打包 [`bb-spec-prd-skill.zip`](https://github.com/0xBB2B/bb-spec/releases/latest/download/bb-spec-prd-skill.zip),下载后在 claude.ai 网页版 / 桌面版的 **Settings → Customize → Skills** 上传即可单独使用(需付费计划并启用代码执行),产出的 PRD 以可下载文件交付给工程师。

### bb-spec-core — 通用纪律

- **`tdd-workflow`** — Red-Green-Refactor 纪律,覆盖增 / 改 / 删三场景标准流程
- **`version-policy`** — 官方库 / 标准库优先,新增第三方库须经用户明确同意(plan 批准的依赖清单视为已同意);钉版本前先查依赖官方最新版,禁凭训练记忆
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

BB-Spec 拆成**五个可独立安装的子 plugin**——只装你需要的约束层。

先添加一次 marketplace(在 Claude Code 里执行):

```bash
/plugin marketplace add 0xBB2B/bb-spec
```

再按需安装对应层:

| 子 plugin | 装了得到什么 | 安装命令 |
|---|---|---|
| **bb-spec-core** _(推荐基座)_ | TDD / 版本策略 / Git 纪律 + 3 个被动 hook | `/plugin install bb-spec-core@0xbb2b` |
| **bb-spec-workflow** _(核心功能)_ | spec → plan → exec → test-webview / test-api → review → revise → git-push、git-clone 一次性初始化、init 反向 spec、doc-update 全仓一致性维护 + 12 个 subagent | `/plugin install bb-spec-workflow@0xbb2b` |
| **bb-spec-product** | /prd 需求头脑风暴 → 含具体用例的 PRD 文档(PM / 需求方使用) | `/plugin install bb-spec-product@0xbb2b` |
| **bb-spec-backend** | Go / REST API / 数据库 / 认证 / 授权 / 可观测性 / 服务治理 / 配置约束 | `/plugin install bb-spec-backend@0xbb2b` |
| **bb-spec-frontend** | Vue 3 + TS + Vite + Tailwind + bun 技术栈与工程约定(含 bun hook) | `/plugin install bb-spec-frontend@0xbb2b` |

按需取用——例如只要纪律与工作流、不要技术栈意见:装 `bb-spec-core` + `bb-spec-workflow`;PM / 需求方的机器上只装 `bb-spec-product`;想要全套:五个全装。

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
    "bb-spec-product@0xbb2b": false,
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

五个子 plugin 共用同一条同步版本线。

---

## 🪝 默认启用的 Hooks

每个 hook 随「负责该关注点的子 plugin」一起发布——装了对应 plugin 才有。

| Hook | 所属子 plugin | 触发时机 | 作用 |
|---|---|---|---|
| `block-non-bun-pm` | bb-spec-frontend | PreToolUse(Bash) | 拦截 `npm` / `yarn` / `pnpm` 的包管理动作,强制 `bun`;既有项目已存在匹配 lockfile(如 `package-lock.json`)时放行 |
| `git-workflow-guard` | bb-spec-core | PreToolUse(Bash) | 拦截 `main` / `master` 分支的 `git commit`;其余 git 流程动作(开分支 / push / worktree / merge / PR)放行并注入 git-workflow 纪律与实时 git 状态 |
| `dep-version-check` | bb-spec-core | PostToolUse(Write\|Edit) | 编辑依赖文件后注入「先查官方最新版」自检提示 |
| `stop-self-check` | bb-spec-core | Stop | 任务结束前强制四项自检:临时文件 / 改动范围 / 孤立残留 / 历史包袱 |

---

## 🧪 测试

```bash
bash tests/validate.sh
```

校验多 plugin 结构:marketplace.json 有效性与 plugin 条目一致性(每个 `source` 都指向真实存在、且 name 匹配的 plugin 目录)、各子 plugin 的 plugin.json 字段、agent frontmatter 完整性(必填字段、name 一致性、agent-type 合法值、安全基线段落)、skill SKILL.md 格式、hooks.json 有效性及脚本存在性、个人路径泄露检测。

CI 在 PR 和 push 到 main 时自动运行(`.github/workflows/ci.yml`)。

---

## 🛠️ 推荐配套

### CLAUDE.md 模板

仓库根目录的 [`CLAUDE.template.md`](./CLAUDE.template.md) 是配套的「铁律索引」参考。**不会自动安装**——按需复制到你的 `~/.claude/CLAUDE.md` 或项目根 `CLAUDE.md`,按需裁剪。

### .bb-spec.yaml 项目配置

`/prd`、`/spec` 和 `/plan` 默认输出至 `.bb-spec/docs/` 下(`.bb-spec/docs/prd/`、`…/spec/`、`…/plan/`);运行时瞬态产物(如 webview 截图)落在与之平级的 `.bb-spec/.cache/`(自动 gitignore)。在项目根创建 `.bb-spec.yaml` 可覆盖 bb-spec 根目录:

```yaml
base_dir: my/bb  # → my/bb/docs/{prd,spec,plan,test}/ 与 my/bb/.cache/;填 ./ 则直接落项目根
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
| [**Superpowers**](https://github.com/obra/Superpowers)(obra)—— 一套完整的编码代理方法论 | 端到端分阶段工作流、子代理驱动开发 + 分阶段审查、TDD 红-绿-重构、git worktree 隔离、苏格拉底式头脑风暴、可组合技能库 | 整条 `spec → ship` 流水线骨架、按角色拆分子 Agent 协作、强制 TDD、多阶段 / 对抗式审查、对话先行的需求澄清 |
| [**ECC**](https://github.com/affaan-m/ECC)(affaan-m)—— 一个 agent harness「操作系统」 | agents / skills / hooks / rules 的大规模分层体系、被动 hook 自动强制、规则即基础设施、跨会话记忆持久化 | 分层、可独立安装的子插件套件、用被动 hook 强制纪律、把工程规范沉淀为可加载的约束 skill |
| [**skills**](https://github.com/mattpocock/skills)(mattpocock)——「Skills For Real Engineers」 | 直击真实失败模式(需求不对齐 / 冗长 / 质量 / 架构)、深度提问对齐意图、共享域语言、用户调用 vs 模型调用双形态 skill、垂直切片 | 质疑前置、动手前先对话锁定需求、双触发 skill(slash 命令 + 模型自动触发)、一文一规则的极简组织 |

**BB-Spec 自己的取舍**——三者都未同时具备的差异化:

- **三 Agent 隔离执行**——Impl Agent *物理上看不到 spec*,只看测试,无法「照着意图蒙混」;测试、实现、审查由互相看不见的三方分别完成。
- **磁盘文档作为唯一交接物**——每阶段交接的是文件而非会话记忆,因此跨会话、`/clear` 乃至换一个模型接手都能无损续接。
- **spec ⇄ code 双向闭环**——不止 spec → code,还能用 `/init-spec` 从既有代码反向沉淀 spec、用 `/doc-update` 在代码漂移时持续追平。

---

## 📜 License

MIT —— 详见 [LICENSE](./LICENSE)。

<p align="center">
  <sub>Built with ❤️ for the Claude Code community.</sub>
</p>
