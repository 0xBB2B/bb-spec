---
name: prd-migrate
description: 老项目一次性迁移——把用过 spec 的 bb-spec 项目转成「PRD + 代码 + git 标记」：原始 PRD（prd/.archive/）原样移回 prd/，spec 按领域转成 legacy PRD，每份 PRD 用 `commits:` 记下相关 commit 哈希让老代码能经 git 反查回来；只写有出处的内容，每条设计原因标来源，查不到的写"未知"交用户确认、禁止编造；项目级约束移入 AGENTS.md；删除 spec/ 与已完成的 plan。启动即 EnterPlanMode，批准后落盘并一次 commit；spec/ 不存在即视为已迁移、直接退出。触发：/prd-migrate、迁移旧项目、spec 转 PRD。跳过：没有 spec/ 的项目（直接从下一个需求开始用 /prd）。
---

# PRD-Migrate：spec 项目一次性迁移

把老的「PRD → spec → plan」项目转成「PRD + 代码 + git 标记」：代码回答现在做什么，PRD 回答为什么，commit 哈希把老代码连回 PRD。

## 核心原则

1. **只迁有 spec 的项目**：`${DOCS_DIR}/spec/` 不存在 → 告知"没有 spec，无需迁移（已迁移过或不是 spec 项目）"后退出。这也是迁移完成的唯一判据，不另建状态文件
2. **先对齐再落盘**：启动即 `EnterPlanMode`，盘点、取证、切分全程只读，`ExitPlanMode` 批准后才写
3. **只写有出处的内容**：设计原因、约束、验收都必须来自原始 PRD、spec 原文或 commit 说明，每条设计原因后标来源 `（来源：spec <领域>/<规则>）` / `（来源：commit <短哈希>）` / `（来源：原 PRD <目录>）`；查不到的写 `未知`，**禁止 AI 根据代码或常识补写**
4. **原始 PRD 不重写**：`prd/.archive/` 里的原始 PRD 是当时真实的需求记录，原样 `git mv` 回 `prd/`，只在 OVERVIEW frontmatter 补 `features:` 与 `commits:`
5. **不改 git 历史**：老 commit 没有 `Requirement:` 标记，也不补；改为在 PRD frontmatter 用 `commits:` 记短哈希，AGENTS.md 查询规矩用短哈希反查。多仓库工作区写成 `<仓库目录名>@<短哈希>`（如 `trade@9153a78`、`docs@5ae1da7`），按短哈希 grep 仍能命中
6. **推断要让用户确认**：凡是靠"文件 + 时间窗"推断出来的 commit 关联，都在待批方案里单独列出、标明推断依据，用户确认后才写入 `commits:`
7. **同一内容只写一处**：项目级约束移入 AGENTS.md 后，legacy PRD 里不再重复
8. **语言跟随用户**：正文用用户的工作语言，标识符保持英文

---

## 工作流

> 步骤 0~4 在 plan 模式内（只读），步骤 5~8 在 plan 模式外。

### 步骤 0：进入 plan 模式 + 前置检查

**立即调用 `EnterPlanMode`**。`cat .bb-spec.yaml 2>/dev/null` 取 `base_dir`（缺省 `.bb-spec`），`${DOCS_DIR}` = `<base_dir>/docs`。

**判断仓库布局**：`git -C ${DOCS_DIR} rev-parse --show-toplevel` 得到文档仓库。它就是代码所在仓库 → 单仓库；不是（如工作区根不是 git 仓库、`docs/` 与各服务各自独立）→ 多仓库工作区，代码仓库 = 工作区里其他 git 仓库（go.work 的 `use`、pnpm workspace 成员、或根目录下含 `.git` 的子目录）。下文 spec / PRD / plan 相关的 git 命令都在文档仓库里执行、路径相对文档仓库根；代码相关的在各代码仓库里执行。

- `${DOCS_DIR}/spec/` 不存在 → 告知无需迁移，`ExitPlanMode` 后退出
- `${DOCS_DIR}/plan/` 下有主题目录的 `PROGRESS.md` 含非 `done` 行 → 新版 `/exec` 已不读 spec，这些 plan 无法续跑。列出它们与已完成的步骤，用 AskUserQuestion 让用户选：**放弃这些 plan、随迁移一起删除**（已提交的代码保留，未完成部分以后用 `/prd` 重新提需求）/ **退出迁移**

