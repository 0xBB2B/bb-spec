---
name: 04-design-doc-enforcement
description: /exec、/revise 写界面代码时把 DESIGN.md 交给实现工程师和审查员；/doc-update 把 DESIGN.md 纳入维护
---
# 写界面代码时守 DESIGN.md

## 目标
改界面代码时，实现工程师按 DESIGN.md 写，审查员逐项对照；`/doc-update` 发现代码和 DESIGN.md 对不上时请用户选以谁为准。

## 业务规则（来源：PRD 03-design-doc-enforcement）
- `/exec`、`/revise` 改动界面代码（页面、组件、样式文件，或命令行输出的颜色和格式）且项目有 DESIGN.md 时 → 派给实现工程师的输入带 DESIGN.md 路径并要求按它写；派给审查员的输入也带 DESIGN.md 路径。
- 审查员报告里有「DESIGN.md 对照」一项：列出代码用到的颜色、字号、间距、圆角、阴影是否都在规范里，规范外的每处给文件和行号，算作需要修的问题。
- 项目没有 DESIGN.md，或本次改动不涉及界面代码 → 实现工程师和审查员的输入都不带 DESIGN.md，审查报告不出现「DESIGN.md 对照」。
- `/doc-update` 把项目根目录的 DESIGN.md 纳入维护的文档名单。
- 被 `/prd` 调用出原型时，用户同意的 DESIGN.md 新建或修改先放在和原型预览页同名的草稿 `<预览页名>.DESIGN.draft.md`（和预览页在同一个目录，内容是改完后的完整 DESIGN.md）；`/prd` 落盘 PRD 时一起写进项目并一起提交；开分支或 worktree 时草稿随原型预览页一起搬到新现场；用户选「不做了」时一起删掉。`/revise` 中用户同意改过 DESIGN.md 时，commit 一并提交。（来源：PRD 01-design-doc C16）
- `/doc-update` 发现界面代码和 DESIGN.md 对不上 → 列出代码文件和行号、DESIGN.md 里的值，请用户选：改代码（转 `/revise`）/ 改 DESIGN.md / 跳过；选之前两边都不改。DESIGN.md 是规范，不能像 README 那样直接改成代码的样子。

## 涉及文件
- `plugins/bb-spec-workflow/skills/exec/SKILL.md` — 修改
- `plugins/bb-spec-workflow/skills/revise/SKILL.md` — 修改
- `plugins/bb-spec-workflow/agents/impl-engineer.md` — 修改
- `plugins/bb-spec-workflow/agents/prd-reviewer.md` — 修改
- `plugins/bb-spec-workflow/skills/doc-update/SKILL.md` — 修改
- `plugins/bb-spec-workflow/skills/prd/SKILL.md` — 修改
- `tests/design-doc-rules.test.sh` — 修改（01 新建，本 plan 追加分组）

## 成品定义

**exec SKILL.md**
- 信息隔离矩阵表格在「项目级约束」那一行之后加一行：`| 设计规范（项目根 `DESIGN.md`，改动界面代码时，如有） | ❌ | ✅ | ✅ |`
- 2b 句中「prompt 传「函数清单 + 文件路径 + 协作关系 + 成品定义（如有）+ 新增技术表（如有）」+ 测试文件路径」之后插入：`；本 plan 改动界面代码（页面、组件、样式文件，或命令行输出的颜色和格式）且项目有 DESIGN.md 时，再传 DESIGN.md 的路径，要求按它写`
- 2c 句中「prompt 传「业务规则」+「验证方式」+ AGENTS.md 项目级约束（如有）+ 所有变更文件路径」之后插入：`；同样情况下再传 DESIGN.md 的路径，要求报告里写「DESIGN.md 对照」。项目没有 DESIGN.md 或本 plan 不涉及界面代码时，2b、2c 都不传`

