---
name: test-webview
description: 网页项目全量交互验证——Docker 整栈拉起→经浏览器 MCP（playwright/chrome-devtools）逐个跑完 webview 测试用例；每用例派隔离串行 subagent，主上下文只留 verdict 摘要；全程零并发；跑完无条件 docker compose down -v；失败转 /revise。触发：/test-webview、跑网页交互测试、端到端验证前端、webview 验收。跳过：非 web 项目、无浏览器 MCP、Docker 不可用。
argument-hint: [category]
disable-model-invocation: true
---

# Test-Webview 网页交互验证

用项目自带 Docker 整栈拉起应用，经浏览器 MCP 驱动真实浏览器逐用例验证。核心：**每个用例派一个隔离串行 subagent**，主上下文只留 INDEX + 各用例 verdict 摘要，几百上千用例不爆窗口。

## 核心原则（兼硬约束）

1. **全程串行、零并发**：浏览器 MCP 是单会话共享实例，并发会互相踩状态。主 agent 一次只派一个 subagent，等其返回 verdict 再派下一个
2. **上下文隔离**：冗长的 MCP 交互全留在 subagent 内，主上下文只累积结构化 verdict 摘要——这是 subagent 化的真实收益（不是提速）
3. **不调用 Workflow 工具**：派发用普通 Agent 工具逐个串行调用（参照 `/exec` 的逐步执行节奏）
4. **环境只用项目自己的、不生成**：只检测项目能否用 Docker 整栈拉起；**首次**确认拉起方式后**持久化、下次不再问**；不判断它是不是测试环境
5. **每次跑完清理干净**：无条件 `docker compose down -v`（含失败 / 中断路径），保证下次拉起的是干净环境与数据
6. **默认全量**：每次运行完整跑一遍全部用例；`/test-webview <category>` 仅跑某类
7. **只验证不改业务代码**：失败转 `/revise` 闭环，本 skill 自身不改实现
8. **输出中文**

## Agent 定义

通过 plugin 注册的 `subagent_type` 派工，数据通过 `prompt` 自包含传入：

| Agent | subagent_type | 角色 |
|---|---|---|
| 用例执行者 | `bb-spec-workflow:webview-test-runner` | 解析单个用例 JSON，映射浏览器 MCP 工具执行，返回 verdict |

## 工作流

### 步骤 0：读取配置

`cat .bb-spec.yaml 2>/dev/null` 取 `base_dir`（缺省 `.bb-spec`）；`${DOCS_DIR}` = `<base_dir>/docs`、`${CACHE_DIR}` = `<base_dir>/.cache`。`$ARGUMENTS` 非空 → 仅跑该 category，否则全量。

**缓存约定**：本 skill 的临时产物（截图）统一落 `${CACHE_DIR}/`（截图落 `${CACHE_DIR}/webview-shots/`），与交付物目录 `${DOCS_DIR}/` 平级、不混入。**首次写入前**确保 `${CACHE_DIR}/.gitignore` 存在——不存在则连目录一并创建、内容写单行 `*`（把整个 `.cache` 含其自身排除出 git，无需改动任何上层 `.gitignore`）。

### 步骤 1：前置检查（任一不过即中止并给指引）

- **是 web 项目**：`package.json` 含前端依赖（vue / react / vite / svelte 等）或存在 `index.html` + 前端 `src/`。非 web → 告知"本命令仅适用于网页项目"，中止。
- **浏览器 MCP**：当前工具列表含 `mcp__playwright__*` 或 `mcp__chrome-devtools__*` 任一 → 选定（**优先 playwright**），记为 `${MCP_FAMILY}`。都没有 → **提示安装**（`claude mcp add playwright -- npx @playwright/mcp@latest`，或安装 chrome-devtools MCP），中止。
- **Docker 可用**：`docker info` 探测；不可用 → **报错终止**（提示安装 / 启动 Docker）。

### 步骤 2：拉起测试环境（Docker，确认一次后记住）

