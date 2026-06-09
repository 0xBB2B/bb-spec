# CLAUDE.md

## Commit Message 规范

### 类型只允许 feat / fix / docs

- **feat**：任何新增 / 增强 / 约束硬化（使用者视角可感知的正向变化）
- **fix**：修复 bug、纠正错误信息、回滚不当行为
- **docs**：仓库自身的说明文档与开发约定（根 `README.md` / `README.zh.md` / `LICENSE` / `CLAUDE.md` / 贡献指南等），前提是改动**不改变任何插件交付给使用者的行为或约束**

禁用 `chore:` / `refactor:` / `style:` / `test:` / `perf:` / `ci:` / `build:` 等其它类型。

**为什么这样分**：本项目用 release-please 自动发版——`feat`(minor) / `fix`(patch) / `!`(major) 触发版本 bump 并进 CHANGELOG，`docs` 既不 bump 也不进 CHANGELOG。

- **产品本体**——`SKILL.md`、`agents/*.md`、`hooks/*`、`plugin.json` / `marketplace.json`、`.bb-spec` spec 规则——**即便是 Markdown**，改了也会改变插件对使用者的行为或约束，**必须**用 `feat` / `fix`（要 bump + 可追溯）。
- **说明文档与开发约定**——仓库根 README、`CLAUDE.md`、贡献指南等不随插件交付的内容——改了不影响插件行为，用 `docs`（不该让一次 README 措辞调整或开发约定更新就 bump 版本号）。

**判断标准一句话**：改动会不会改变插件交付给使用者的行为 / 约束？会 → `feat` / `fix`；不会、且只是仓库说明 / 开发约定 → `docs`。纯配置 / 纯测试改动若服务于某项功能或修复，仍归 `feat` / `fix`。

### 重大更新先问用户

遇以下场景，**先停下询问**是否要标 BREAKING CHANGE，得到用户明确"确认"后再写 commit：

- 重构改变了模块结构 / 公开接口
- 删除或重命名公开 API、CLI 参数、配置项、目录结构、命名约定
- 修改默认行为（同样输入产出不同结果）
- 调整发版机制、依赖最低版本要求

询问话术示例：

> 这次改动会让 X 行为变成 Y，建议作为 BREAKING CHANGE 提交（release-please 会自动跳 major 版本号），确认吗？

用户确认后，commit 写成：

```
feat(scope)!: 一句话描述破坏性变更

BREAKING CHANGE: 详细描述影响范围与迁移办法
```

### 示例

- ✅ `feat(spec,init): spec 文档强制按领域建子目录`（SKILL 行为变化，要 bump）
- ✅ `fix(hooks): 修正 stop-self-check.sh 路径变量未引用`
- ✅ `docs(readme): 重写 workflow 章节、补全阶段流转`（仅根 README，纯对外说明、不 bump）
- ✅ `feat(plugin)!: 重命名 .bb-spec/ 为 .spec/`（正文带 `BREAKING CHANGE:` 段）
- ❌ `docs: 调整 SKILL.md 约束` → SKILL 是产品本体，改用 `feat(scope): …` / `fix(scope): …`
- ❌ `chore: 升级依赖` → 改为 `feat(deps): 升级 X 到 Y` 或 `fix(deps): 修复 X 漏洞`
- ❌ `refactor: 整理代码` → 先停下问用户是否走 BREAKING CHANGE