### 步骤 1：盘点

```bash
cat ${DOCS_DIR}/spec/INDEX.md
find ${DOCS_DIR}/spec -name '*.md' ! -name INDEX.md ! -name GLOSSARY.md
ls ${DOCS_DIR}/prd/.archive/ 2>/dev/null   # 已被消费的原始 PRD
ls ${DOCS_DIR}/prd/ 2>/dev/null            # 未被消费的旧 PRD（不含 .archive）
cat AGENTS.md CLAUDE.md 2>/dev/null
```

读全部 spec 正文、全部原始 PRD。

### 步骤 2：取证

**原始 PRD ↔ spec 的对应关系**：旧版 `/spec` 在同一个 commit 里归档 PRD 并新增 spec——

```bash
git log --format='%H' --diff-filter=A -- '${DOCS_DIR}/prd/.archive/<目录>/*' | tail -1   # 归档该 PRD 的 commit
git show --name-status --format= <该 commit> -- '${DOCS_DIR}/spec/'                     # 同一 commit 新增/修改的 spec
```

同一 commit 里出现的 spec 视为该 PRD 的规则。

**每份 spec / 原始 PRD 的文档 commit**（在文档仓库执行）：

```bash
git log --follow --format='%h %ad %s' --date=short -- <spec 文件>          # 改过这份 spec 的 commit
git log --format='%h %ad %s' --date=short --grep '<spec name 或 PRD 目录名>' # commit 说明里提到它的
```

单仓库且 squash 合并时，这些 commit 通常同时包含代码改动，`git log -L` 查函数会命中同一个哈希，到这里就够了。

**代码 commit**（多仓库工作区、或单仓库里实现 commit 与文档 commit 分开时必做）——代码 commit 通常不提 spec 名，按 plan 的「涉及文件」与时间窗找：

1. 每个已完成 plan 主题：时间窗起点 = 文档仓库里新增该主题 `INDEX.md` 的 commit 日期；终点 = `PROGRESS.md` 最后一个完成时间（或根 `plan/INDEX.md` 的完成时间）
2. 「涉及文件」里的路径按开头的仓库目录名对应到代码仓库，在该仓库里 `git log --since=<起点> --until=<终点 +1 天> --format='%h %ad %s' --date=short -- <文件>`
3. 命中的 commit 关联到该 plan 对应的原始 PRD 与 spec 规则
4. 没有 plan 的 spec 修改（如某次只改了 spec 的 commit）：在同一批文件上找 spec 修改日期后 7 天内的代码 commit，**属于推断**，列入待批方案请用户确认

去重后就是 `commits:` 的内容。

**设计原因的证据**：按优先级取——原始 PRD「决策记录」→ spec「设计原因」段（如有）→ 上面 commit 的说明正文。都没有 → `未知`。

### 步骤 3：切分方案

1. **原始 PRD**：每个 `prd/.archive/<目录>` → 移回 `prd/<目录>`；没有 `OVERVIEW.md` 的单文件 PRD → 移为 `prd/<目录名>/OVERVIEW.md`
2. **未被消费的旧 PRD**（`prd/` 下非 `.archive`）：原地保留，只补 frontmatter
3. **spec**：按领域（spec 子目录）各生成一份 `prd/<今天日期>.legacy-<领域>/`——`OVERVIEW.md` + 每条规则一份子文档
4. **项目级约束**：spec 里对整个项目生效、不属于某个功能的规则（如统一错误码格式、时间精度）→ 列为移入 AGENTS.md 的候选，不进 legacy PRD
5. **功能名**：`features:` 用 spec 规则名（如 `discount-rule`、`order-create`），不用领域名——领域名太粗，按功能查会把整个领域都搜出来。legacy PRD 的 `features:` = 该领域包含的规则名；原始 PRD 的 `features:` = 步骤 2 对应到的规则名，对应不到的列入待确认

### 步骤 4：呈现待批方案 → ExitPlanMode

- 原始 PRD 移回清单（目录 + `features:` + commit 数）
- legacy PRD 清单（目录 + 包含的规则 + commit 数）
- **推断出的 commit 关联**：逐条列出 commit、关联到哪份 PRD、推断依据（哪个文件、哪个时间窗），请用户确认
- 移入 AGENTS.md 的项目级约束（逐条）；要新建 AGENTS.md 或给 `CLAUDE.md` 加 `@AGENTS.md` 时写明
- **设计原因为"未知"的清单**：逐条列出，请用户补充或确认保持"未知"——用户补充的标 `（来源：用户补充 <日期>）`
- 待确认的功能名
- 将删除：`spec/`（含 INDEX.md）、迁移后的空 `prd/.archive/`、已完成的 plan 主题目录、用户选择放弃的进行中 plan、根 `plan/INDEX.md`

