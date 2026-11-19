# ARCHITECTURE.md

> 项目大纲：有哪些模块、各在哪、怎么协作。只写不常变的内容，代码细节以代码为准。由 /doc-update 维护。

## 项目做什么
bb-spec 是一套 Claude Code 插件：用 PRD 驱动"需求 → 计划 → 实现 → 文档 → 提 PR"的流水线，并附带 TDD、Git、技术栈等约束。给用 Claude Code 写代码、想让 AI 按固定规程交付的开发者用。

## 整体设计
- 仓库本身是一个插件市场（marketplace），下挂 4 个可单独安装的子插件，按"纪律 / 流水线 / 后端约束 / 前端约束"分层，用户只装需要的层。
- 插件的"代码"主要是 Markdown 规程（skill、agent 定义），少量 bash 脚本和 hook 负责确定性的事（找目录、查 PR 状态、拦截 main 提交）。规程文字就是产品，所以测试多是检查规程原文的规则测试。
- 流水线各阶段之间只靠磁盘文件交接（PRD、plan、PROGRESS.md），跨会话、`/clear` 后都能接着跑。

## 模块地图
| 模块 | 职责 | 目录 | 关键文件 / 类型 |
|---|---|---|---|
| 插件市场 | 登记 4 个子插件及其来源目录 | `.claude-plugin/` | `marketplace.json` |
| bb-spec-core | 通用纪律 skill + 被动 hook | `plugins/bb-spec-core/` | `skills/{tdd-workflow,version-policy,git-workflow,code-constraints}`、`hooks/hooks.json` |
| bb-spec-workflow | 流水线 skill、子代理、脚本、原型模板 | `plugins/bb-spec-workflow/` | `skills/*/SKILL.md`、`agents/*.md`、`scripts/`、`templates/` |
| bb-spec-backend | Go / API / 数据库 / 认证授权 / 可观测性 / 服务治理 / 配置约束 | `plugins/bb-spec-backend/skills/` | 各 `SKILL.md` |
| bb-spec-frontend | Vue 技术栈与前端工程约定 | `plugins/bb-spec-frontend/skills/` | 各 `SKILL.md` |
| 共用脚本 | 算出 bb-spec 各目录路径、列出本分支 PRD | `plugins/bb-spec-workflow/scripts/` | `bbspec-paths.sh`、`branch-prds.sh` |
| 测试 | 插件结构校验 + 规程规则测试 + 脚本行为测试 | `tests/` | `validate.sh`、`*.test.sh`、`lib/md.sh` |
| 介绍主页 | GitHub Pages 静态站点 | `site/` | `index.html`、`style.css`、`app.js` |
| CI 与发版 | 跑测试、部署主页、按 commit 类型自动发版 | `.github/workflows/`、`release-please-config.json` | `ci.yml`、`pages.yml`、`release-please.yml` |
| 需求文档 | 本仓库自己的 PRD 与术语表 | `.bb-spec/docs/prd/` | `<日期>.<主题>/OVERVIEW.md`、`GLOSSARY.md` |

## 关键流程
### 新需求交付
`/prd`（`skills/prd`：澄清后写 PRD）→ `/plan`（`skills/plan`：写函数级 plan）→ `/exec`（`skills/exec`：派 `test-engineer` → `impl-engineer` → `prd-reviewer`）→ `/doc-update --tail`（`skills/doc-update`）→ 用户手动 `/git-push`（`skills/git-push`：自查用 `pre-reviewer`，合并状态用 `skills/git-push/scripts/pr-status.sh`）

### 修正
`/revise`（`skills/revise`：归因后同样派三个子代理）→ `/doc-update --tail`

### 界面原型
`/prd` 或 `/revise` 调 `/prototype`（`skills/prototype`）→ 派 `prototype-designer` 按 `templates/ui-preview-shell.html` 出原型 → 主对话转报告、在浏览器里打开

### 发版
commit 合入 main → `release-please.yml` 按 `feat` / `fix` 生成版本，同步写入 4 个 `plugin.json` 的版本号

## 公共机制
- 目录定位：所有 skill 先运行 `bbspec-paths.sh`，按项目里的 `.bb-spec.yaml` 算出 PRD、plan、缓存目录。
- 需求追溯：每个 commit 末尾带 `Requirement: <PRD 目录名>`，`branch-prds.sh` 据此区分本分支新增和已合并的 PRD。
- 被动约束：`bb-spec-core` 的 hook 在提交、改依赖文件、结束回合时自动注入提醒或拦截。