读 `${DOCS_DIR}/test/webview/INDEX.md` frontmatter 的**已确认环境配置**（`up` / `down` 命令 + 前端服务→端口映射）：

- **已有配置** → 直接用，**不再询问**。
- **首次（无配置）**：探测项目 docker 拉起方式（`compose*.y*ml` / `Makefile` 目标 / `Dockerfile`）+ 识别前端服务及其端口，把"拉起命令 + 各前端服务→端口"呈现给用户，用 `AskUserQuestion` 让其**确认是否正确**（可纠正命令 / 端口）；**不判断是否测试环境、不生成任何环境**。探测不出拉起方式 → 让用户直接给出拉起命令。确认后**持久化到 INDEX.md frontmatter**（INDEX 不存在则在步骤 3 生成时一并写入）。

用确认的命令整栈 `up`（如 `docker compose up -d`）→ 等各服务就绪（健康检查 / 端口探活）→ 每个前端服务的 published port 推出对应 `${BASE_URL}`，建立 `服务名 → BASE_URL` 映射。

### 步骤 3：覆盖对齐 + 定位用例

UI 验证用例的生成与覆盖完整性都由本 skill 独占负责。

**覆盖对齐**（仅全量模式执行；`/test-webview <category>` 定向跑某类时跳过本环节，直接收集该类现有用例）：读 `${DOCS_DIR}/spec/`、`${DOCS_DIR}/plan/`、PRD（都没有则项目其他文档），把其中的 UI 交互验收点归纳为「应有场景集」，与 `${DOCS_DIR}/test/webview/` 现有用例比对，算出**缺口**（应测但无对应用例的场景）：

- **现有用例为空** → 缺口即全部，按规范生成全部用例。
- **有缺口**（部分应有场景无对应用例） → 用 `AskUserQuestion` 展示缺口清单，让用户二选一：①**补全后再跑**（按规范生成缺口用例）②**先跑现有、缺口记入报告**（步骤 5 显式列出，**禁静默漏测**）。
- **无缺口** → 直接进入收集。

新生成的用例按前端建顶层文件夹、其下按类别分（格式见下「测试用例文档规格」），落盘前先向用户展示清单确认。

**收集执行**：全量收集所有 category 下所有用例（定向模式仅收 `$ARGUMENTS` 指定的 category）。

### 步骤 4：串行派发执行

按**依赖拓扑序**串行派工（`dependsOn` 的用例先跑，无依赖关系按 INDEX 顺序）：**一次一个**用 Agent 工具派 `bb-spec-workflow:webview-test-runner`，等返回再派下一个（零并发）。

**派发前的依赖闸门**（执行顺序与依赖规范见 `references/webview-testcase-format.md`）：派某用例前先查它 `dependsOn` 的用例结果——**任一上游 `fail` / `error` / `skipped` → 本用例不派发、直接标 `skipped`，并级联到其传递依赖者**；上游全 `pass` 或本用例无依赖 → 正常派发。**独立用例的失败不影响其它独立用例**，继续跑完全部。检测到依赖成环 → 环内用例全标 `skipped` 并在报告点名。

每个 subagent 的 prompt 自包含，填充：

- `test_case_json`：该用例 md 里的 JSON 流原文
- `base_url`：该用例 `target` 前端对应的 `${BASE_URL}`（`target` 即用例所在顶层目录段）
- `mcp_family`：`${MCP_FAMILY}`（playwright | chrome-devtools）
- `project_context`：技术栈一句话（供选择器 / 等待策略参考）
- `screenshots_dir`：`${CACHE_DIR}/webview-shots/`（相对项目根，截图统一落此；派发首个用例前已按步骤 0 缓存约定确保该目录与 `.cache/.gitignore` 就位）

subagent 返回结构化 verdict：`{ caseId, category, status: pass|fail|error, failedStep, evidence, screenshots[] }`（`skipped` 由主 agent 在依赖闸门处赋予，不派发）。主 agent 只把 verdict 摘要记入内存，**不回读** MCP 交互细节。

### 步骤 5：聚合报告 + 回写状态 + 下一步

