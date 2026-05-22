---
name: git-push-pr
description: Use when 用户想把本地代码通过 PR 流程推送到远程仓库。自动检测单 / 多仓库，支持批量或选择性处理；用户也可通过参数指定单个仓库目录。推送前若项目内存在 `docs/spec/INDEX.md`，会自动跑一次**分支规范自查（pre-review）**——派 subagent 拿 spec 比对当前分支 vs main 的 diff，违规由主 agent 直接修复并循环复审，通过后生成一份**简洁的 6 段 PR 描述草稿**（背景 / 需求 / 方案 / 结果 / 测试 / 规范，整体不超过 50 行），直接用作创建 PR 的 body。常见触发："push 一下"、"提个 PR"、"代码推上去"、"准备发 PR"、"开 PR 之前帮我自查一下"、"对照规范看下这个分支"。
user-invocable: true
---

# 仓库提交与 PR 流程

## 概览

将本地代码通过标准 PR 流程推送到远程仓库。自动识别单仓库或多仓库场景，逐仓库执行：创建分支 → 跑测试 → 提交 → **分支规范自查 + PR 草稿（仅当项目内有 `docs/spec/INDEX.md` 时跑）** → 推送 → 创建 PR → 选择处理方式（自动合并 / 已合并 / 关闭 PR）→ 清理分支。

规范自查（步骤 4.5）以项目内 `docs/spec/` 为唯一规范基线：派 subagent 比对 `当前分支 vs main` 的 diff，违规由主 agent 按建议直接修、循环复审至 PASS（最多 3 轮），随后生成一份 6 段 PR 描述草稿作为步骤 6 创建 PR 时的 `--body`。项目无 spec 索引则跳过整个 4.5，按"简短改动要点"作为 PR body。

## 参数

用户可在调用时附带目录路径，直接指定处理某个仓库，例如：

- `/repo-push ./my-project`
- `/repo-push /absolute/path/to/repo`

如果未指定路径，则自动检测当前目录。

## 工作流

### 1. 识别范围

检测当前工作目录的仓库结构：

- **当前目录本身是 git 仓库**：作为单仓库处理。
- **当前目录下包含多个 git 子目录**：列出所有子仓库，询问用户是全部处理还是选择其中某几个。
- **用户通过参数指定了目录**：只处理该目录，跳过检测。

检测方式：

```bash
# 判断当前目录是否为 git 仓库
git rev-parse --git-dir 2>/dev/null

# 如果不是，扫描子目录
ls -d */  # 然后逐个检查子目录是否包含 .git
```

#### Shell 保留变量名禁区（重要）

在循环或脚本里，禁止将以下名字用作自定义变量，否则可能触发 `read-only variable` 错误：

`status`、`path`、`PATH`、`SECONDS`、`LINENO`、`RANDOM`、`PWD`、`OLDPWD`、`UID`、`EUID`、`PPID`

推荐短名替代：`st`、`p` / `repo_dir`、`br` 等。

确定范围后，对每个目标仓库依次执行以下步骤。

### 2. 确认分支

检查当前所在分支：

```bash
git branch --show-current
```

- **如果在 `main`（或 `master`）上**：必须先创建新分支再继续。分支名应基于改动内容，询问用户或根据改动自动生成一个有意义的名称。
- **如果已在功能分支上**：记录分支名，直接继续。

### 3. 跑全量测试

在 commit / push / PR 之前，必须至少跑一次全量测试，确保推送出去的代码是绿的。

**命令选择优先级**：

1. **优先使用 Makefile**：检查仓库根目录是否存在 `Makefile`，若存在则按顺序查找以下 target，命中即用 `make <target>`：
   - `test`
   - `tests`
   - `check`
   - `ci`
   - `test-all`

   检测方式：
   ```bash
   # 列出 Makefile 中的 target（简易匹配）
   grep -E '^[a-zA-Z_-]+:' Makefile | cut -d: -f1
   ```

2. **Fallback 到项目类型推断**：若无 Makefile 或无匹配 target，按项目类型选择默认命令：
   - Go 项目（`go.mod`）：`go test ./...`
   - Bun/Node 项目（`package.json` 中有 `test` 脚本）：`bun test` 或 `bun run test`
   - Rust 项目（`Cargo.toml`）：`cargo test`
   - Python 项目（`pyproject.toml` / `pytest.ini`）：`pytest`
   - 其他语言按惯例处理

