---
name: init
description: Reverse-spec-ification for onboarding. When the target project has no .bb-spec/docs/spec/INDEX.md, read existing code and docs and distill the already-enforced implicit conventions into a set of ≤100-line spec documents, in the exact directory and index structure /spec uses. Split large projects into parallel subagents by functional area. TRIGGER — /init / reverse-generate specs for an existing project / document existing conventions / onboard a project to the bb-spec workflow. ｜ 项目初始化反向 spec 化。当目标项目还没有 `.bb-spec/docs/spec/INDEX.md` 时，阅读现存代码与文档，把"已经在执行的隐式规范"沉淀为一组 ≤ 100 行的 spec 文档，纳入与 `/spec` 完全一致的目录与索引结构。庞大项目按独立功能区拆 subagent 并发提取。常见触发：用户输入 `/init`、"给现有项目反向生成 spec"、"把现有规范文档化"、"项目要接入 bb-spec 工作流"。
---

# Init 反向 Spec 化

`/spec` 从对话正向产出规则；`/init` **从已有代码与文档反向提炼规则**。落点完全对齐 `/spec`：同一份 `INDEX.md`、同一套 frontmatter、同一份 ≤ 100 行的"一文一规则"格式，使 `/plan`、`/exec`、`/revise` 可直接接力。

## 核心原则（兼硬约束）

1. **只提炼"规则"不誊抄"实现"**：写入 spec 的必须是跨实现的硬约束（错误码格式、命名约定、不变量、业务策略、安全 invariant），而非某个函数怎么写
2. **格式与 /spec 完全对齐**：frontmatter（`name` + `description`）、路径 `${DOCS_DIR}/spec/<分区>/<name>.md`、按分区分组的 `INDEX.md`——任何不一致都会破坏后续 `/plan` 闭环
3. **每条规则必举例且有来源**：从代码挑一处真实场景作"例子"，例子末尾标注 `来源：file:line`，无来源不准落盘，禁凭空抽象
4. **并发只拆分区不拆决策**：subagent 只产**结构化候选规则草案**且**禁写盘**；所有 Write/Edit 由主 agent 串行执行以保证格式一致
5. **用户裁决拆分**：分区清单先给用户确认再派工，避免基于错误切分跑一长串无效 agent
6. **纯净现态**：只写**当前代码已在执行**的规则，禁写"应该但还没做"或"历史遗留"（用户想补"应然"则提示走 `/spec`）
7. **冲突不自决**：代码本身的冲突一律抛给用户裁决
8. **单文件 ≤ 100 行、禁跨文档引用、语言跟随用户**：超 100 行即拆；每份 spec 自包含不写"详见 X.md"；正文用用户的工作语言，标识符/API/错误码保持英文

---

## 工作流

### 步骤 0：读取配置 + 检测 spec 现状

`cat .bb-spec.yaml 2>/dev/null` 取 `docs_dir`（缺省 `.bb-spec/docs`），后续记作 `${DOCS_DIR}`，spec 目录即 `${DOCS_DIR}/spec/`。

`ls ${DOCS_DIR}/spec/INDEX.md 2>/dev/null`：

- **不存在 / 为空** → 进步骤 1
- **已存在且非空** → 绝不静默覆盖，向用户三选一：
  - `跳过`：告知"已有 INDEX.md，未做任何改动"并退出
  - `增量补全`：读完现有 INDEX.md + 全部已有 spec 后，仅提炼"既有未覆盖的规则"，与既有文档**互不重叠**
  - `全量重做`：先 `mv ${DOCS_DIR}/spec ${DOCS_DIR}/spec.bak.<时间戳>` 备份再走全流程，过程中可参考 `.bak`

### 步骤 1：项目盘点

主 agent 自做，产出"分区清单候选"，不下钻代码细节：

1. 顶层结构：`ls`、根目录 `README*` / `CLAUDE.md` / `docs/` / `ARCHITECTURE.md` / `CONTRIBUTING.md`
2. 技术栈：`package.json` / `go.mod` / `pyproject.toml` / `Cargo.toml` / `pom.xml` / `Dockerfile` / `*.tf` 等
3. 模块边界：codegraph 可用则 `codegraph_status` + `codegraph_files <顶层目录>`，否则 `ls -la <主源码目录>`
4. git 主题：`git log --oneline -50` 粗看历史里反复出现的模块名 / 主题词

回显给用户：栈 / 主源码目录 / README 与 CLAUDE.md 提示的核心主题 / 已有显式文档清单（或"无"）。

### 步骤 2：识别"独立功能区"并向用户确认

按优先级切分（同一项目可混用）：

1. **架构层**：API / Service / Repository / Domain / Infra（Go 三层、DDD 四层都适用）
2. **业务模块**：用户 / 订单 / 支付 / 权限 / 通知（看顶层目录或 package 命名）
3. **前端特性区**：路由 / 页面 / 组件库 / 状态管理 / API client
4. **横切关注点**：日志 / 错误码 / 配置 / 鉴权 / 限流 / 缓存 / 监控（**单独一区**，跨模块共享的硬约束几乎都落这里）
5. **运维 / CI**：Docker / GitHub Actions / 部署脚本

