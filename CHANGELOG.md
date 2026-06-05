# Changelog

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
