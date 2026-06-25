---
name: test-api
description: 后端 API e2e 验证（语言无关）——Docker 整栈拉起→md 用例渲染为单文件 TS runner→`bun run` 顺序跑完→报告与 /revise 闭环；时间敏感规则（token 过期 / 订单超时 / 积分过期）经协议契约 /test/advance-time、/test/backdate、/test/trigger-job 测，应用侧用什么语言/库实现自选；零 subagent、零并发；跑完无条件 docker compose down -v。触发：/test-api、跑后端接口测试、API e2e 验收、验证后端业务流。跳过：Docker 不可用、Bun 不可用、应用未暴露 /test/healthz 协议。
argument-hint: [scope]
disable-model-invocation: true
---

# Test-API 后端 API e2e 验证

用项目自带 Docker 整栈拉起后端服务，把 md 用例**渲染为单文件 TS runner**后用 `bun run` 顺序跑完。核心：**API e2e 是确定性 HTTP 调用脚本，不派 subagent、不逐步操作**——agent 只做生成、调度、解析报告，真正执行由 bun 接管；**与后端实现语言完全解耦**。

## 核心原则（兼硬约束）

1. **零 subagent**：API 调用是确定性 HTTP，无 DOM 漂、无视觉判断，不需要 LLM 逐步介入。主 agent 一次渲染完整 runner → 一条命令跑完 → 解析 JSON 报告。**禁用 Workflow 工具**。
2. **md 是 source of truth**：用例文档 md 是产物与评审基线；`runner.ts` 与 `cases.json` 是每次执行前按 md 重新渲染的**机械派生物**，落 `${CACHE_DIR}/test-api-gen/`，禁手改、禁纳入版本控制。
3. **时钟串行**：时间敏感测试通过 `/test/advance-time` 等接口共享应用时钟，runner 顺序执行不并发——**用例间无任何并行**。
4. **后端语言无关**：被测应用用什么语言/框架/时钟库实现完全自由，只需暴露 `references/test-only-endpoints.md` 约定的 `/test/*` HTTP 协议。skill 与 runner 自身用 Bun + TS，**只依赖 host 上有 bun**，不依赖任何 Go / Python / Java 工具链。
5. **环境只用项目自己的、不生成**：检测项目是否提供 `compose.e2e.yaml`（须把 `/test/*` 接口在测试镜像中启用，启用机制由应用按本语言惯例自选——build tag / env / profile / feature flag 均可）；**首次**确认配置后**持久化、下次不再问**。
6. **应用侧契约前置**：应用须按 `references/test-only-endpoints.md` 协议契约暴露 `/test/*` 接口并保证生产构建默认禁用。skill 启动时探测 `/test/healthz`，不可用则中止、不降级为缩短 TTL 兜底。
7. **跑完无条件清理**：含失败 / 中断路径都执行 `docker compose down -v`。
8. **默认全量**：每次跑全部用例；`/test-api <scope>` 仅跑某个后端 scope。
9. **只验证不改业务代码**：失败转 `/revise` 闭环。
10. **输出中文**。

## 工作流

### 步骤 0：上下文探测 + 读取配置

1. **探测 root**：
   - 当前目录有 `.git` → **单 repo 模式**，root = 当前目录
   - 无 `.git`、有 workspace 标记（`.bb-workspace` 或用户 git-workflow 约定的标记）→ **多 repo 模式**，root 待步骤 2 与用户确认是落工作区根（跨 repo 整栈）还是某个 repo 内
   - 无 `.git`、无 workspace 标记 → 报错中止：「需要在 git 仓库或 bb-workspace 内运行」，不自动 `git init`
2. **读 `.bb-spec.yaml`**：取 `base_dir`（缺省 `.bb-spec`）；`${DOCS_DIR}` = `<root>/<base_dir>/docs`、`${CACHE_DIR}` = `<root>/<base_dir>/.cache`。
3. **缓存目录约定**：本 skill 临时产物（生成的 `runner.ts` / `cases.json`、runner 输出 `result.json`、docker logs）统一落 `${CACHE_DIR}/test-api-gen/`、`${CACHE_DIR}/test-api-logs/`，**首次写入前**确保 `${CACHE_DIR}/.gitignore` 存在——不存在则连目录一并创建、内容写单行 `*`。
4. `$ARGUMENTS` 非空 → 仅跑该 scope，否则全量。

### 步骤 1：前置检查（任一不过即中止并给指引）

- **Docker 可用**：`docker info` 探测；不可用 → 报错中止（提示安装 / 启动 Docker）。
- **Bun 可用**：`bun --version` 探测；不可用 → 报错中止并给一行安装指引（macOS / Linux：`curl -fsSL https://bun.sh/install | bash`；Windows：`powershell -c "irm bun.sh/install.ps1 | iex"`）。