3. **都无法确定**：停下并询问用户该用什么命令跑测试。

**失败处理**：

- **测试失败**：立即停止整个流程，把失败输出汇报给用户，等待用户修复或明确指示"跳过测试"后再继续。
- **用户明确要求跳过**：可在调用时说明（如"跳过测试直接推"），仅在此类明确指示下才可略过本步骤。

### 4. 提交未暂存的改动

检查工作区状态：

```bash
git status --short
```

- **如果有未提交的改动**：暂存相关文件并创建 commit。commit message 应与实际改动匹配。
- **如果工作区干净**：跳过此步，继续。

禁止使用 `git add .` 或 `git add -A`，必须明确暂存需要提交的文件。如有不确定是否应提交的文件（如 `.env`、凭据文件），必须先询问用户。

### 4.5 分支规范自查与 PR 草稿（pre-review）

在推送前对 `当前分支 vs base` 的 diff 做一次规范自查，发现违规自动修复并循环复审，通过后生成 6 段 PR 描述草稿，**作为步骤 6 创建 PR 时的 `--body`**。

#### 前置探测

```bash
test -f docs/spec/INDEX.md
```

- **不存在** → 跳过整个步骤 4.5，直接进入步骤 5（推送）。汇报中标注「未跑 pre-review：项目内无 `docs/spec/INDEX.md`」。
- **存在** → 继续 4.5.1。

#### 核心原则

1. **以规范为准，不以习惯为准**：subagent 与主 agent 都必须显式指明"这条违规对照的是哪条规范"，凭空"看着不顺眼"的修改一律拒绝。
2. **直修不商量**：发现违规默认直接修，**不停下来等用户确认**；仅当规范本身**冲突或缺失**时才停下问用户。
3. **循环到通过**：subagent → 修复 → subagent，**最多 3 轮**；3 轮还过不了说明规范或代码有结构性问题，停下来把分歧列给用户。
4. **简洁就是规范**：PR 草稿**整体硬上限 50 行**（含 6 段标题），超出就是违规。每段写多少自行裁量，但要把"信息密度优先于详尽"。

#### 4.5.1 派 subagent 做规范 review

使用 `Agent` 工具，`subagent_type: "general-purpose"`，**单次启动**（不要并行多个）。Prompt 必须包含：

- **任务说明**：拿 `git diff <base>...HEAD` 与 `git log <base>..HEAD --oneline` 输出，逐文件 / 逐 hunk 对照规范找违规。
- **规范来源（唯一）**：项目内 `docs/spec/INDEX.md` → 按需打开相关 spec 文件。
  - subagent **只**以 `docs/spec/` 下的内容为判定基准，禁止引入任何项目外的"通用最佳实践"、"全局规则"或自身训练记忆里的偏好；spec 没规定的视为允许。
  - 多份 spec 之间相互独立（spec 文档自包含），subagent 按 INDEX 找最相关的文档对照即可。
- **输出格式**（强制结构化，便于主 agent 解析）：
  ```
  ## 结论
  PASS | FAIL

  ## 违规项（仅 FAIL 时填）
  1. <文件:行号> — <违反了哪条规范的哪一条> — <建议修法（1 句）>
  2. ...

  ## 备注
  <可选：subagent 拿不准的、需要人工拍板的灰色地带>
  ```
- **明确禁令**：subagent **不许**直接改代码；只读 + 输出报告。

#### 4.5.2 主 agent 按报告修复

- 报告 **PASS** → 跳到 4.5.3。
- 报告 **FAIL**：
  1. 逐条按"建议修法"用 `Edit` 工具改代码；改动**只针对违规处**，禁顺手优化（编码四铁律 §3）。
  2. 改完后 `git add <改动文件>` + 新建一个 commit，message 形如 `chore: pre-review fixups`（保留为独立 commit，方便人工 review 时分辨"自查改了啥"）。
  3. 回到 4.5.1，**重新派一次 subagent** 复审。
  4. 累计 ≥ 3 轮仍 FAIL → 停下，把当前轮的违规项原样贴给用户，请求人工判断（可能是规范冲突或代码结构性问题），**不进入步骤 5**。