**revise SKILL.md**
- 步骤 4 第 5 条「只提交本次涉及文件（PRD / plan / 实现 / 测试 + doc-update 收尾改动；」改成「只提交本次涉及文件（PRD / plan / 实现 / 测试 + doc-update 收尾改动 + 本次经用户同意新建或改过的 DESIGN.md；」
- 3a 第 3 步、3b 第 2 步派 impl-engineer 的 prompt 内容末尾各加：`+ DESIGN.md 路径（改动界面代码且项目有 DESIGN.md 时）`
- 3a 第 3 步、3b 第 3 步派 prd-reviewer 的 prompt 内容末尾各加：`+ DESIGN.md 路径（同上，要求报告里写「DESIGN.md 对照」）`
- Agent 隔离规则表 Impl Agent、Review Agent 两行的「可见」列末尾各加：`+ DESIGN.md（改动界面代码且有时）`

**impl-engineer.md**
- frontmatter `inputs` 加一行：`  - design_doc                # 项目根 DESIGN.md 路径（改动界面代码且项目有时；没有则为空）`
- `## 输入` 末尾加一节：

```markdown
### 设计规范（DESIGN.md）

{design_doc}

（不为空时先读完。界面代码用到的颜色、字号、间距、圆角、阴影、组件样式都按它写，不用它里面没有的值；为空时跳过本节。）
```

**prd-reviewer.md**
- frontmatter `inputs` 加一行：`  - design_doc          # 项目根 DESIGN.md 路径（改动界面代码且项目有时；没有则为空）`
- `## 输入` 里「变更文件」之前加一节：

```markdown
### 设计规范（DESIGN.md）

{design_doc}

（为空时跳过下面指令里的 DESIGN.md 对照，报告里也不写这一节。）
```

- `## 指令` 第 5 条之后插入一条（后面的编号顺延）：`6. **DESIGN.md 对照**（设计规范不为空时）：读完 DESIGN.md，逐个列出变更代码用到的颜色、字号、间距、圆角、阴影，标出是否在 DESIGN.md 里；规范外的每处写 file:line 和实际值，算作需要修的问题`
- 产出格式里「## 鲁棒性与安全检查」块之前加：

```
## DESIGN.md 对照（设计规范为空时整节不写）

- ✅ 用到的颜色、字号、间距、圆角、阴影都在 DESIGN.md 里
- ❌ `<file:line>` <实际值> 不在 DESIGN.md 里 — 建议：改用 <规范里的名字和值>，或请用户同意后补进 DESIGN.md
```

- 总结行改成：`PRD 合规 N/M 条，PRD 违规 X 条，项目约束违规 P 条，测试遗漏 Y 条；代码纪律违规 Z 条；DESIGN.md 违规 D 条；鲁棒/安全问题 W 条。`

**doc-update SKILL.md**
- frontmatter description 与步骤 1 名单里的 `ARCHITECTURE.md` 之后都加 `、DESIGN.md`
- 四类发现表格 C 类那一行的含义改成：`代码明显违反 AGENTS.md 的项目约束，或界面代码和项目根 DESIGN.md 对不上（DESIGN.md 是规范，不按 A 类改成代码的样子）`；默认动作改成：`AskUserQuestion：改代码（转 `/revise`）/ 改项目约束或 DESIGN.md / 跳过；选之前两边都不改`
- 步骤 1 第 4 条「项目约束核对」之后加一条：`4b. **DESIGN.md 核对**：项目根有 DESIGN.md 时，在范围内的界面代码里找用到的颜色、字号、间距、圆角、阴影不在 DESIGN.md 里、或和 DESIGN.md 写的值不同的地方，记为 C 类，写出代码 文件:行号 和 DESIGN.md 里的值`
- 步骤 4 第 3 条改成：`3. **改 AGENTS.md 或 DESIGN.md**（C 类选「改项目约束或 DESIGN.md」、D 类裁决结果）：AGENTS.md 只动「项目约束」节的相关条目；DESIGN.md 只动不一致的那一项`