输出分区候选清单（分区名 + 一句话描述 + 大致涉及目录），并把横切关注点单列一区，询问用户：`确认 / 调整分区 / 合并 / 拆分？`

### 步骤 3：方案质检（向用户确认前的自检）

逐项自问，发现问题先调整再展示：

1. **伪规则分区**：某分区能想到的"规则"其实都是语言/框架自带保证（如"TypeScript 必须有类型注解"）？删
2. **漏横切**：错误码 / 日志格式 / 时间戳精度 / ID 生成 / 命名约定这些跨模块硬约束有没有专门分区兜？没有就补
3. **可合并**：两分区预期产出 >50% 重叠？合
4. **是否必拆**：源码 < 20 文件就别拆，单个主 agent 一遍提炼到位

质检后展示最终分区，等"确认"再进步骤 4。

### 步骤 4：并发派工（rule-extractor subagent 提取候选规则）

每分区派 1 个 `Agent`（`subagent_type: bb-spec-workflow:rule-extractor`，只读、禁写盘，模型由 agent 定义指定），**同一条消息内**并发发出。prompt 传入：
- `partition_name`：分区名
- `scan_scope`：扫描范围（目录列表 / glob）
- `project_stack`：语言、框架（便于判断哪些是框架自带保证）
- `existing_index`：已有 spec INDEX.md 内容；无则"无既有 spec"

提取任务、输出结构、五条筛选标准与禁止事项均由 agent 定义自包含。

降级：项目很小或用户在步骤 3 选"不拆"，主 agent 读取插件 `agents/rule-extractor.md` 直接执行一份等价提取任务，跳过并发。

### 步骤 5：合并、去重、落盘

主 agent 收集所有 subagent 返回的候选清单：

1. **跨分区去重**：同名 / 同义合并为一条，保留 confidence 高 + source_refs 多的版本
2. **横切优先**：错误码格式、命名约定等若被多分区识别，统一归入"横切"分区
3. **冲突标注**：代码本身存在不一致（两处 `file:line` 互斥）不硬选，候选条目加 `conflict: <描述>`，进步骤 7 让用户裁决
4. **格式化为 spec 文档**：每条候选生成一个 `.md`，套用模板（与 `/spec` 完全一致）：

```markdown
---
name: <kebab-case，与文件名一致>
description: <≤ 80 字>
---

# <规则标题>

## 目的
<一句话>

## 逻辑
<3-10 行>

## 约束
<每条约束必须可测，且在「验收」里有对应项；禁止"健壮/友好/高性能"类无判定标准的表述。>
- <约束 1>
- <约束 2>

## 例子
<具体场景。结尾标注：来源：file:line[, file:line]>

## 验收
- [ ] <可测试验收项 1>
- [ ] <可测试验收项 2>
```

路径 `${DOCS_DIR}/spec/<分区>/<name>.md`，**强制按分区建子目录**（与 `/spec` 一致）：禁扁平放置（如 `<分区>-<name>.md` 或裸 `<name>.md`）；分区即便只 1 条规则也建子目录，避免后续迁移；`<分区>` 用 kebab-case，与 INDEX.md 分组标题一一对应。

### 步骤 6：生成 / 更新 INDEX.md

```markdown
# Spec 索引

> 每条一行。读者先扫此页判断相关性，再打开具体文件。

## <分区 1>

- [name](path.md) — description

## <分区 2>

- ...
```

按分区分组，同分区字母序。若步骤 0 选"增量补全"，在既有 INDEX.md 上**追加**新条目，不动既有条目。

### 步骤 7：跨文档一致性 review + 冲突清单

落盘后主 agent 快速扫一遍：同一术语命名是否一致（用户 vs User vs Account）/ 约束是否互斥（A 说"超时 5s"，B 说"超时 10s"）/ 例子是否冲突。把发现的不一致 + 步骤 5 标注的代码冲突合成清单输出，让用户裁决——**禁自作主张改任何一份 spec**。

### 步骤 8：完成简报

```
## /init 完成简报

- 模式：全新生成 / 增量补全 / 全量重做（已备份至 <bak 路径>）
- 分区：N 个（<逐项列出>）
- 派工：M 个 rule-extractor agent（并发） / 主 agent 直跑
- 产出：新增 K 条 spec（<分区>/<name> — <description>）
- 跳过候选：J 条（理由：框架自带保证 / 孤例 / 实现细节）
- 待用户裁决冲突：L 条（<一句话描述> — <file:line> vs <file:line>）
- 下一步：解决冲突后运行 `/plan` 基于这套 spec 生成实施计划；或 `/spec` 补本次未覆盖的新需求
```

---

## 与 /spec 的边界

`/init` 仅在"项目首次接入 bb-spec 工作流"或"用户主动要求批量反向梳理"时使用，不要当日常工具。单条新增 / 修订规则走 `/spec`。`/init` 跑完后，后续维护一律走 `/spec`（编辑既有文件 + 跨文档 review）。