> ⚠️ subagent 报告的「备注」（灰色地带）不进入循环——这些直接复述给用户在最终汇报里，不要自作主张改。

#### 4.5.3 生成 PR 描述草稿

PASS 后，主 agent 根据 `git log <base>..HEAD` 和 diff 自行总结（**不再派 subagent**），按下面 6 段模板写一份草稿，**整体硬上限 50 行**（含 6 段标题）：

```markdown
## 背景
<改动发生在什么上下文 / 哪个模块，以及为什么现在要动它（动机：触发的 bug / 痛点 / 业务诉求 / 重构动机）。>

## 需求
<本次改动具体要满足哪些诉求 / 验收点（功能项、接口契约、行为预期等，能 bullet 就 bullet）。>

## 方案
<采取的关键技术路径或拆分思路。>

## 结果
<改完之后系统行为发生了什么变化（含错误码 / 接口变更 / 性能差等）。>

## 测试
<跑了哪些测试 / 新增了哪些用例 / 是否覆盖边界。未跑测试就写「未跑：原因」，禁谎报。>

## 规范
<对照 docs/spec/ 是否符合（点名命中的 spec 文件）；若 4.5.2 有改动，简述「自查修复了 X」。>
```

草稿保留在主 agent 上下文中，**直接作为步骤 6 创建 PR 时的 `--body`**，不需要落盘。

#### 4.5.4 自检（生成草稿后逐条过）

- [ ] 工作区是否已经干净（`git status --short` 为空）？
- [ ] 最后一轮 subagent 结论是否 PASS？
- [ ] 草稿整体是否 ≤ 50 行（含 6 段标题）？
- [ ] 「测试」一段是否如实反映了步骤 3 实际跑过的测试，未跑就明说「未跑」？
- [ ] 草稿是否准备好作为步骤 6 的 `--body`？

#### 反面案例（不要这样做）

- ❌ 没有 `docs/spec/INDEX.md` 也强跑 subagent（应直接跳过 4.5）。
- ❌ subagent 既读又改，自己改自己审。
- ❌ 「方案」写成长达半屏的实现细节——这是 PR 描述不是设计文档。
- ❌ 「测试」段写「测试已覆盖」却没跑过任何命令。
- ❌ subagent 找出问题后，主 agent 顺手把整个文件重排版 / 重命名变量。
- ❌ 循环超过 3 轮还在埋头改，不停下来汇报分歧。
- ❌ subagent 拿"通用最佳实践"或自身偏好挑刺，而不是引用 `docs/spec/` 里的具体条款。

### 5. 推送到远程

```bash
git push -u origin <branch-name>
```

如果推送失败，停止并报告错误。

### 6. 创建 PR

根据远程仓库平台选择工具：

- **GitHub**：使用 `gh pr create`
- **GitLab**：使用 `glab mr create`

判断方式：

```bash
git remote get-url origin
```

- 包含 `github` → 使用 `gh`
- 包含 `gitlab` → 使用 `glab`
- 其他情况 → 询问用户使用哪个工具

创建 PR 时：

- **标题简洁（≤ 70 字），反映改动内容**
- **PR body**：
  - 若步骤 4.5 跑过且 PASS → **直接使用 4.5.3 生成的 6 段草稿** 作为 `--body`（gh / glab 均通过 HEREDOC 注入）。
  - 若步骤 4.5 被跳过（项目无 `docs/spec/INDEX.md`）→ 用简短的改动要点（3-5 行 bullet 即可）作为 `--body`，并在描述里标注「未跑 pre-review：项目内无 `docs/spec/INDEX.md`」。
- 将 PR 链接展示给用户

注入示例（使用步骤 4.5 草稿时）：

```bash
gh pr create --title "<标题>" --body "$(cat <<'EOF'
## 背景
...
## 需求
...
## 方案
...
## 结果
...
## 测试
...
## 规范
...
EOF
)"
```

### 7. 处理 PR

PR 创建成功后，向用户明确询问处理方式（除非用户在调用时已显式声明，如"自动合并一下"、"我已经合了"、"建完直接关掉"）：