汇总各 verdict 写报告，更新 `${DOCS_DIR}/test/webview/INDEX.md` 的 last-run 状态列。

**报告格式**：

```
## Test-Webview 完成简报
- 环境：<up 命令> ｜ 前端：<服务名→URL 列表>
- 范围：<全部 N 用例 / category=X>
- 覆盖缺口（仅全量模式且用户选择暂不补全时，否则省略本行）：⚠️ E 个应有 UI 场景本轮未覆盖：<场景名列表>
- 结果：✅ 通过 A ｜ ❌ 失败 B ｜ ⚠️ 错误 C ｜ ⏭️ 跳过 D
- 失败明细：
  | 用例 | target | 失败步骤 | 证据 |
  |---|---|---|---|
  | <caseId> | <前端> | step#K <action> | <一句话 + 截图名> |
- 跳过明细（仅 D>0）：
  | 用例 | 因哪个上游失败 |
  |---|---|
  | <caseId> | <dependsOn 中失败的 caseId> |
- 下一步：<见下>
```

**下一步**：

- **全通过**（无失败 / 错误 / 跳过）→ 收尾完成。
- **有失败 / 错误**（跳过项是其上游失败的连带，修好上游后重跑即可恢复）→ 用 `AskUserQuestion` 询问是否 `/revise` 修复。用户同意 → 用 Skill 工具调用 `revise`，把失败用例的**标题 / `target` / 失败步骤 / evidence / 截图**作为输入传入，由 revise 诊断归因（spec / impl / 需求哪层）并闭环修复；本 skill 不自行改代码。

### 步骤 6：清理（无条件执行）

无论通过、失败还是中断，都执行环境清理：用记忆的 `down` 命令（缺省 `docker compose down -v`）拆容器 + 删数据卷，保证下次拉起干净。

## 测试产物目录与用例规格

在目标项目 `${DOCS_DIR}/test/` 下，**按前端建顶层文件夹、其下按类别分**、根 `INDEX.md` 索引：

```
${DOCS_DIR}/test/webview/
  INDEX.md                          # frontmatter 存已确认拉起配置；正文为前端→类别→用例表 + last-run 状态
  <frontend>/<category>/<case>.md   # <frontend> = INDEX env.frontends 的服务名；<category> = 功能领域
```

**为什么顶层永远按前端分**（即便当前只有一个前端）：结构不随前端数量变化——加第 N 个前端只是新建一个 `<frontend>/` 顶层目录，已有用例零迁移；同时不同前端下的同名 category（如各自的 `auth`）天然隔离、报告按前端聚合。

**INDEX.md frontmatter**（环境记忆，确认后写入）：

```yaml
---
env:
  up: docker compose up -d          # 已确认的整栈拉起命令
  down: docker compose down -v      # 清理命令（缺省即此）
  frontends:                        # 前端服务 → published port
    admin-frontend: 8080
    frontend: 8081
---
```

**每个用例 md 的骨架、JSON 流字段约定、抽象 action 词表**：见 `references/webview-testcase-format.md`，与 `webview-test-runner` 执行共用同一事实源；生成用例时按该规范产出。INDEX `env.frontends` 的服务名同时是用例 `target` 取值与落盘路径的 `<frontend>` 顶层目录段（二者必须一致）。

## 硬约束

- 全程**串行、零并发**；编排用普通 Agent 工具，**禁用 Workflow 工具**
- 全量模式跑前**必做覆盖对齐**（对照 spec / plan / PRD 算缺口）；缺口要么补全要么显式记入报告，**禁静默漏测**（定向 category 模式不适用）
- 环境只复用项目自带、**不生成**；首次确认后持久化、之后不再问；**不判断是否测试环境**
- 每次跑完**无条件清理**（含失败 / 中断路径），删容器 + 数据卷
- subagent prompt 自包含（看不到本对话）
- 只验证不改业务代码；失败修复一律走 `/revise`
- 浏览器 MCP / Docker 缺失即中止并给指引，**禁降级**为无环境跑
