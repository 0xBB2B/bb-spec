> 用在 /prd 步骤 7 和步骤 8：落盘 PRD、GLOSSARY.md、AGENTS.md、DESIGN.md，以及落盘后的自检清单。

**7a. PRD**：写入 `${DOCS_DIR}/prd/<YYYY-MM-DD>.<主题>/`（主题 kebab-case）——`OVERVIEW.md` + 每个子需求一份 `<序号>-<子需求>.md`（`01-`、`02-`…）。主题和出预览时定的不一样时，把预览页改成和 PRD 目录同名；同名的 `.DESIGN.draft.md`、`.DESIGN.md` 存在的都一起改名。

**7b. GLOSSARY.md**：`${DOCS_DIR}/prd/GLOSSARY.md` 不存在而 `${DOCS_DIR}/spec/GLOSSARY.md` 存在时，先把旧表整份复制过来（旧表不动），表头说明里的「仅 /spec 维护」改成「仅 /prd 维护」；再按术语变更队列增行、并别名、改定义，删除不再被使用的术语；所有定义冲突必须已经用户裁决，禁静默覆盖。

**7c. AGENTS.md**：

- 位置：单仓库放项目根；多仓库工作区放文档仓库根（随文档一起提交——工作区根目录不受 git 管）
- 不存在 → 按模板新建，路径写成实际的 `${DOCS_DIR}`
- 已存在 → 「查功能、查问题的规矩」节整节按模板覆盖（这一节由插件维护，旧版本写进去的查法要随插件更新）；「项目约束」节只做本次的增删改；其他内容不动
- 确保会话启动目录（单仓库为项目根，多仓库为工作区根）的 `CLAUDE.md` 含导入行 `@<AGENTS.md 相对它的路径>`（单仓库为 `@AGENTS.md`，多仓库如 `@docs/AGENTS.md`；Claude Code 只读 CLAUDE.md，靠这一行把 AGENTS.md 一起加载）：没有 CLAUDE.md → 新建只含这一行的文件；有但缺这一行 → 加在文件最前面

**7d. DESIGN.md**：本次预览页旁边同名的 `<预览页名>.DESIGN.md` 存在（用户已同意、改完后的完整文件）→ 把它写到 DESIGN.md 的位置（`bbspec-paths.sh` 输出的 `docs_repo` 根目录，为空时为 `root`），写完删掉它；`<预览页名>.DESIGN.draft.md` 是用户还没同意的，不写入

- [ ] 步骤 0~5 只在 `${CACHE_DIR}/ui-preview/` 写过预览页和它的 DESIGN.md 草稿（预览页旁边的两个设计规范临时文件 `.DESIGN.draft.md`、`.DESIGN.md`），没写别的文件？涉及界面时，预览已获用户明确确认，框里确认过的布局、文案、各种状态都写进了约束和验收，外壳没写成产品功能？
- [ ] 质疑已完成；OVERVIEW 有背景、目标、非目标、子需求清单、整体验证路径、决策记录；frontmatter 含 name + description（≤ 80 字）+ date + 单行写法的 `features: [a, b]`？
- [ ] 每份子文档：每条约束可测且在验收里有对应项；每条 P0 有主路径用例；有验证路径；全文无实现方案；没有引用其他文档？
- [ ] `features:` 复用了已有功能名？新功能名都会列进步骤 9 的简报？
- [ ] 项目级约束只在 AGENTS.md、功能约束只在 PRD，没有一条写在两处？AGENTS.md 有查询规矩节？CLAUDE.md 已含指向 AGENTS.md 的导入行？