> PR 已创建：<PR 链接>
> 请选择处理方式：
> 1. **自动合并**：CI 通过后由平台自动 squash 合并并删除远程分支
> 2. **已合并**：你已在网页完成 review 与合并，我会校验状态后继续清理
> 3. **关闭 PR**：放弃本次改动，关闭 PR 并删除分支

- 用户选 **1** → 走 7a（自动合并）
- 用户选 **2** → 走 7b（已合并，需校验）
- 用户选 **3** → 走 7c（关闭 PR）

多仓库场景下逐仓库分别询问，互不绑定。

#### 7a. 自动合并

设置 PR 自动合并：

```bash
# GitHub（gh 用 --auto）
gh pr merge <PR_NUMBER> --squash --auto --delete-branch

# GitLab（glab 用 --auto-merge，注意与 gh 不同名）
glab mr merge <MR_IID> --squash --auto-merge --remove-source-branch
```

> ⚠️ 易错点：GitHub `gh` 是 `--auto`，GitLab `glab` 是 `--auto-merge`，不要混用。

自动合并 flag 让平台自行判断时机：CI 通过后立即 squash 合并并删除远程分支；若仓库未启用 auto-merge 功能，会立即报错，此时回退执行不带自动合并 flag 的同名命令做即时合并。

设置完成后，查询一次 PR / MR 状态确定后续走向：

```bash
# GitHub
gh pr view <PR_NUMBER> --json state -q .state

# GitLab
glab mr view <MR_IID> --output json | jq -r .state
```

状态值映射（GitHub → GitLab）：`MERGED` ↔ `merged`、`OPEN` ↔ `opened`、`CLOSED` ↔ `closed`。

- **已合并**（GitHub `MERGED` / GitLab `merged`）：合并已立即完成（CI 已通过或仓库无 CI 门槛），继续步骤 8、9 做本地清理。
- **仍开启**（GitHub `OPEN` / GitLab `opened`）：进入下方「CI 状态检查」决定挂起、等待平台动作或主动介入修复，**不要**直接挂起跳过检查。
- **命令报错**：先解析报错原因，按下表分流：
  - **仓库未启用 auto-merge**：回退到即时合并命令（见下），成功后继续步骤 8、9；仍失败则报告错误并等待指示。
  - **PR 与 base 分支存在冲突**：进入下方「冲突处理」流程，不要直接报告给用户。
  - **CI 失败**：进入下方「CI 状态检查」/「CI 失败处理」，不要直接报告给用户。
  - **权限不足或其他错误**：报告原始错误内容，等待用户指示。
  
  即时合并命令：
  ```bash
  # GitHub
  gh pr merge <PR_NUMBER> --squash --delete-branch

  # GitLab
  glab mr merge <MR_IID> --squash --remove-source-branch
  ```

##### CI 状态检查（自动合并模式专用）

PR 仍处 OPEN，或命令报错指向 CI 失败时，必须先查 CI / pipeline 实际状态再决定挂起、等待还是主动介入。**不能盲目相信 `--auto` 会自行兜底**——平台只会在 CI 通过后合并，CI 失败时 PR 会一直挂在那里不动，需要 Agent 主动介入。

```bash
# GitHub
gh pr checks <PR_NUMBER>
# 或结构化输出：gh pr view <PR_NUMBER> --json statusCheckRollup

# GitLab
glab mr view <MR_IID> --output json | jq -r '.head_pipeline.status // .pipeline.status // "none"'
# 或：glab ci status --branch <branch-name>
```

按结果分流：

- **无 CI checks**（输出 `no checks` / `none` 等）：`--auto` 没有等待门槛，稍等 1-2 秒重查 PR 状态；`MERGED` 进入步骤 8、9；仍 `OPEN` 则告知用户挂起后跳过步骤 8、9。
- **CI 全部通过**（all `pass` / `success`）：平台即将合并，稍等 1-2 秒重查 PR 状态；`MERGED` 进入步骤 8、9；仍 `OPEN` 则告知用户挂起后跳过步骤 8、9。
- **CI 进行中**（`pending` / `running` / `queued` / `in_progress`）：告知用户：
  > PR <链接> 的 CI 仍在运行。已设置自动合并，CI 通过后会自动 squash 合并并删除远程分支；若 CI 失败请告诉我，我会先修复错误再重试合并。

  skill 流程结束，**跳过步骤 8、9**，避免长时间挂起。
