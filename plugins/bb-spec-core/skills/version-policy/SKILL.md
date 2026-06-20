---
name: version-policy
description: 依赖引入与版本选择策略——官方库/标准库优先；新增第三方库必须先询问用户获同意；写版本号前必经官方渠道验证最新版，禁凭训练记忆。触发：编辑 package.json/go.mod/Cargo.toml/Dockerfile/CI workflow/Helm/Terraform 等钉死版本号的文件、新增拉新包的 import、用户要求升级/加库/bump/更新 Actions。跳过：仅改本地代码、仅删依赖、用户已指定具体版本。
user-invocable: false
---

# 依赖引入与版本管理策略

适用于：**一切会被钉死到项目文件里的外部资产版本号 / tag / digest 的引入与升级**。

> 核心理念：**先问"该不该引入"，再问"引入哪个版本"。** 官方库 / 标准库优先，新增第三方库须经用户同意；任何版本号在写入文件前都必须经官方渠道验证（训练数据有截止时间，凭记忆填写的"最新版本号"几乎总是过时的）。

## 0. 触发场景

**TRIGGER**（命中任一即应应用本策略）：

- 编辑或新增以下任何文件中的版本声明：
  - **语言包**：`package.json`、`bun.lockb`、`go.mod`、`go.sum`、`requirements.txt`、`pyproject.toml`、`Cargo.toml`、`pom.xml`、`build.gradle(.kts)`
  - **运行时与工具链**：`.nvmrc`、`.tool-versions`、`.python-version`、`Dockerfile` 中的 `FROM` 行、`go.mod` 中的 `toolchain` 指令
  - **CI 配置**：`.github/workflows/*.yaml`（`uses: actions/*@vX`）、`.gitlab-ci.yaml`（`include` 与 components）
  - **容器**：`Dockerfile` 的 `FROM`、`docker-compose.yaml` / Helm chart / K8s manifest 中的 `image:` tag
  - **IaC**：Terraform / OpenTofu `required_providers`、Pulumi 包、Helm chart `version`
  - **CLI 工具锁定**：`brew install <pkg>@<version>` / `apt install <pkg>=<version>` / `curl ... | sh` 等
- 用户明确要求：
  - "升级依赖" / "更新依赖" / "bump 版本"
  - "加一个 xxx 库 / package / dependency"
  - "更新一下 GitHub Actions"
  - "把 Node / Python / Go 版本升一下"

**SKIP**（以下情况本策略不适用）：

- 仅修改本地代码，不涉及任何版本号文件
- 仅删除依赖
- 用户在对话中明确指定了具体版本号（按用户指定执行，但仍需提醒该版本是否最新）

---

## 1. "依赖"的完整范围

不限于包管理器声明。本策略覆盖以下**所有**类型：

| 类别 | 典型文件 / 位置 | 查询命令示例 |
|---|---|---|
| npm 生态 | `package.json` | `npm view <pkg> version` / `bun pm view <pkg>` |
| Go 模块 | `go.mod` | `go list -m -versions <module>` |
| Python | `requirements.txt`、`pyproject.toml` | `pip index versions <pkg>` |
| Rust crate | `Cargo.toml` | `cargo search <crate>` |
| Java | `pom.xml`、`build.gradle` | Maven Central 搜索 |
| 运行时 | `.nvmrc`、`.tool-versions` | 官方发布渠道 |
| GitHub Actions | `.github/workflows/*.yaml` | `gh api /repos/<owner>/<repo>/releases/latest --jq .tag_name` |
| 容器镜像 | `Dockerfile`、`docker-compose.yaml` | Docker Hub / GHCR tags 页 / `crane ls <image>` |
| Helm chart | `Chart.yaml` | `helm search repo <chart> --versions` |
| Terraform provider | `*.tf` | `https://registry.terraform.io/providers/<ns>/<name>` |

---

## 2. 引入门槛：官方库优先，第三方库须用户同意（强制）

本节是版本选择的**前置门**——先通过这道门，才进入后续"查版本、选版本"流程。

### 默认顺序

实现任何功能时，按以下优先级选取依赖来源：

1. **标准库 / 语言官方库**（如 Go 的 `database/sql`、`net/http`，Python 的 `json`、`http.server`）
2. **项目已有依赖**（已在 `go.mod` / `package.json` / lockfile 中的库，继续使用不算新增）
3. **新增第三方库**——最后手段，且**必须先经用户同意**

### 新增第三方库的同意流程

在写入任何 `import` 语句或依赖文件**之前**，必须先向用户说明并获得**明确同意**：

- **为什么标准库 / 官方库 / 已有依赖不能满足**（缺能力？实现成本过高？）
- **候选库是什么**（名称、用途、维护状态）

用户同意后才能导入；用户拒绝则改用标准库或现有依赖实现。

### 豁免

- 用户在对话中**主动点名**要求使用某个第三方库 → 视为已同意，直接引入（版本仍按 §3 查最新）
- 依赖已列入**经用户批准的实施计划**的「新增第三方依赖」清单（如 `/plan` 的 ExitPlanMode 批准）→ 批准即同意，不需重复询问（版本仍按 §3 查最新）
- 使用项目**已有**第三方依赖 → 不需重复审批

### 严禁的做法