**prd SKILL.md**
- 步骤 6 中「把预览页移到新现场的 `ui-preview/` 下」之后插入：`；预览页旁边同名的 `.DESIGN.draft.md` 草稿存在时一起移过去`
- 步骤 7 在 7c 之后加一段：

```markdown
**7d. DESIGN.md**：本次预览页旁边同名的 `<预览页名>.DESIGN.draft.md` 存在（步骤 3 出原型时用户同意了新建或修改 DESIGN.md，草稿是改完后的完整文件）→ 把它写到 DESIGN.md 的位置（`bbspec-paths.sh` 输出的 `docs_repo` 根目录，为空时为 `root`），写完删掉草稿
```

- 步骤 9 简报模板「- 术语表：…」那一行之后加一行：`- DESIGN.md：新建 / 修改了哪几节 / 无`
- 步骤 9「不做了」那一行「选了之后」列中「删掉本次新建的文件（PRD 目录、界面预览页，」改成「删掉本次新建的文件（PRD 目录、界面预览页、DESIGN.md 草稿，」，并在「本次改过的已有文件用 `git checkout -- <文件>` 恢复」前加「本次新建的 DESIGN.md 删掉，」
- 步骤 10「只提交本次涉及的文件（PRD 目录 + GLOSSARY + AGENTS.md + 受 git 管的 CLAUDE.md；」改成「只提交本次涉及的文件（PRD 目录 + GLOSSARY + AGENTS.md + 受 git 管的 CLAUDE.md + 7d 写入的 DESIGN.md；」

## 函数清单
无过程式代码，只有上面的规程文字成品。

## 协作关系
实现工程师和审查员的 `{design_doc}` 由 `/exec`、`/revise` 派工时填入。DESIGN.md 的写法标准由 `/prototype` 规程承担（02）。

## 验证方式
- 测试入口：`bash tests/design-doc-rules.test.sh`（在 01 新建的文件里追加分组，用 `grep -qF` 检查文字）
- 测试输入：上面 5 个文件
- 预期结果：
- [ ] exec：信息隔离矩阵有「设计规范（项目根 `DESIGN.md`」一行；2b、2c 都写明改动界面代码且有 DESIGN.md 时传路径；写明没有 DESIGN.md 或不涉及界面代码时都不传
- [ ] revise：3a、3b 派 impl-engineer 和 prd-reviewer 的 prompt 都含 `DESIGN.md 路径`；隔离规则表 Impl、Review 两行含 `DESIGN.md`
- [ ] impl-engineer：frontmatter `inputs` 含 `design_doc`；正文有 `{design_doc}` 和"按它写，不用它里面没有的值"
- [ ] prd-reviewer：frontmatter `inputs` 含 `design_doc`；正文有 `{design_doc}`、指令里有 `DESIGN.md 对照`、规范外写 `file:line`、产出格式有 `## DESIGN.md 对照`、总结行含 `DESIGN.md 违规`；写明设计规范为空时整节不写
- [ ] doc-update：description 和名单都含 `DESIGN.md`；C 类含 `DESIGN.md 对不上`；有 `DESIGN.md 核对` 一条；选项含 `改项目约束或 DESIGN.md`、`选之前两边都不改`
- [ ] prd：步骤 6 含 `.DESIGN.draft.md` 草稿存在时一起移过去；有 `**7d. DESIGN.md**` 段，含 `<预览页名>.DESIGN.draft.md` 存在、`改完后的完整文件`、`写完删掉草稿`；简报有 `- DESIGN.md：` 一行；「不做了」含 `DESIGN.md 草稿` 和 `本次新建的 DESIGN.md 删掉`；步骤 10 提交清单含 `7d 写入的 DESIGN.md`
- [ ] revise：步骤 4 第 5 条提交清单含 `本次经用户同意新建或改过的 DESIGN.md`
- [ ] `bash tests/validate.sh`、`bash tests/new-tech-workflow.test.sh`、`bash tests/ui-preview-rules.test.sh` 照常通过（它们也检查 impl-engineer.md、prd、revise 等文件）