> 不再检查被测应用的语言——是否能跑测试由「步骤 2 拉起后 `/test/healthz` 是否 200」单一信号决定。应用是 Go / Python / Node / Java / Rust 任意一种都行，只要按 `references/test-only-endpoints.md` 协议暴露 `/test/*` 接口。

### 步骤 2：拉起测试环境（Docker，确认一次后记住）

读 `${DOCS_DIR}/test/api/INDEX.md` frontmatter 的**已确认环境配置**：

- **已有配置** → 直接用，**不再询问**。
- **首次（无配置）**：用 `AskUserQuestion` 顺序确认：
  1. `compose.e2e.yaml` **落点**（推荐顺序作 default：① 后端单服务 → `backend/compose.e2e.yaml`；② 后端多服务 / 跨 frontend → `<root>/compose.e2e.yaml`；③ 已有 deploy 约定 → `deploy/e2e/compose.e2e.yaml`；多 repo + 跨 repo 整栈 → 强制落工作区根）。文件不存在 → 引导用户按 `references/test-only-endpoints.md` 创建后再继续，**不自动生成**。
  2. **后端 service 名 + 端口**：从 compose 文件解析候选，让用户确认要测的 API service 与 published port。
  3. **健康检查 URL**：缺省 `<base_url>/test/healthz`（与 `references/test-only-endpoints.md` 约定一致）。
  4. 确认后**持久化到 INDEX.md frontmatter**（首次跑时一并落 INDEX）。

用确认的命令整栈 `up`（`docker compose -f <compose_file> up -d --build`）→ 轮询 `/test/healthz` 至 200（默认超时 60s）→ 探测失败 → 收集 `docker compose logs` 落 `${CACHE_DIR}/test-api-logs/` 后中止。

### 步骤 3：覆盖对齐 + 收集用例

API e2e 用例的生成与覆盖完整性都由本 skill 独占负责。

**覆盖对齐**（仅全量模式执行；`/test-api <scope>` 定向跑某类时跳过本环节）：读 `${DOCS_DIR}/spec/`、`${DOCS_DIR}/plan/`、PRD（都没有则项目其他文档），把其中的 API 行为验收点 + 时间敏感规则归纳为「应有场景集」，与 `${DOCS_DIR}/test/api/` 现有用例比对，算缺口：

- **现有用例为空** → 缺口即全部，按 `references/api-testcase-format.md` 生成全部用例。
- **有缺口** → `AskUserQuestion` 展示清单，二选一：①补全后再跑 ②先跑现有、缺口记入报告（步骤 5 显式列出，**禁静默漏测**）。
- **无缺口** → 直接进入收集。

新生成的用例按后端 scope 建顶层文件夹、其下按 category 分（格式见 `references/api-testcase-format.md`），落盘前先向用户展示清单确认。

**收集**：全量收集所有 scope 下所有用例（定向模式仅收 `$ARGUMENTS` 指定 scope）。

### 步骤 4：渲染为 TS runner → 一次性执行

**渲染**（主 agent 一次完成，不派 subagent）：

1. **指纹命中复用**：对入选用例的所有 md 文件按路径排序、内容拼接，与 `references/runner-ts-template.md` 内容一并求 SHA-256 得 `current_fingerprint`。读 `${CACHE_DIR}/test-api-gen/.fingerprint`——等于 `current_fingerprint` 且目录下 `runner.ts` + `cases.json` 齐全 → **跳过渲染**直接进入执行；否则清空 `${CACHE_DIR}/test-api-gen/`、按下一步重新渲染，渲染完把 `current_fingerprint` 写入 `.fingerprint`。
2. 按 `references/runner-ts-template.md` 把入选用例渲染为：

```
${CACHE_DIR}/test-api-gen/
  .fingerprint                 # 命中复用指纹：入选 md + runner-ts-template.md 的 SHA-256
  runner.ts                    # 单文件 TS runner：读 cases.json 顺序跑 → 写 result.json
  cases.json                   # 入选用例的 JSON 流原样拼接 + INDEX 注入的 backends 映射
```

**依赖拓扑**：`cases.json` 里的用例已由渲染阶段按 `dependsOn` 拓扑序排好。runner 在每个用例执行前查 `status` map：任一上游 `fail` / `skipped` → 本用例标 `skipped` 并级联。依赖成环 → 渲染阶段报错点名、不进入执行。

