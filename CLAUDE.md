# CLAUDE.md

## Commit Message 规范

### 默认类型只允许 feat / fix

- **feat**：任何新增 / 增强 / 约束硬化（读者视角可感知的正向变化）
- **fix**：修复 bug、纠正错误信息、回滚不当行为

禁用 `docs:` / `chore:` / `refactor:` / `style:` / `test:` / `perf:` / `ci:` / `build:` 等其它类型。

**原因**：本项目用 release-please 自动发版，默认只对 `feat` / `fix` 触发版本 bump；其它类型不会进 CHANGELOG，会导致版本号停滞、变更不可追溯。即便是纯文档 / 纯配置 / 纯测试改动，也归入 `feat`（新增约束 / 补强规则）或 `fix`（纠正错误）。

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

- ✅ `feat(spec,init): spec 文档强制按领域建子目录`
- ✅ `fix(hooks): 修正 stop-self-check.sh 路径变量未引用`
- ✅ `feat(plugin)!: 重命名 .bb-spec/ 为 .spec/`（正文带 `BREAKING CHANGE:` 段）
- ❌ `docs: 更新 README` → 改为 `feat(readme): 补充 X 章节` 或 `fix(readme): 修正 Y 表述`
- ❌ `chore: 升级依赖` → 改为 `feat(deps): 升级 X 到 Y` 或 `fix(deps): 修复 X 漏洞`
- ❌ `refactor: 整理代码` → 先停下问用户是否走 BREAKING CHANGE
