---
name: 03-dep-hook-reminder
description: 依赖文件被改后，钩子提示里加一句：引入了没批准的新技术就撤回改动、先列清单请用户批准
---
# 依赖文件钩子补新技术提醒

## 目标
不走任何流程的普通对话里，Claude 一改依赖文件或配置文件，钩子就提醒它：引入了用户没批准的新技术，立刻撤回改动，先列清单请用户批准。

## 业务规则（来源：PRD 02-unlisted-tech-stop）
- 执行计划、修 bug、普通对话里，要用不在已批准清单里的新技术，Claude 先停下，逐项列出并弹窗请用户批准。
- 用户同意之前，不改依赖文件和配置文件（如 `go.mod`、`package.json`、`Dockerfile`、`compose.yaml`、`.github/workflows/*`），不写引入新技术的代码。
- 钩子在文件改完之后才运行，只能事后提醒：没批准就撤回，回到"先列清单、等批准"。
- 钩子现有行为不变：只对依赖文件、配置文件输出提示，其他文件静默；没有 `jq` 时静默退出 0。

- 第二轮补充：提示里任何"可以忽略"的说法只能管版本号那部分，新技术提醒不管改的是不是版本字段都要检查；新技术提醒要写全七项内容，并说明弹一次窗。
## 涉及文件
- `plugins/bb-spec-core/hooks/dep-version-check.sh` 修改
- `tests/dep-version-check.test.sh` 新建（Test Agent 写）

## 成品定义

`dep-version-check.sh` 第 2 行注释改为：

```bash
# PostToolUse/Write|Edit：命中"会钉死外部资产版本号"的文件时，注入版本号自检和新技术批准提示。
```

`MSG=$(printf '…' "$FILE")` 的格式串，在最后一句 `若仅改动非版本字段（脚本、依赖名、配置 key 等），请忽略本提示。` 之前插入一段（前后各用 `\n` 分隔）：

```
若本次改动引入了项目里原来没有的新技术，且它不在用户已批准的清单里，立刻撤回这次改动，先按 version-policy 的新技术清单逐项列出用途、现有手段为什么不够、替代方案为什么不选，请用户批准后再改。
```

### 第二轮补改（审查后，在第一轮改好的文件上继续改）

`MSG=$(printf '…' "$FILE")` 的格式串整体替换为下面这段（`%s` 是文件路径，换行用 `\n`，不得出现其他 `%`）：

```
依赖版本号自检（version-policy）：刚改动了 `%s`。\n① 版本号：若本次改动写入或更新了任何外部资产的版本号（npm/Go/PyPI/Cargo/Maven/Actions/容器镜像/IaC provider/Helm/CLI 等），请确认每个版本号都通过**官方渠道**查询过最新稳定版（npm view / go list -m -versions / pip index versions / cargo search / docker manifest 等），未凭训练记忆填写；只改了非版本字段（脚本、配置 key 等）时，这一条可以跳过。\n② 新技术：若本次改动引入了项目里原来没有的新技术（新的依赖、镜像、Action、安装新工具的命令等），且它不在用户已批准的清单里，立刻撤回这次改动，先按 version-policy 的新技术清单逐项写齐七项内容（名称、类别、来源、用途、现有手段为什么不够、替代方案为什么不选、版本策略），弹一次窗请用户批准后再改。这一条不管改的是不是版本字段都要检查。
```

## 函数清单
### plugins/bb-spec-core/hooks/dep-version-check.sh
| 函数名 | 职责 |
|---|---|
| 顶层脚本（无函数） | 按成品定义改注释和提示文字，匹配逻辑不动 |

## 协作关系
钩子由 `plugins/bb-spec-core/hooks/hooks.json` 的 PostToolUse（Write|Edit）注册，不改注册。

## 验证方式
- 测试入口：`bash tests/dep-version-check.test.sh`：用 `jq -nc` 造标准 PostToolUse 输入 JSON（`{"tool_name": "...", "tool_input": {"file_path": "..."}}`），通过 stdin 喂给 `bash plugins/bb-spec-core/hooks/dep-version-check.sh`，检查退出码和输出；沿用 `tests/background-script-wait.test.sh` 的 `pass` / `fail` 计数，最后打印"通过 X，失败 Y"，有失败时退出非 0
- 测试输入与预期结果：
- [ ] `tool_name=Edit`、`file_path=/p/package.json` → 退出 0；输出是合法 JSON，`.hookSpecificOutput.hookEventName` 为 `PostToolUse`，`.hookSpecificOutput.additionalContext` 含 `立刻撤回这次改动`、`新技术清单`、`请用户批准`、`官方渠道`
- [ ] `tool_name=Write`、`file_path=/p/Dockerfile` 和 `file_path=/p/.github/workflows/ci.yml` → 同上，`additionalContext` 含 `立刻撤回这次改动`
- [ ] `tool_name=Edit`、`file_path=/p/README.md` → 退出 0，输出为空
- [ ] `tool_name=Bash`、`file_path=/p/package.json` → 退出 0，输出为空
- [ ] `PATH` 里找不到 `jq`（用只含 `bash` 和基础命令、不含 `jq` 的临时目录作 `PATH`）时 → 退出 0，输出为空
- [ ] 第二轮：package.json 的 `additionalContext` 含 `七项内容`、`名称、类别、来源、用途、现有手段为什么不够、替代方案为什么不选、版本策略`、`弹一次窗`、`不管改的是不是版本字段都要检查`；不含 `请忽略本提示`
- [ ] 第二轮：Dockerfile 和 `.github/workflows/ci.yml` 的 `additionalContext` 同样含 `立刻撤回这次改动`、`新技术清单`、`请用户批准`、`官方渠道`；另测 `tool_name=Edit`、`file_path=/p/go.mod` 和 `file_path=/p/compose.yaml` 也输出含 `立刻撤回这次改动` 的提示