- **CI 失败**（任一 check 为 `fail` / `failure` / `error` / `cancelled`）：**不能挂起**，进入下方「CI 失败处理」。
- **状态查询命令报错**：报告原始错误（多半是网络或权限），等待用户指示。

##### CI 失败处理（自动合并模式专用）

发现 CI 失败时，按顺序介入，不要让 PR 挂在自动合并状态等下次 push：

1. **先取消自动合并**，避免修复 commit 触发 CI 通过后被平台立即合入（修复未经用户复核就被合并是高风险动作）：

   ```bash
   # GitHub
   gh pr merge <PR_NUMBER> --disable-auto

   # GitLab（无直接 flag，通过 API 调取消接口）
   PROJECT_ID=$(glab repo view --output json | jq -r .id)
   glab api -X POST "projects/${PROJECT_ID}/merge_requests/<MR_IID>/cancel_merge_when_pipeline_succeeds"
   ```

   若取消命令本身失败，先报告错误后再继续诊断（不阻塞下一步排查）。

2. **拉取失败详情**，定位具体失败 check 与日志：

   ```bash
   # GitHub
   gh pr checks <PR_NUMBER>                          # 看哪些 check 失败
   gh run view <RUN_ID> --log-failed                 # 失败 job 的日志

   # GitLab
   glab ci view                                      # 当前分支 pipeline 视图
   glab ci trace --job <JOB_ID>                      # 失败 job 的日志
   ```

3. **判断失败性质，二选一**（与上文「冲突处理」同思路）：

   - **机械性失败 → 自行修复，不打扰用户**。识别特征（满足任一即可）：
     - lint / format / 风格检查失败（`gofmt`、`prettier`、`eslint --fix`、`cargo fmt`、`ruff format` 等可一键修复）
     - import 排序、未使用变量、显式 unused 等明确规则违反
     - 文件末尾缺换行、行尾空格、EOL/EOF 类格式问题
     - lockfile 不一致（`bun install` / `go mod tidy` / `cargo update` / `pip-compile` 重新对齐即可）

     本地修复 → `git add <files>` → `git commit` → `git push`（普通 push 即可，无需 `--force-with-lease`）→ **重新执行步骤 7a 的自动合并设置命令**（取消后需重新设置）。CI 重新跑通过后平台会自动 squash 合并。

   - **业务性失败 → 立即停下，向用户报告并等待明确指示**。识别特征（满足任一即停）：
     - 单元测试 / 集成测试断言失败
     - 编译 / 构建错误
     - 类型检查错误（`tsc`、`mypy`、`go vet` 等带语义判断的失败）
     - 安全扫描、依赖审计、License check 等带策略判断的检查失败
     - 任何无法用"纯格式调整"解释的错误

     报告内容：失败的 check 名 + 关键错误日志（最具诊断价值的几行） + 你对失败性质的判断。在用户给出明确指示前，**不要 force push、不要 close PR、不要重新设置自动合并**，保持失败现场便于 review。

4. **边界判断不确定时按"业务性失败"对待**——宁可多打扰一次，不可在用户不知情时改动业务行为后被自动合并。

##### 冲突处理（自动合并模式专用）

当 `--auto`（或回退即时合并）因 base 分支冲突失败时，先在本地复现冲突、判断性质，再决定是否打扰用户。

1. **拉取 base 并尝试 rebase 复现冲突**：

   ```bash
   git fetch origin
   git rebase origin/main   # 若仓库默认分支是 master 则换成 origin/master
   ```

