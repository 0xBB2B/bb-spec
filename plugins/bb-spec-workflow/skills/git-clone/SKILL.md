---
name: git-clone
description: 把一个或多个远程仓库 clone 到本地并落 .bb-spec.yaml——先 AskUserQuestion 询问「单 repo 还是多 repo 工作区」+「base_dir 用默认还是自定义」；多 repo 模式建统一父目录 + 各成员独立 clone（不嵌套）+ 可选生成 workspace 根文件；落盘后写入 .bb-spec.yaml（base_dir 字段）。触发：clone 一下、把项目拉下来、初始化本地副本、新机器拉代码、接入 bb-spec 工作流。跳过：仓库已存在于目标路径（应走 git pull / 重置而非重新 clone）、纯私有 fork 临时实验（用裸 git clone 更轻）。
---

# Git Clone 与项目初始化

把远程仓库拉到本地，并按「单 repo / 多 repo 工作区」摆好目录结构，写入 `.bb-spec.yaml`，让后续所有 bb-spec skill（`/spec` / `/plan` / `/exec` / `/git-push` …）能直接使用。

**职责边界**：只解决「拿代码 + 写 base_dir」。技术栈识别交给各 constraints skill；本 skill 不触发它们、不读代码、不装依赖。

## 参数

```
/git-clone <url> [<url> ...] [target=<本地路径>]
```

- 无 `<url>`：用 AskUserQuestion 问用户要远程地址（支持一次贴多条）
- 无 `target=`：默认落到 `$PWD/<repo-name>`（单 repo）或 `$PWD/<project-name>`（多 repo 父目录）

---

## 1. 询问项目模式

无论 URL 数量，**都要明确询问一次**，避免「贴了 2 个 URL 就默认多 repo」的误判（用户可能只是想顺序 clone 两个无关单仓）：

用 **AskUserQuestion** 让用户选：

- **单 repo（默认）**：每个 URL 独立 clone 到各自目录，互不关联。
- **多 repo 工作区**：所有 URL 是同一项目的成员仓库（典型场景：`go.work` / `pnpm-workspace.yaml` / Cargo workspace / Gradle composite）；建一个统一父目录把它们摆在同一层，复原构建工具期待的相对路径。

URL 只 1 个时只展示「单 repo」选项 + 提示「如果这是多 repo 工作区的第一个成员，可改用多 repo 模式并补齐其余 URL」。

## 2. 询问 base_dir

用 **AskUserQuestion** 让用户选 `.bb-spec.yaml` 的 `base_dir`：

- **`.bb-spec`（默认）**：交付物落 `.bb-spec/docs/{prd,spec,plan,test}/`，瞬态产物落 `.bb-spec/.cache/`。绝大多数项目用这个。
- **`./`（项目根）**：交付物直接落项目根的 `docs/` 与 `.cache/`，适合已有 `docs/` 习惯的项目。
- **自定义路径**：让用户输入一个相对路径（如 `my/bb`），落 `<base_dir>/docs/` 与 `<base_dir>/.cache/`。

> **不必询问其它项**：基线分支、PR 平台、测试入口、包管理器等——后续各 skill 都能自动探测或按需问，git-clone 不重复劳动。

## 3. 执行 clone

### 单 repo 模式

```bash
git clone <url> <target>
```

- `<target>` 已存在且非空 → **停下报告**，让用户决定是删、是 pull 还是换路径；禁静默覆盖。
- 多个 URL：每个独立 clone 到 `$PWD/<repo-name>`，逐个执行；任一失败停下报告（已成功的不回滚）。

### 多 repo 工作区模式

```bash
mkdir -p <project-parent>             # 统一父目录（普通目录、非 git repo）
git -C <project-parent> clone <url-1>  # → <project-parent>/<repo-1>/
git -C <project-parent> clone <url-2>  # → <project-parent>/<repo-2>/
...
```

- `<project-parent>` 已存在且非空 → 停下报告。
- 成员目录命名沿用 git clone 默认（URL 最后一段）；若用户希望自定义需在 URL 后用 `<url> <dirname>` 语法显式给出。
- **不替用户生成 `go.work` / `pnpm-workspace.yaml` 等 workspace 根文件**——这些文件的字段与构建工具强耦合，且远程仓库通常已经带模板。clone 完成后用 AskUserQuestion 询问「是否要从某个成员仓库拷一份 workspace 根文件到父目录」，给出探测到的候选（按文件存在性列出），用户选「不用」即跳过。

## 4. 写入 `.bb-spec.yaml`

落点：

- 单 repo：写入 `<target>/.bb-spec.yaml`（每个 repo 各一份）
- 多 repo：写入 `<project-parent>/.bb-spec.yaml`（父目录一份，所有成员共享；后续 bb-spec skill 从 cwd 向上找）

内容（仅 `base_dir` 一个字段，其余靠默认/探测）：

```yaml
# bb-spec 工作根目录
# {base_dir}/docs/   —— spec / plan / prd / test 交付物（随仓库提交）
# {base_dir}/.cache/ —— 运行时瞬态产物（自动 gitignore）
base_dir: <用户在步骤 2 选的值>
```

- 用户选默认 `.bb-spec` 时，**仍然显式写入文件**（不省略），让后续 skill 不必区分「文件不存在 vs base_dir 等于默认」，也让用户后续修改有迹可循。
- 目标路径已存在 `.bb-spec.yaml` → 用 AskUserQuestion 让用户选 `保留现有 / 覆盖 / 跳过本步`。

## 5. 完成简报

```
## /git-clone 完成简报

- 模式：单 repo / 多 repo 工作区
- 父目录：<path>（仅多 repo）
- 已 clone：
  - <repo-1>: <local-path>（默认分支 <branch>，<n> commits）
  - <repo-2>: ...
- base_dir：<value>（已写入 <.bb-spec.yaml 路径>）
- workspace 根文件：已拷 <file> / 跳过 / 不适用
- 下一步建议：
  - cd <落点> 开始工作
  - 新需求开工 → /spec（存量项目同样从下一个需求接入）
```

---

## 禁止操作

- 静默覆盖已存在的目录或 `.bb-spec.yaml`
- 自动生成 workspace 根文件（必须先问用户）
- 在 `~/.bb-spec/worktrees/` 下 clone——那里是 worktree 专用，普通 clone 落 `$PWD` 或用户指定路径
- 自动装依赖 / 跑测试——这些超出本 skill 职责
