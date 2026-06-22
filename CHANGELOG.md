# Changelog

## [8.0.0](https://github.com/0xBB2B/bb-spec/compare/v7.7.0...v8.0.0) (2026-06-22)


### ⚠ BREAKING CHANGES

* **init-spec:** skill 名 init 改为 init-spec。原 /init 入口失效，请改用 /init-spec（或全名 /bb-spec-workflow:init-spec）。引用 init skill 的外部脚本 / 文档 / 依赖该 skill name 的配置都需同步替换。

### Features

* **init-spec:** 重命名 init skill 为 init-spec 以避开 Claude Code 内置 /init 冲突 ([#133](https://github.com/0xBB2B/bb-spec/issues/133)) ([1e84e55](https://github.com/0xBB2B/bb-spec/commit/1e84e55a5a72b63e3ad47ecce4aa1a47beacc800))

## [7.7.0](https://github.com/0xBB2B/bb-spec/compare/v7.6.0...v7.7.0) (2026-06-20)


### Features

* **spec:** description 全面中文化并改造为「定位+机制+触发+跳过」模板 ([#131](https://github.com/0xBB2B/bb-spec/issues/131)) ([a54556f](https://github.com/0xBB2B/bb-spec/commit/a54556fcf68dbb19dc311ebb3e3256af07cb6da6))

## [7.6.0](https://github.com/0xBB2B/bb-spec/compare/v7.5.0...v7.6.0) (2026-06-17)


### Features

* **git-workflow:** 顶部新增"路径选择决策表"分流多 repo workspace，description 追加触发词 ([#129](https://github.com/0xBB2B/bb-spec/issues/129)) ([7c0ea45](https://github.com/0xBB2B/bb-spec/commit/7c0ea452e9a1bd51a1d9ab4b68ac5c0793b19d8b))

## [7.5.0](https://github.com/0xBB2B/bb-spec/compare/v7.4.0...v7.5.0) (2026-06-17)


### Features

* **hooks:** block-main-commit 升级为 git-workflow-guard，git 流程操作放行并注入 git-workflow 纪律 ([#127](https://github.com/0xBB2B/bb-spec/issues/127)) ([0d0e416](https://github.com/0xBB2B/bb-spec/commit/0d0e41661eb9548887cb462ca7476e7f2b608e54))

## [7.4.0](https://github.com/0xBB2B/bb-spec/compare/v7.3.0...v7.4.0) (2026-06-17)


### Features

* **git-workflow:** 开新任务用 AskUserQuestion 询问 worktree/切分支（默认 worktree），worktree 统一收敛到 ~/.bb-spec/worktrees/ ([#125](https://github.com/0xBB2B/bb-spec/issues/125)) ([390ceca](https://github.com/0xBB2B/bb-spec/commit/390ceca3f3f64b40aed6394e235347e9b33bd574))

## [7.3.0](https://github.com/0xBB2B/bb-spec/compare/v7.2.0...v7.3.0) (2026-06-17)


### Features

* **git-workflow:** 多 repo 工作区统一父目录 + 每 repo 各拉 worktree ([#123](https://github.com/0xBB2B/bb-spec/issues/123)) ([ab92615](https://github.com/0xBB2B/bb-spec/commit/ab92615cd3fa7398053c1f7531b6b62b54ecab1e))

## [7.2.0](https://github.com/0xBB2B/bb-spec/compare/v7.1.0...v7.2.0) (2026-06-17)


### Features

* **spec:** 启动即进入 plan 模式，方案确认后再落盘 ([#121](https://github.com/0xBB2B/bb-spec/issues/121)) ([cf5b277](https://github.com/0xBB2B/bb-spec/commit/cf5b277a6ae11bca9450ef36920daf820cb4f29a))

## [7.1.0](https://github.com/0xBB2B/bb-spec/compare/v7.0.0...v7.1.0) (2026-06-17)


### Features

* **workflow,core,frontend:** 封闭式多选项交互统一改用 AskUserQuestion ([#119](https://github.com/0xBB2B/bb-spec/issues/119)) ([2258f58](https://github.com/0xBB2B/bb-spec/commit/2258f5839d2bee0df8ae279c3e284c5821942790))

## [7.0.0](https://github.com/0xBB2B/bb-spec/compare/v6.4.0...v7.0.0) (2026-06-17)


### ⚠ BREAKING CHANGES

* **plugin:** .bb-spec.yaml 配置键 docs_dir 重命名为 base_dir，值不再含 docs 后缀。 迁移：将 `docs_dir: <path>/docs` 改为 `base_dir: <path>`（去掉键名，值去掉尾部 /docs）。 未创建 .bb-spec.yaml 的项目默认行为不变（仍输出至 .bb-spec/docs/）。

### Features

* **plugin:** 配置上提为 base_dir，docs 与 .cache 平级、瞬态产物收归 .cache ([#117](https://github.com/0xBB2B/bb-spec/issues/117)) ([5f6e1d1](https://github.com/0xBB2B/bb-spec/commit/5f6e1d16124b5b6f9b724627ba75c577956f405b))

## [6.4.0](https://github.com/0xBB2B/bb-spec/compare/v6.3.0...v6.4.0) (2026-06-16)


### Features

* **git-workflow:** 按在途工作状态决定开分支方式 ([#115](https://github.com/0xBB2B/bb-spec/issues/115)) ([b838326](https://github.com/0xBB2B/bb-spec/commit/b838326121f8200d2abc3b27ca6753b965672beb))

## [6.3.0](https://github.com/0xBB2B/bb-spec/compare/v6.2.0...v6.3.0) (2026-06-16)


### Features

* webview 用例产出收归 test-webview、跑前覆盖对齐，回退截图 /tmp 约定 ([#113](https://github.com/0xBB2B/bb-spec/issues/113)) ([8860bd6](https://github.com/0xBB2B/bb-spec/commit/8860bd6269b872f9671cfad8c90ceb2938bde33b))

## [6.2.0](https://github.com/0xBB2B/bb-spec/compare/v6.1.0...v6.2.0) (2026-06-16)


### Features

* **webview-test-runner:** 截图统一收进 /tmp 专属临时目录 ([#111](https://github.com/0xBB2B/bb-spec/issues/111)) ([2aa986e](https://github.com/0xBB2B/bb-spec/commit/2aa986ea5a1786af8da059f39bf843ecd6202eec))


### Bug Fixes

* **hooks:** 回滚临时文件强制 /tmp 约束 ([#110](https://github.com/0xBB2B/bb-spec/issues/110)) ([cc3ca5d](https://github.com/0xBB2B/bb-spec/commit/cc3ca5d3f384e8f5d978823ad143908a7d3e31d2))

## [6.1.0](https://github.com/0xBB2B/bb-spec/compare/v6.0.0...v6.1.0) (2026-06-15)


### Features

* **hooks:** 临时文件统一放 /tmp 并强制清除 ([#108](https://github.com/0xBB2B/bb-spec/issues/108)) ([c73e792](https://github.com/0xBB2B/bb-spec/commit/c73e79282e13b8298ac44c0f09aaeeb66d852b8a))

## [6.0.0](https://github.com/0xBB2B/bb-spec/compare/v5.19.0...v6.0.0) (2026-06-15)


### ⚠ BREAKING CHANGES

* **test-webview,plan:** 用例落盘路径由 webview/<category>/<case>.md 改为 webview/<frontend>/<category>/<case>.md；target 字段由单前端可省改为始终必填且须与顶层目录段一致。已按旧结构生成的用例需迁移到对应 <frontend>/ 目录下才合规。

### Features

* **test-webview,plan:** webview 用例目录统一按前端分层 ([#106](https://github.com/0xBB2B/bb-spec/issues/106)) ([dfa9b86](https://github.com/0xBB2B/bb-spec/commit/dfa9b86a0f1d4bfe312cb8ea787e6192587200f0))

## [5.19.0](https://github.com/0xBB2B/bb-spec/compare/v5.18.0...v5.19.0) (2026-06-15)


### Features

* **test-webview:** 新增网页交互验证工作流，plan/exec 联动生成用例 ([#104](https://github.com/0xBB2B/bb-spec/issues/104)) ([8f7223a](https://github.com/0xBB2B/bb-spec/commit/8f7223a805b3c663c7b464efa315fec0ff357641))

## [5.18.0](https://github.com/0xBB2B/bb-spec/compare/v5.17.0...v5.18.0) (2026-06-15)


### Features

* **git-workflow:** worktree 由禁用改为允许但强制与 repo 隔离存放 ([#102](https://github.com/0xBB2B/bb-spec/issues/102)) ([d741d6b](https://github.com/0xBB2B/bb-spec/commit/d741d6b8b66a76638149b2f4b60f8ef336a979c8))

## [5.17.0](https://github.com/0xBB2B/bb-spec/compare/v5.16.0...v5.17.0) (2026-06-13)


### Features

* **exec:** Review 偏差按归因分流，impl-defect 自决不打断用户 ([#100](https://github.com/0xBB2B/bb-spec/issues/100)) ([b16a3e2](https://github.com/0xBB2B/bb-spec/commit/b16a3e25dab1b959c0d95763b16b9733d784f228))

## [5.16.0](https://github.com/0xBB2B/bb-spec/compare/v5.15.1...v5.16.0) (2026-06-12)


### Features

* **workflow:** 编排 subagent 全部收口 agents/ 并显式定模，pre-review 修复走 /revise ([#98](https://github.com/0xBB2B/bb-spec/issues/98)) ([540f78b](https://github.com/0xBB2B/bb-spec/commit/540f78b2603ce77cd65092dd94768fef9813f025))

## [5.15.1](https://github.com/0xBB2B/bb-spec/compare/v5.15.0...v5.15.1) (2026-06-12)


### Bug Fixes

* **exec,revise:** 修正 subagent 派发名前缀为 bb-spec-workflow ([#96](https://github.com/0xBB2B/bb-spec/issues/96)) ([4939a99](https://github.com/0xBB2B/bb-spec/commit/4939a99294e272c2f60efd6de824d993c2518124))

## [5.15.0](https://github.com/0xBB2B/bb-spec/compare/v5.14.0...v5.15.0) (2026-06-12)


### Features

* **hooks:** 移除 stop-auto-tests / stop-auto-commit 可选 hook ([#93](https://github.com/0xBB2B/bb-spec/issues/93)) ([ea9bc8a](https://github.com/0xBB2B/bb-spec/commit/ea9bc8a5dc04cca9eb1cec9fb380e825d967f72d))
* **review:** 逐个解决模式修复统一走 /revise，文档同步类自动修复，质量/安全优先排序 ([#95](https://github.com/0xBB2B/bb-spec/issues/95)) ([b9603cb](https://github.com/0xBB2B/bb-spec/commit/b9603cb249d6cd64d544059c029d167da77b2652))

## [5.14.0](https://github.com/0xBB2B/bb-spec/compare/v5.13.0...v5.14.0) (2026-06-12)


### Features

* **review:** 逐个解决模式修复后强制跑一遍项目测试 ([#91](https://github.com/0xBB2B/bb-spec/issues/91)) ([ca9a4c7](https://github.com/0xBB2B/bb-spec/commit/ca9a4c7914c48c321fc6ba855aadc0e880763301))

## [5.13.0](https://github.com/0xBB2B/bb-spec/compare/v5.12.0...v5.13.0) (2026-06-12)


### Features

* **review:** finder 与验证者派工钉死 opus 模型 ([#89](https://github.com/0xBB2B/bb-spec/issues/89)) ([52a5f4f](https://github.com/0xBB2B/bb-spec/commit/52a5f4fd0d51ea1ed015740c43cbae14f39976e8))

## [5.12.0](https://github.com/0xBB2B/bb-spec/compare/v5.11.0...v5.12.0) (2026-06-11)


### Features

* **review:** 报告表格 by 列图标后附 finder 文字名 ([#87](https://github.com/0xBB2B/bb-spec/issues/87)) ([755ba77](https://github.com/0xBB2B/bb-spec/commit/755ba77652f730c70dfedb311166fc8219deeec0))

## [5.11.0](https://github.com/0xBB2B/bb-spec/compare/v5.10.0...v5.11.0) (2026-06-11)


### Features

* **review:** 报告简表表格化并为 finder 分配身份图标 ([#85](https://github.com/0xBB2B/bb-spec/issues/85)) ([c880141](https://github.com/0xBB2B/bb-spec/commit/c880141bcce2574a60954eaa51338fa92fc49c77))

## [5.10.0](https://github.com/0xBB2B/bb-spec/compare/v5.9.0...v5.10.0) (2026-06-11)


### Features

* **review:** 逐个解决模式重组为四段展开并新增根源性自检 ([#83](https://github.com/0xBB2B/bb-spec/issues/83)) ([2d77ee1](https://github.com/0xBB2B/bb-spec/commit/2d77ee165038c18be48be7bd0e8e517459e2cda2))

## [5.9.0](https://github.com/0xBB2B/bb-spec/compare/v5.8.0...v5.9.0) (2026-06-11)


### Features

* **review:** review 报告改为逐个对话解决模式 ([#81](https://github.com/0xBB2B/bb-spec/issues/81)) ([4bc4497](https://github.com/0xBB2B/bb-spec/commit/4bc4497beace4c93a8baf758e4be26b4acd714fd))

## [5.8.0](https://github.com/0xBB2B/bb-spec/compare/v5.7.0...v5.8.0) (2026-06-11)


### Features

* 新增 bb-spec-product 插件，/prd 头脑风暴产出 PRD 并打通 /spec 消费 ([#77](https://github.com/0xBB2B/bb-spec/issues/77)) ([2b0d817](https://github.com/0xBB2B/bb-spec/commit/2b0d8174461ebe99fe611987a20bd6b88e6f4799))


### Bug Fixes

* **review:** workflow 输入改为脚本内嵌，砍掉 args 传参通道 ([#80](https://github.com/0xBB2B/bb-spec/issues/80)) ([ab4e65e](https://github.com/0xBB2B/bb-spec/commit/ab4e65e8988bfa39c5f5541723a0718068bcc900))
* validate.sh frontmatter 提取改单进程 awk，消除 CI SIGPIPE 竞态 ([#79](https://github.com/0xBB2B/bb-spec/issues/79)) ([68385b7](https://github.com/0xBB2B/bb-spec/commit/68385b7955777af1222a8067314fdc37d08fc47c))

## [5.7.0](https://github.com/0xBB2B/bb-spec/compare/v5.6.0...v5.7.0) (2026-06-11)


### Features

* **exec,review:** impl-engineer 与各 review agent 固化 model: opus ([#75](https://github.com/0xBB2B/bb-spec/issues/75)) ([b9de213](https://github.com/0xBB2B/bb-spec/commit/b9de213cbe8be8035817505f04ebf8f1e525d329))

## [5.6.0](https://github.com/0xBB2B/bb-spec/compare/v5.5.0...v5.6.0) (2026-06-10)


### Features

* **golang-constraints:** 区分业务分层与支撑包 ([#72](https://github.com/0xBB2B/bb-spec/issues/72)) ([e45642e](https://github.com/0xBB2B/bb-spec/commit/e45642e6a56aa782bbb6e798e063556e345acdfb))

## [5.5.0](https://github.com/0xBB2B/bb-spec/compare/v5.4.0...v5.5.0) (2026-06-10)


### Features

* **plan,exec,version-policy:** plan 批准即授权新增第三方依赖清单，exec 不得超出 ([#70](https://github.com/0xBB2B/bb-spec/issues/70)) ([a444eb6](https://github.com/0xBB2B/bb-spec/commit/a444eb6a2902d468e697ef86236d9d4f43dc93ed))

## [5.4.0](https://github.com/0xBB2B/bb-spec/compare/v5.3.0...v5.4.0) (2026-06-10)


### Features

* **plan,exec:** 声明式产物强制内联成品，禁散文转述 ([#68](https://github.com/0xBB2B/bb-spec/issues/68)) ([551237a](https://github.com/0xBB2B/bb-spec/commit/551237a22240749d93bf1eda860a4388954fc19e))

## [5.3.0](https://github.com/0xBB2B/bb-spec/compare/v5.2.0...v5.3.0) (2026-06-10)


### Features

* **version-policy,golang-constraints:** 官方库优先，新增第三方库须用户同意 ([#66](https://github.com/0xBB2B/bb-spec/issues/66)) ([6a4df87](https://github.com/0xBB2B/bb-spec/commit/6a4df870bacd90a74139805601e3fe4647279dc8))

## [5.2.0](https://github.com/0xBB2B/bb-spec/compare/v5.1.0...v5.2.0) (2026-06-10)


### Features

* **spec,plan,exec:** 断点恢复叙事更新为跨会话续接，裁决点接入 AskUserQuestion ([#64](https://github.com/0xBB2B/bb-spec/issues/64)) ([4205e2b](https://github.com/0xBB2B/bb-spec/commit/4205e2b3dafa0f353afb803680f9d2b3dc7ab742))

## [5.1.0](https://github.com/0xBB2B/bb-spec/compare/v5.0.0...v5.1.0) (2026-06-09)


### Features

* **plan,exec:** plan 模式 gate + 规模分流 + 分批懒生成路线图 ([#61](https://github.com/0xBB2B/bb-spec/issues/61)) ([a352225](https://github.com/0xBB2B/bb-spec/commit/a352225f02bd699476b30832ec5cd75a4a5879bc))

## [5.0.0](https://github.com/0xBB2B/bb-spec/compare/v4.1.0...v5.0.0) (2026-06-08)


### ⚠ BREAKING CHANGES

* **plugin:** 单个 bb-spec plugin 已拆为 bb-spec-core / bb-spec-workflow / bb-spec-backend / bb-spec-frontend 四个子 plugin。老用户需先 /plugin uninstall bb-spec，再按需重装对应子 plugin。

### Features

* **plugin:** 拆分为 core/workflow/backend/frontend 四个可独立安装的子 plugin ([#58](https://github.com/0xBB2B/bb-spec/issues/58)) ([b7de60a](https://github.com/0xBB2B/bb-spec/commit/b7de60a60d0cc7b3ac6e6b6a412cfeff4a6ebeab))
* **spec,init:** 需求澄清改递进式深挖 + 加可证伪红线挡空泛规则 ([#54](https://github.com/0xBB2B/bb-spec/issues/54)) ([faa3c76](https://github.com/0xBB2B/bb-spec/commit/faa3c768bcad61e98c295d0b5e4865ba123f2570))
* 新增全栈技术框架约束套件（认证/授权/可观测/服务工程/前端） ([#56](https://github.com/0xBB2B/bb-spec/issues/56)) ([e636896](https://github.com/0xBB2B/bb-spec/commit/e6368963c14e323f62be13e92b561ff5f204c5bd))


### Bug Fixes

* **auth-constraints:** device_id 不强制 UUID 格式，兼容 Android ID 等平台标识 ([#57](https://github.com/0xBB2B/bb-spec/issues/57)) ([68a9609](https://github.com/0xBB2B/bb-spec/commit/68a9609c51ea31a14d1cfba164bec95752003256))

## [4.1.0](https://github.com/0xBB2B/bb-spec/compare/v4.0.0...v4.1.0) (2026-06-07)


### Features

* **skills:** 拆出 database-constraints，错误码并入 api-design ([#52](https://github.com/0xBB2B/bb-spec/issues/52)) ([642d438](https://github.com/0xBB2B/bb-spec/commit/642d438c18d3d2cdcfdbf9adb0244212bdc67802))

## [4.0.0](https://github.com/0xBB2B/bb-spec/compare/v3.1.0...v4.0.0) (2026-06-05)


### ⚠ BREAKING CHANGES

* **review:** /review 的执行机制由"5 agent 并行 + 主 agent 三维自评分过滤"替换为 Workflow 工具编排——Find 阶段 5 个 finder 并行产出 schema 结构化发现，纯代码去重与交叉验证标记后，每条 BLOCKER/IMPORTANT 发现交由 3 个独立怀疑视角（重要性/根源性/不修风险）对抗验证、多数决定去留。原三维评分公式与"已过滤摘要"机制删除，被否决项改以对抗验证 verdict 单行透明化呈现。本 skill 自此依赖 Workflow 工具，要求 Claude Code ≥ 2.1.154，低于该版本 /review 不可用且不提供降级路径。迁移：升级 Claude Code 至 2.1.154+ 即可，命令用法（/review <base-branch>）不变。另清理 v3.0.0 语言无关化漏改的"输出中文"残留。

### Features

* **review:** /review 改为 Workflow 编排的多维审查 + 对抗性验证 ([#50](https://github.com/0xBB2B/bb-spec/issues/50)) ([b166c71](https://github.com/0xBB2B/bb-spec/commit/b166c710890e331a6f233461958b74125f6cb37d))

## [3.1.0](https://github.com/0xBB2B/bb-spec/compare/v3.0.0...v3.1.0) (2026-06-05)


### Features

* **vue-constraints,hooks:** 既有 lockfile 项目跟随原包管理器，不再强制 bun ([#48](https://github.com/0xBB2B/bb-spec/issues/48)) ([fe1114e](https://github.com/0xBB2B/bb-spec/commit/fe1114eee1d4c0fe9bad6dcac0cf98007b326757))

## [3.0.0](https://github.com/0xBB2B/bb-spec/compare/v2.1.0...v3.0.0) (2026-06-02)


### ⚠ BREAKING CHANGES

* skill 产出的默认语言从「强制中文」变为「跟随用户工作语言」。 同样的 /spec、/plan、/init 等调用，对非中文用户现在会产出其工作语言的文档与注释而非中文； 中文用户行为不变（用中文对话即得中文产出）。如需固定某语言，请在自己的 CLAUDE.md 中声明语言偏好。

### Features

* 工作流产出改为语言无关，不再强制中文输出 ([#45](https://github.com/0xBB2B/bb-spec/issues/45)) ([7107afe](https://github.com/0xBB2B/bb-spec/commit/7107afee985ca9ed5fb8a9eb633025105759b844))

## [2.1.0](https://github.com/0xBB2B/bb-spec/compare/v2.0.0...v2.1.0) (2026-06-02)


### Features

* **skills:** 知识型 skill 从用户斜杠菜单隐藏 ([#43](https://github.com/0xBB2B/bb-spec/issues/43)) ([eccd5b4](https://github.com/0xBB2B/bb-spec/commit/eccd5b49e8f1c89624e0c554d6d22e56fc769e13))

## [2.0.0](https://github.com/0xBB2B/bb-spec/compare/v1.4.0...v2.0.0) (2026-05-29)


### ⚠ BREAKING CHANGES

* user-invocable 命令 /bug 重命名为 /revise，技能目录 skills/bug/ 移至 skills/revise/。迁移：原先输入 /bug 改为 /revise；自然语言触发（"这里有 bug"、"结果不对"等）行为不变。

### Features

* /bug 改名为 /revise 并压缩四个 skill 文档 ([#41](https://github.com/0xBB2B/bb-spec/issues/41)) ([f371f0f](https://github.com/0xBB2B/bb-spec/commit/f371f0f0936d87877d49bf5e3ba84bacc33090fd))

## [1.4.0](https://github.com/0xBB2B/bb-spec/compare/v1.3.0...v1.4.0) (2026-05-28)


### Features

* **gitignore:** 忽略项目根 CLAUDE.md，避免个人项目偏好被分发 ([#39](https://github.com/0xBB2B/bb-spec/issues/39)) ([0343a3f](https://github.com/0xBB2B/bb-spec/commit/0343a3f7174b3ea8bcf9936e217cdc199f4becfc))

## [1.3.0](https://github.com/0xBB2B/bb-spec/compare/v1.2.0...v1.3.0) (2026-05-28)


### Features

* review skill 输出前加自检过滤层，过滤低价值发现 ([#36](https://github.com/0xBB2B/bb-spec/issues/36)) ([3da94b7](https://github.com/0xBB2B/bb-spec/commit/3da94b75cda923b7ea4d01292df593c78c13645e))

## [1.2.0](https://github.com/0xBB2B/bb-spec/compare/v1.1.0...v1.2.0) (2026-05-28)


### Features

* 新增 init skill 反向 spec 化存量项目 ([#34](https://github.com/0xBB2B/bb-spec/issues/34)) ([80217a4](https://github.com/0xBB2B/bb-spec/commit/80217a4faceff09012bb709db675b0563c9aedbe))

## [1.1.0](https://github.com/0xBB2B/bb-spec/compare/v1.0.1...v1.1.0) (2026-05-27)


### Features

* bug skill 轻量修复前须向用户确认是否跳过 3-Agent 隔离 ([#30](https://github.com/0xBB2B/bb-spec/issues/30)) ([6250ede](https://github.com/0xBB2B/bb-spec/commit/6250ede98ee3c72d0fdf7dca10da893c0e3e6e40))
* 用 release-please 替代手动 workflow_dispatch 发版 ([#31](https://github.com/0xBB2B/bb-spec/issues/31)) ([d1da9ec](https://github.com/0xBB2B/bb-spec/commit/d1da9ecd7a0ba5bd25558437be81c9fdadf4d5bd))
