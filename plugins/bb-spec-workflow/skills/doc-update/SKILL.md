---
name: doc-update
description: 文档与代码一致性维护——代码是事实，让 README、CLAUDE.md、AGENTS.md 等根文档追平代码现状，并检查代码是否违反 AGENTS.md 项目约束；/exec 与 /revise 收尾时以 --tail 收尾模式自动调用，额外核对本分支 PRD 与实际交付是否一致；已合并的 PRD 任何模式都不碰；改代码一律先问用户、转 /revise。触发：/doc-update、文档和代码不一致、README 过期、维护一下文档。跳过：单点 bug 或定向修复（→/revise）、新需求（→/prd）、老项目从 spec 迁移（→/prd-migrate）。
argument-hint: [--tail | 可选：限定范围，如某目录 / 某文档]
---

# Doc-Update 文档与代码一致性维护

默认认为「代码是事实」，文档追平代码；**仅当代码明显违反 AGENTS.md 项目约束**时停下用 `AskUserQuestion` 请用户裁决，确认后转 `/revise` 改代码。

> 与相邻 skill 的边界
> - `/revise`：单点 bug 或定向修复；本 skill 只改文档、不改代码
> - `/review` 内的 `review-design`（文档同步视角）：只读、只看 PR diff；本 skill 会落盘修改
> - `/prd`：新需求；本 skill 不新增需求、不改已合并的 PRD

## 核心原则（兼硬约束）

1. **代码是事实，文档追平代码**：禁止凭文档反推代码该怎么写
2. **不改代码**：发现代码违反项目约束，停下用 `AskUserQuestion` 请用户拍板，同意后产出挂单交给 `/revise`，本 skill 不直接改实现
3. **已合并的 PRD 只读**：PRD 是需求记录，合并后冻结，任何模式下都不改、不删。唯一能改的是收尾模式下的**本分支 PRD**——判定：`git -C <文档仓库> cat-file -e <基线分支>:<PRD 根>/<目录>/OVERVIEW.md` 失败（基线分支 main 或 master 上还没有它；单仓库时文档仓库就是当前仓库、`<PRD 根>` 为 `${DOCS_DIR}/prd`，多仓库工作区时文档仓库是 `${DOCS_DIR}` 所在的独立仓库、`<PRD 根>` 相对它的根）
4. **批改前先汇总**（收尾模式下 A 类除外）：所有发现分类列出 + 默认动作 + 待裁决项一次性展示，用户批准后才落盘
5. **冲突不自决**：AGENTS.md 内部互相矛盾、或与已激活的技术栈 skill 冲突时，一律 `AskUserQuestion`
6. **最小影响**：只改确实过期的那几行，不借机整理排版、调整标题层级
7. **只写最新结果**：文档只写当前代码的行为；禁加"原来是 X、现在改为 Y""已废弃保留兼容"类过渡表述，废弃直接删
8. **语言跟随用户**：正文用用户工作语言，标识符/API 名/错误码保持英文

## 两种模式

| | 全仓模式（手动 `/doc-update`） | 收尾模式（`--tail`，由 `/exec`、`/revise` 调用） |
|---|---|---|
| 范围 | 全部根文档 + 全部代码对照 AGENTS.md | 根文档中引用了本分支改动的段落 + 本分支改动的代码对照 AGENTS.md + 本分支 PRD |
| 本分支 PRD | 不处理 | 核对约束、验收与实际交付是否一致 |
| A 类 | 汇总后经用户批准再改 | 直接改，在简报中逐条列出 |
| B / C / D 类 | 逐条 AskUserQuestion | 逐条 AskUserQuestion |
| commit | 不 commit，改动留在工作区 | 不 commit，由调用方连同其他收尾改动一起提交 |

## 四类发现

| 编号 | 类别 | 含义 | 默认动作 |
|---|---|---|---|
| A | **doc-stale** | README / CLAUDE.md / AGENTS.md 等根文档引用了已改名、删除或行为变了的函数、路径、命令、配置项 | 改文档追平代码 |
| B | **prd-stale**（仅收尾模式） | 本分支 PRD 的约束或验收与实际交付不一致，且没有经用户同意的修改记录 | AskUserQuestion：改 PRD 认可代码 / 转 `/revise` 改代码 |
| C | **code-violation** | 代码明显违反 AGENTS.md 的项目约束 | AskUserQuestion：改代码（转 `/revise`）/ 改项目约束 / 跳过 |
| D | **agents-conflict** | AGENTS.md 的约束之间互相矛盾，或与已激活的技术栈 skill 冲突 | AskUserQuestion：选保留哪条 |

每条发现必须落到具体 `文件:行号` + 一句话说明哪里不一致；说不出位置的丢弃。性能、可读性、口味偏好不算 C 类。

