# Changelog

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