2. **判断冲突性质，二选一**：

   - **机械性冲突 → 自行解决，不提醒用户**。识别特征（满足任一即可视为机械性）：
     - 不同 import / use / require 语句的合并保留
     - 注释、空行、格式或缩进差异
     - 双方在不同位置追加的同类条目（配置项、枚举、列表项）且语义独立
     - 自动生成文件（lockfile、生成代码、快照）
     - 文档中并列章节的纯追加
     
     就地解决 → `git add <files>` → `git rebase --continue` → `git push --force-with-lease`（必须 `--force-with-lease` 而非 `--force`）→ 重新执行步骤 7a 的自动合并命令。
   
   - **触碰业务逻辑或设计语义 → 立即停下，向用户报告并等待明确指示**。识别特征（满足任一即停）：
     - 同一函数 / 方法的实现差异
     - 接口签名、参数列表、返回类型变化
     - 数据结构 / 类型定义 / schema 字段变化
     - 配置项语义变化（默认值、含义、可选值范围）
     - 测试断言冲突指向行为预期不一致
     - 任何无法用"纯机械合并"解释的差异
     
     报告内容：冲突文件清单 + 关键冲突段（含 `<<<<<<< HEAD` / `=======` / `>>>>>>>` 上下文）+ 你对冲突性质的判断。在用户给出明确指示前，**不要 `git rebase --continue` 也不要 `git rebase --abort`**，保持冲突现场。

3. **边界判断不确定时按"触碰逻辑"对待**——宁可多打扰一次，不可在用户不知情时改动业务行为。

#### 7b. 已合并

用户声明已在网页完成合并。**必须先查询 PR/MR 实际状态校验**，不要直接相信用户的口头确认（用户可能误点了 Close、关掉了页面没真合并、或合并到错的分支）：

```bash
# GitHub
gh pr view <PR_NUMBER> --json state -q .state

# GitLab
glab mr view <MR_IID> --output json | jq -r .state
```

按状态分支处理：

- **`MERGED` / `merged`**：合并已确认，继续步骤 8、9 做本地清理。
- **`OPEN` / `opened`**（PR 仍开启，实际未合并）：明确提醒用户并停下等待：
  > 检查到 PR <链接> 仍处于 OPEN 状态，似乎尚未完成合并。请到网页确认是否已点击 Merge，完成后再告诉我继续；
  > 如果你是想关闭而非合并，请说一声，我改走关闭 PR 流程（7c）。

  用户再次声明已合并后，**必须重新查询一次状态**再继续；连续两次校验失败则继续等待，不要凭口头确认进入清理。
- **`CLOSED` / `closed`**（已关闭未合并）：提醒用户：
  > PR <链接> 状态为 CLOSED，并未合并。是希望我按关闭 PR 流程（7c）继续清理本地，还是重新打开并合并？

  按用户指示再继续，不要自行决定。
- **状态查询命令报错**：报告原始错误（多半是网络或权限），等待用户指示。

#### 7c. 关闭 PR

用户选择放弃此次改动：

```bash
# GitHub（关闭并删除远程分支一步到位）
gh pr close <PR_NUMBER> --delete-branch --comment "<可选关闭说明>"

# GitLab（close 不会自动删除源分支，需后续步骤 9.3 探测删除）
glab mr close <MR_IID>
```

关闭成功后继续步骤 8、9 做本地清理：
- 步骤 8 切回 main 并 pull（即便没有合并，也保持本地 main 同步远端最新状态）。
- 步骤 9 删除本地分支与残留的远程引用（GitLab 场景下步骤 9.3 会探测并删除残留远程分支）。

如果 `gh pr close` / `glab mr close` 失败（多半是权限或 PR 已被他人处理），报告原始错误并停止，等待用户指示。

### 8. 拉取最新 main

由步骤 7（7a 已就地合并 / 7b 状态校验确认已合并 / 7c 已关闭 PR）进入本步骤：

```bash
git checkout main
git pull origin main
```

如果 pull 失败，停止并报告。

### 9. 删除功能分支

清理本地分支、远程分支、本地保存的远程引用三者，确保最终状态干净。**必须按 9.1 → 9.4 顺序全部执行**，不能因为前一步成功就跳过后面任意一步。

```bash
# 9.1 防御性确认当前在 main（步骤 8 已切，再 check 一次）
git rev-parse --abbrev-ref HEAD   # 必须输出 main 或 master，否则停止报错

# 9.2 删除本地分支：始终用 -D，不要先试 -d
git branch -D <branch-name>

# 9.3 删除远程分支：先探测是否还存在
if git ls-remote --exit-code --heads origin <branch-name> >/dev/null 2>&1; then
    git push origin --delete <branch-name>
fi

# 9.4 裁剪本地的远程引用
git fetch -p
```