---

## 工作流

### 步骤 0：读取配置 + 确定范围

```bash
cat .bb-spec.yaml 2>/dev/null
```

取 `base_dir`（缺省 `.bb-spec`），`${DOCS_DIR}` = `<base_dir>/docs`。

- `$ARGUMENTS` 是 `--tail` → 收尾模式。本分支改动文件：在本次改动的每个仓库里 `git diff <基线分支>...HEAD --name-only`；本分支 PRD：文档仓库里 `git diff <基线分支>...HEAD --name-only -- <PRD 根>` 列出的目录中，按上面的判定属于本分支新增的那些
- `$ARGUMENTS` 是其他非空内容 → 全仓模式，只处理参数指定的目录或文档
- 为空 → 全仓模式

### 步骤 1：盘点

主 agent 自做，**禁派子代理**：

1. **读根文档**：`README*.md` / `CLAUDE.md` / `AGENTS.md` / `CONTRIBUTING.md` / `ARCHITECTURE.md` 等存在者；收尾模式只看引用了本分支改动文件、命令、配置项的段落
2. **抽取可核对的引用**：文档里出现的函数名、文件路径、命令、env var、CLI flag、配置 key、默认值、超时阈值
3. **对照代码**：codegraph 可用则 `codegraph_explore`，否则 `grep -rnE` + 读相关文件，确认每个引用在代码里是否还成立
4. **项目约束核对**：逐条读 AGENTS.md「项目约束」，在范围内的代码里找违反项
5. **收尾模式额外**：读本分支 PRD 的每条约束与验收，对照本分支的实现和测试确认是否都已交付、行为是否一致

### 步骤 2：分类

把发现按 A / B / C / D 归类，每条带 `文件:行号` 与一句话说明。

### 步骤 3：汇总 + 裁决

```
## /doc-update 发现清单（共 N 条）

### A. doc-stale（X 条）
- README.md:42 引用 `oldFunc()` → 已改名为 `newFunc()`（internal/order/export.go:15）
  → 改 README

### B. prd-stale（X 条，仅收尾模式）
- prd/2026-10-08.order-export/01-csv.md:20 约束「最多导出 1 万行」→ 实现为 5 万行（internal/order/export.go:88）
  → 需裁决：改 PRD / 转 /revise 改代码

### C. code-violation（X 条）
- AGENTS.md「禁止泛型」→ internal/util/map.go:12 定义了泛型函数
  → 需裁决：转 /revise 改代码 / 改项目约束 / 跳过

### D. agents-conflict（X 条）
- AGENTS.md 第 8 行与第 15 行对同一件事要求相反
  → 需裁决：保留哪条
```

- B / C / D 类逐条 `AskUserQuestion`
- A 类：全仓模式用一次 `AskUserQuestion` 请用户选「全部批准 / 逐条裁决 / 取消」；收尾模式直接进入步骤 4

未获批准的条目**一律不动**。

### 步骤 4：落盘

1. **改根文档**：用 `Edit` 精准替换过期的 symbol / 路径 / 命令 / 配置，语言与原文一致
2. **改本分支 PRD**（B 类选「改 PRD」）：只改不一致的约束、验收或用例，保证约束与验收仍一一对应
3. **改 AGENTS.md**（C 类选「改项目约束」、D 类裁决结果）：只动「项目约束」节的相关条目
4. **C / B 类选「改代码」**：不改实现，产出挂单交给 `/revise`：

   ```
   - <涉及文件:行号>
     期望行为：<项目约束或 PRD 要求什么>
     不符点：<代码实际怎样>
     建议测试切入：<从哪个测试入口先写 Red>
   ```

5. **不允许**：改已合并的 PRD、改 plan 正文、改测试、改代码、改 commit 历史

每改一处先回显一行：`✏️ <文件>: <一句话变更>`，便于用户中途叫停。

### 步骤 5：回归校验

1. 被改过的文档里引用的相对路径真实存在
2. 被改过的本分支 PRD 约束与验收仍一一对应
3. `git diff --stat` 里没有代码文件、没有已合并的 PRD

任何一项不通过 → 当场修，修不了列入简报「待处理」。

### 步骤 6：完成简报

```
## /doc-update 完成简报
- 模式：<全仓 / 限定范围 $ARGUMENTS / 收尾>
- 发现：A/B/C/D 各 N 条
- 已落盘：根文档 X 处 / 本分支 PRD Y 处 / AGENTS.md Z 处（逐条列出）
- 待用户后续处理：<转 /revise 的挂单 / 未裁决项 / 无>
- 回归校验：✅ 全部通过 / ⚠️ <说明>
```

> 本 skill 不自动 commit、不自动 push。全仓模式的改动留在工作区由用户决定何时提交；收尾模式由调用方一起 commit。
