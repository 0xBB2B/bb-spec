> 用在 /prd 全程（所有 skill 共用）：仓库布局的定义和本分支 PRD 的判定。

**仓库布局**（所有 skill 共用这一节的定义）：

- **单仓库**：PRD 与代码在同一个 git 仓库，`${DOCS_DIR}` 就在这个仓库里
- **多仓库工作区**：`${DOCS_DIR}` 所在的 git 仓库（`bbspec-paths.sh` 输出的 `docs_repo`）与代码不在同一个仓库，常见为工作区根目录不是 git 仓库、`docs/` 与各服务各自是独立仓库。此时：
  - **文档仓库** = `${DOCS_DIR}` 所在仓库；**代码仓库** = 工作区里其他 git 仓库（go.work 的 `use`、pnpm workspace 成员、或根目录下含 `.git` 的子目录）
  - 涉及 PRD 的 git 命令都在文档仓库里执行（`git -C <文档仓库>`），路径用相对文档仓库根的写法，在各 skill 里记作 `<PRD 根>`（单仓库时就是 `${DOCS_DIR}/prd`）
  - 查代码历史的 git 命令（`git log -L`、`git log --grep "Requirement: …"`）在每个相关代码仓库里分别执行
  - 本次需求涉及的每个仓库（文档仓库 + 改动的代码仓库）都按 git-workflow 开同名功能分支，各自的 commit 都带 `Requirement:` 标记

**本分支 PRD 的判定**（所有 skill 共用这一条）：基线分支（main 或 master）上还没有 `<PRD 根>/<目录>/OVERVIEW.md` = 本分支新增 = 可改；已有 = 已合并 = 冻结。`${CLAUDE_PLUGIN_ROOT}/scripts/branch-prds.sh <基线分支>` 按这条规则列出本分支涉及的 PRD：`new=<目录>` 是本分支新增，`merged=<目录>` 是本分支 commit 的 `Requirement:` 指向的已合并 PRD；不在 `new=` 里的 PRD 都已合并。