#### 为什么这么写（必读）

- **9.2 用 `-D` 而非 `-d`**：squash merge 之后，功能分支的 commit hash 与 main 上 squash 后的新 commit 不同，`git` 不会把它识别为"已合并"，`git branch -d` 几乎一定失败；7c 关闭 PR 场景下分支根本没合并，`-d` 同样会拒绝。直接 `-D` 强制删除是正确做法——此时 PR 已被显式处理（7a/7b 状态查询已确认合并 / 7c 已关闭），分支安全可删。
- **9.3 先探测再删**：7a `gh --delete-branch` / `glab --remove-source-branch` 已删除远程分支；7c `gh pr close --delete-branch` 同样会删；7b 用户也可能在网页上点了"删除分支"。直接 `git push origin --delete` 会报"remote ref does not exist"。先用 `git ls-remote` 探测再决定。
- **9.4 必须执行**：即使 9.2 / 9.3 都成功，本地的 `refs/remotes/origin/<branch-name>` 仍然残留。不跑 `git fetch -p`，后续 `git branch -a` 会持续看到一堆已被合并删除的过期分支。这一步不可省略。

#### 失败处理

- **9.1 输出不是 main/master**：停止流程，报告当前分支名，等待用户指示（可能是步骤 8 的 checkout 失败被忽略了）。
- **9.2 失败**（极罕见，通常是 worktree 占用）：执行 `git worktree list`，若有 worktree 引用该分支，先 `git worktree remove <path>` 再重试 9.2。
- **9.3 失败**（探测显示远程还在但删除失败）：报告原始错误（多半是权限或 protected branch），等待用户指示。
- **9.4 失败**：报告原始错误并停止。

#### 多仓库场景

每个仓库各自完整执行 9.1–9.4，互不影响。任一仓库失败不阻塞其他仓库继续清理。

## 多仓库处理

当处理多个仓库时：

- 每个仓库独立执行流程（步骤 2-9），包括各自跑一遍全量测试与步骤 4.5 规范自查（若该仓库存在 `docs/spec/INDEX.md`）。
- 一个仓库失败（包括测试失败、pre-review 自修循环 ≥ 3 轮仍 FAIL）不影响其他仓库继续。
- 步骤 7 对每个仓库分别询问处理方式（自动合并 / 已合并 / 关闭 PR），不同仓库可选择不同方式：
  - **选择自动合并的仓库**：PR 创建后立即设置自动合并，按合并状态决定是否就地走步骤 8、9；CI 仍在跑的挂起跳过本地清理；CI 失败的仓库走「CI 失败处理」介入（机械性失败自行修复后重设自动合并，业务性失败停下报告），不跨仓库阻塞其他仓库。
  - **选择已合并的仓库**：先查询 PR 状态校验，状态为 MERGED 才走步骤 8、9；仍 OPEN 的仓库提醒用户后挂起，不进入清理。
  - **选择关闭 PR 的仓库**：立即关闭 PR 并走步骤 8、9 清理本地。
- 最终汇总报告每个仓库的处理结果（包含各自处理方式与状态）。

## 输出格式

最终回复简洁明确：

- 处理了哪些仓库
- 每个仓库创建的分支名和 PR 链接
- 哪些已成功合并并清理
- 哪些步骤失败及原因

## 停止条件

遇到以下情况必须停下，告知用户并等待指示：

- 全量测试失败（或找不到合适的测试命令且用户未明确指示）
- 步骤 4.5 pre-review 自修循环累计 ≥ 3 轮仍 FAIL（疑似规范冲突或代码结构性问题）
- 步骤 4.5 subagent 报告含「备注」类灰色地带（需人工拍板，不进入自修循环）
- 推送失败
- PR 创建失败
- 拉取 main 失败
- 分支删除失败
- 工作区存在不确定是否应提交的文件

## 禁止操作

- `git push --force`
- `git reset --hard`
- `git checkout -- .`
- 未经用户授权直接合并 PR（步骤 7 用户显式选择自动合并属于授权）
- 在自动合并模式下使用 `merge` 或 `rebase` 策略（必须使用 `--squash`）
- 提交包含敏感信息的文件（`.env`、凭据等）