驳回则在 plan 模式内调整后重新呈现。

### 步骤 5：确认落盘现场

在 main/master 上 → 按 git-workflow 用 AskUserQuestion 选开分支方式（默认 worktree），后续落盘与 commit 都在新现场；已在功能分支 → 继续。

### 步骤 6：落盘

1. `git mv` 原始 PRD 回 `prd/`，在 OVERVIEW frontmatter 补 `features:` 与 `commits:`，正文不动
2. 按模板写 legacy PRD
3. `git mv ${DOCS_DIR}/spec/GLOSSARY.md ${DOCS_DIR}/prd/GLOSSARY.md`（存在时）
4. 写 AGENTS.md：单仓库放项目根，多仓库工作区放文档仓库根（随文档提交）。不存在则按 `/prd` 的 AGENTS.md 模板新建（含「查功能、查问题的规矩」节，路径写成实际的 `${DOCS_DIR}`）；写入已批准的项目约束；确保会话启动目录（单仓库为项目根，多仓库为工作区根）的 `CLAUDE.md` 含指向它的导入行（如 `@AGENTS.md` 或 `@docs/AGENTS.md`）
5. `git rm -r` 删除 `spec/`、空的 `prd/.archive/`、已完成的 plan 主题目录、用户选择放弃的进行中 plan、根 `plan/INDEX.md`

### 步骤 7：自检 + commit

- [ ] 每条设计原因都标了来源，或写着"未知"且已在步骤 4 经用户确认？
- [ ] 原始 PRD 正文未改动（`git diff -M --stat` 显示为改名 + 少量 frontmatter 行）？
- [ ] 每份 PRD 的 OVERVIEW frontmatter 都有用规则名写的 `features:`，有实现记录的都有 `commits:`（多仓库带仓库前缀）？推断出的关联都经用户确认？
- [ ] 项目级约束只在 AGENTS.md，legacy PRD 里没有重复？
- [ ] `${DOCS_DIR}/spec/` 已不存在？

通过后在文档仓库做一次本地 commit，message 遵循仓库历史风格，正文写"从 spec 迁移到 PRD + 代码 + git 标记"，最后一段尾注带 `Requirement: none`（与 `Co-Authored-By:` 等同段、中间不空行，否则 git 认不出）；**不 push**。

### 步骤 8：简报

```
## 迁移完成简报
- 原始 PRD：移回 N 份
- legacy PRD：新建 M 份（覆盖 K 条 spec 规则）
- 项目约束移入 AGENTS.md：X 条
- 设计原因：有出处 A 条 / 用户补充 B 条 / 未知 C 条
- 已删除：spec/、prd/.archive/、已完成 plan Y 个
- 代码关联：按 plan 文件清单关联 N 个 / 推断后经确认 M 个 / 未关联的代码 commit K 个
- 下一步：之后的新需求用 /prd，修正用 /revise
```

---

## 模板

### legacy `OVERVIEW.md`

```markdown
---
name: legacy-<领域>
description: 从 spec「<领域>」迁移的规则记录
date: <迁移日期>
features: [<规则名>, ...]  # 必须单行写法
commits: [<短哈希>, ...]  # 多仓库写 <仓库>@<短哈希>
---

# <领域>（从 spec 迁移）

## 背景与问题
<取自 spec「目的」；没有则写"未知">

## 子需求清单
| 序号 | 子需求 | 来源 spec |
|---|---|---|
| 01 | [<规则名>](01-<规则名>.md) | <领域>/<规则名> |

## 决策记录
- <设计原因>（来源：…）
- 未知：<没有任何依据的取舍点>
```

### legacy 子文档 `<序号>-<规则名>.md`

```markdown
---
name: <规则名>
description: <取自 spec description>
date: <迁移日期>
---

# <规则标题>

## 用例
<取自 spec「例子」>

## 约束
<取自 spec「约束」，原文照搬>

## 验收
<取自 spec「验收」，原文照搬>
```
