# Changelog

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