- ❌ 未经询问直接 `import` 新第三方库，再事后告知
- ❌ 标准库可满足却默认引入第三方封装（如用第三方 HTTP 框架替代 `net/http` 而未经用户同意）
- ❌ 以"业界常用""更优雅"为由跳过询问

---

## 3. 引入前必查最新版本（强制）

**在写入版本号之前**，Agent 必须先通过**官方渠道**查询当前最新版本。

### 严禁的做法

- ❌ 凭训练记忆填写版本号（典型翻车：vite 实际已 8.x 却写 6.x；`actions/checkout` 实际 v6 却写 v4）
- ❌ 复用既往项目中见过的版本号
- ❌ LLM 猜测 / 推断版本号
- ❌ 仅依赖 `WebSearch` 搜索结果中的版本号，**未访问官方源**确认

### 推荐查询方式（按类型）

**npm 生态**：
```bash
npm view <pkg> version              # 单一最新版本
bun pm view <pkg>                   # bun 方式
# 或访问 https://www.npmjs.com/package/<pkg>
```

**Go 模块**：
```bash
go list -m -versions <module>       # 列出所有版本
# 或访问 https://pkg.go.dev/<module>
```

**Python**：
```bash
pip index versions <pkg>
# 或访问 https://pypi.org/project/<pkg>
```

**Rust**：
```bash
cargo search <crate>
# 或访问 https://crates.io/crates/<crate>
```

**GitHub Actions**：
```bash
gh api /repos/<owner>/<repo>/releases/latest --jq .tag_name
# 或访问 https://github.com/<owner>/<repo>/releases
```

**容器镜像**：
```bash
docker run --rm quay.io/skopeo/stable list-tags docker://<image>
crane ls <image>
# 或访问 Docker Hub / GHCR 的 tags 页面
```

**Helm chart**：
```bash
helm search repo <chart> --versions
# 或访问 ArtifactHub
```

**Terraform / OpenTofu provider**：
- 访问 `https://registry.terraform.io/providers/<ns>/<name>`

**运行时与工具链**（Node.js、Java、Python、Go、Bun、Ubuntu 等）：
- 以各自官方发布渠道为准

**兜底**：以上命令不可用时，用 `WebFetch` / `WebSearch` 访问官方 release 页或 changelog；**不可**直接输出搜索结果摘要中的版本号，必须打开官方页面确认。

---

## 4. 版本选择优先级

除用户特殊声明外，按以下顺序选取版本：

1. **有 LTS 概念**的依赖（Node.js、Java、Python、Ubuntu、Spring Boot、Angular 等）：
   - 优先选用**当前最新的 LTS** 版本
   - 例：Node.js 选 22.x LTS 而非 23.x current
   
2. **无 LTS 概念**的普通库（绝大多数 npm / Go / Python / Rust 包、GitHub Actions、容器镜像、Terraform provider 等）：
   - 选用**最新稳定版本**（Latest Stable）

3. **禁止**直接选用以下版本：
   - alpha / beta / rc / nightly / preview / snapshot 等预发布版本
   - 已 EOL（End of Life）或已被官方标记 deprecated 的版本

---

## 5. 偏离须说明

如确需锁定到非最新版本，必须在 **PR 描述或 commit message** 中写明：

- **原因**：兼容某既有依赖 / 规避已知 bug / 特定 CVE 锁版 / 团队尚未验证新版兼容性 等
- **回滚条件**：何时可以解除锁定（如"等 X 库发布 vN 修复后"）

不写明原因的"莫名锁旧版"应在 review 中被拦回。

---

## 6. 升级既有依赖

为已有项目升级依赖时同样适用本策略，**不因"只是升级"而豁免查询**：

- `bun update <pkg>` / `go get -u <module>` / `cargo update -p <crate>` 等命令执行**前**应先确认目标版本
- Dependabot / Renovate 批量 PR：逐项核对升级目标是否为当前最新稳定版
- 批量升级 PR 必须列出：
  - **版本变更清单**（from → to）
  - **影响面评估**（breaking change / API 变化 / 行为变化 / 依赖链传染）
  - **测试验证情况**

---

## 7. 与其他规范的关系

- **包管理器选择**：前端统一使用 `bun`（详见前端规范），不在本 skill 范围内
- **Go 依赖同步**：每次 `import` 变更后必须 `go mod tidy`（详见 Go 项目规范）
- **PR 描述规范**：依赖升级 PR 的描述同样遵循"背景/原因/优化方案"三段式（详见 Git 工作流规范）

---

## 8. 自检清单（写入版本号前）

在保存任何含版本号的文件前，逐项确认：

- [ ] 已确认标准库 / 官方库 / 项目已有依赖**无法满足**，才考虑新增第三方库
- [ ] 新增第三方库**已向用户说明理由并获明确同意**（或用户主动点名）
- [ ] 已通过**官方渠道**（命令或官方网站）查询最新版本，**未**凭记忆填写
- [ ] 已确认选用的是**最新稳定版**或**最新 LTS**（依据该依赖是否有 LTS 概念）
- [ ] **不是** alpha / beta / rc / nightly / preview / snapshot 预发布版本
- [ ] 若锁定到非最新版本，**已在 PR / commit message 中写明原因和回滚条件**
- [ ] 多依赖批量变更时，已列出版本变更清单与影响面评估
