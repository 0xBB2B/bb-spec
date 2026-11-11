> 用在 /git-push 第 4.5 步：分支规范自查、经 /revise 修复、PR 标题与六段描述草稿。

### 前置探测

运行 `${CLAUDE_PLUGIN_ROOT}/scripts/bbspec-paths.sh`，输出的 `docs_repo` 是文档仓库：与当前仓库相同为单仓库，不同为多仓库工作区。再运行 `${CLAUDE_PLUGIN_ROOT}/scripts/branch-prds.sh <基线>`。探测三类规范来源：

1. **项目约束**：文档仓库根（单仓库即仓库根）的 `AGENTS.md`
2. **本分支 PRD**：`branch-prds.sh` 输出的 `new=` 行（基线上还没有 = 本分支新增）
3. **已合并 PRD**：`branch-prds.sh` 输出的 `merged=` 行，即本分支 commit 的 `Requirement:` 指向、基线上已有的 PRD——本分支在改已合并的功能，期望行为写在 commit 正文里

任一存在 → 进入自查；三者都不存在 → 跳过 4.5.1、4.5.2，直接进 4.5.3 写 PR 草稿。

### 核心原则

1. 以规范为准，不以习惯为准
2. 直修不商量（规范本身冲突或缺失时才停下问）
3. 循环到通过（最多 3 轮）
4. PR 草稿整体 ≤ 50 行

### 4.5.1 派 subagent review

`Agent`（`subagent_type: bb-spec-workflow:pre-reviewer`，模型由 agent 定义指定），prompt 传入：
- `repo_path`：仓库绝对路径
- `base_branch`：比对基线分支
- `agents_md`：仓库根 AGENTS.md 路径（不存在则为空）
- `prd_dirs`：`new=` 目录的完整路径（`prd_dir`/<目录名>，无则为空）
- `change_notes`：`git log <基线>..HEAD --format='%h %s%n%b'` 的输出
- `merged_prd_dirs`：`merged=` 目录的完整路径（`prd_dir`/<目录名>，无则为空）
- `diff_summary`：diff 概况（commit 数、规模、审查重点）
- `reports_dir`：细节文件目录 `<cache_dir>/reports/`

审查指令、输出格式（`## 结论 PASS|FAIL` → `## PRD 逐条检查` → `## 违规项` → `## 测试缺口` → `## 备注`）、只读约束均由 agent 定义自包含。

### 4.5.2 经 /revise 修复

- PASS 且「测试缺口」为无 → 跳到 4.5.3
- PASS 但有测试缺口 → 用 Skill 工具调用 `revise`，把全部测试缺口（约束 + 实现的 file:line）作为参数传入，由 revise 按「处理 Review 结果」在推送前补上；补完进 4.5.3，不用复审
- FAIL → 用 Skill 工具调用 `revise`，把本轮全部违规项（file:line + 违反哪条 + 建议修法）和全部测试缺口作为参数传入；归因诊断、修复、全量测试、本地 commit 由 revise 闭环，禁止绕过 revise 直接改代码 → revise 完成后重新派 subagent 复审 → ≥ 3 轮仍 FAIL → 停下报告分歧

自查结束后（不管结论是 PASS 还是 FAIL），删掉 `${CACHE_DIR}/reports/` 下本次产生的细节文件。

### 4.5.3 生成 PR 标题与描述草稿（6 段，≤ 50 行）

squash 合并后，基线上只留一个 commit：标题就是 PR 标题，正文就是 PR 描述，分支上各个 commit 的说明都不进基线。所以：

- **标题**：≤ 70 字，跟随基线上的 commit 风格（先 `git log --oneline -20 <基线>`）。基线用 `feat(scope): …` / `fix(scope): …` 这类格式时，标题必须是这个格式；破坏性变更在冒号前加 `!`，并在描述末尾写 `BREAKING CHANGE:` 行
- **描述**：写分支最终做成了什么，中途推翻的做法不写。分支 commit 正文里写了改前 / 改后 / 为什么的，按最终结果汇总进「需求」「方案」「结果」。分支 commit 正文里的「决策」段（没改 PRD 的修复把取舍只记在这里）最终仍有效的，写进「方案」，保留选了什么、否掉了哪些做法及理由、由谁在哪天定的，否则 squash 后基线上就找不到这些决定

```markdown
## 背景
## 需求
## 方案
## 结果
## 测试
## 规范

BREAKING CHANGE: <影响范围与迁移办法；不是破坏性变更时删掉这一行>
Requirement: <目录名，多个用逗号分隔；没有写 none>
```

「规范」段写本次涉及的 PRD 目录与相关项目约束（无则写"无"）；跳过了 4.5.1、4.5.2 时注明「未跑分支规范自查」。

最后一行 `Requirement:` 标记必须保留，目录名取 4.5 前置探测里 `branch-prds.sh` 输出的全部 `new=` 与 `merged=` 目录名，用逗号分隔；一个都没有写 `none`。分支在改已合并的功能时，commit 里写的是已合并 PRD 的目录名，squash 后基线上只剩这一行，漏写就查不回那份 PRD。多仓库工作区每个仓库的 PR 都带，代码仓库的 PR 写文档仓库里的 PRD 目录名。

标题与描述直接作为步骤 6 的 `--title`、`--body`。