**执行**：
```bash
cd ${CACHE_DIR}/test-api-gen
bun run runner.ts > ${CACHE_DIR}/test-api-logs/runner.log 2>&1
# runner 自身把结果写到 ./result.json（schema 见 runner-ts-template.md）
```
（runner 串行 await 每个用例，**无任何 Promise.all / concurrent 调用**——时钟串行约束）

### 步骤 5：聚合报告 + 回写状态 + 下一步

解析 `${CACHE_DIR}/test-api-gen/result.json`（runner 自定义 schema，见 `references/runner-ts-template.md`），汇总写报告，更新 `${DOCS_DIR}/test/api/INDEX.md` last-run 状态列。

**报告格式**：

```
## Test-API 完成简报
- 环境：<compose_file> ｜ 后端：<service→base_url 列表>
- 范围：<全部 N 用例 / scope=X>
- 覆盖缺口（仅全量且暂不补全时，否则省略）：⚠️ E 个应有 API 场景本轮未覆盖：<场景名列表>
- 结果：✅ 通过 A ｜ ❌ 失败 B ｜ ⚠️ 错误 C ｜ ⏭️ 跳过 D
- 失败明细：
  | 用例 | scope | 失败步骤 | 期望 vs 实际 |
  |---|---|---|---|
  | <caseId> | <scope> | step#K <action> | <断言摘要> |
- 跳过明细（仅 D>0）：
  | 用例 | 因哪个上游失败 |
  |---|---|
  | <caseId> | <dependsOn 中失败的 caseId> |
- 下一步：<见下>
```

**下一步**：

- **全通过** → 收尾完成。
- **有失败 / 错误** → `AskUserQuestion` 询问是否 `/revise` 修复。同意 → 用 Skill 工具调用 `revise`，把失败用例的**标题 / scope / 失败步骤 / 期望 vs 实际 / 相关 docker logs 片段**作为输入传入；本 skill 不自行改代码。

### 步骤 6：清理（无条件执行）

无论通过、失败、中断，都执行：`docker compose -f <compose_file> down -v` 拆容器 + 删数据卷。生成的 `runner.ts` / `cases.json` / `result.json` 保留在 `${CACHE_DIR}/test-api-gen/` 供二次调试（`.cache` 已被 gitignore，不污染版本控制）。

## 测试产物目录与用例规格

```
${DOCS_DIR}/test/api/
  INDEX.md                          # frontmatter 存已确认环境配置；正文为 scope→category→用例表 + last-run 状态
  <scope>/<category>/<case>.md      # <scope> = INDEX env.backends 的 service 名；<category> = 功能领域
```

**为什么顶层永远按 scope 分**（即便当前只有一个后端）：结构不随后端服务数量变化——加第 N 个后端只是新建一个 `<scope>/` 顶层目录，已有用例零迁移；同时不同 scope 下的同名 category（如各自的 `auth`）天然隔离、报告按 scope 聚合。

**INDEX.md frontmatter**（环境记忆，确认后写入）：

```yaml
---
env:
  compose_file: backend/compose.e2e.yaml   # 相对 root
  backends:                                        # 服务名 → base_url
    api: http://localhost:8080
  health_path: /test/healthz                       # 健康检查路径（拼到各 base_url）
  test_endpoints_prefix: /test                     # 协议契约的测试接口前缀
---
```

**用例 md 骨架、JSON 流字段、action 词表**：见 `references/api-testcase-format.md`。
**应用侧 `/test/*` 协议契约 + 多语言隔离机制样板**：见 `references/test-only-endpoints.md`。
**md → 单文件 TS runner 的渲染模板**：见 `references/runner-ts-template.md`。

三份规范与本 SKILL.md 共用同一事实源，改格式只改对应 references。

## 硬约束

- **零 subagent、零并发**：编排不派 Agent，runner 内 `await` 顺序执行用例、**禁 `Promise.all` 等并发**；**禁用 Workflow 工具**
- 全量模式跑前**必做覆盖对齐**；缺口要么补全要么显式记入报告，**禁静默漏测**
- 环境只复用项目自带 `compose.e2e.yaml`、**不自动生成**；首次确认后持久化、之后不再问
- 应用必须按 `references/test-only-endpoints.md` 协议契约暴露 `/test/*` 接口（实现语言与隔离机制自选）；探测 `/test/healthz` 失败即中止，**禁降级为缩短 TTL 兜底**
- 每次跑完**无条件清理**（含失败 / 中断路径），删容器 + 数据卷
- 生成的 `runner.ts` / `cases.json` / `result.json` 落 `${CACHE_DIR}/`、禁纳入版本控制；md 用例是唯一 source of truth
- 只验证不改业务代码；失败修复一律走 `/revise`
- Docker / Bun / `/test/healthz` 任一不可用即中止并给指引，**禁降级**为无环境跑
