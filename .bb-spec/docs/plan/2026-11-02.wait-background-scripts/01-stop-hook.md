---
name: 01-stop-hook
description: 新增 Stop 钩子：发现新的运行中后台命令就提示一次，其余情况一律放行
---
# 后台脚本等待钩子

## 目标
Claude 准备结束回合时，如果有本会话没提示过的运行中后台命令，钩子提示一次，让 Claude 等完脚本、放过常驻服务。

## 业务规则（来源：PRD 01-wait-background-scripts）
- 回合结束时，后台任务里类型为 `shell`、状态为 `running`、本会话没提示过的命令算“新命令”。有新命令 → 输出一次提示，Claude 继续工作。
- 提示必须走 `hookSpecificOutput.additionalContext`，`hookEventName` 为 `Stop`，不用 `decision: block`。实测后者在屏幕上显示 “Stop hook error”。
- 已提示过的编号不再提示；新旧混合时只列新的，并把新的也记下；不同会话的记录互不影响。
- 空列表、字段缺失、非 `shell` 类型、状态不是 `running` → 不输出，放行。
- 命令超过 80 个字符显示前 80 个字符加 `…`，正好 80 个字符完整显示。命令里的换行显示成空格，先换空格再截断。
- 没有 `jq`、输入不是合法 JSON、缺会话编号、会话编号带路径分隔符或 `..` → 不输出，退出码 0。
- 记录写不进去 → 不输出，退出码 0，避免同一条命令每个回合都被提示。先写记录，写成功才输出提示。
- 记录放在 `${CLAUDE_PLUGIN_DATA}` 下，不写进用户项目目录。这个变量为空时按“记录写不进去”处理。
- 任何异常都不能让退出码非 0，也不能让回合卡住。
- 只注册 `Stop`，不注册 `SubagentStop`。

## 涉及文件
- `plugins/bb-spec-core/hooks/background-script-wait.sh`（新建，可执行）
- `plugins/bb-spec-core/hooks/hooks.json`（修改）
- `tests/background-script-wait.test.sh`（新建）

## 成品定义

`plugins/bb-spec-core/hooks/hooks.json` 改成下面的内容：

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/git-workflow-guard.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/dep-version-check.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/background-script-wait.sh"
          }
        ]
      }
    ]
  }
}
```

提示文本逐字如下，`<任务编号>: <命令>` 一条命令一行：

```text
后台命令还在运行：
- <任务编号>: <命令>
会自己结束的脚本（测试、构建、审查）：用前台 Bash 循环等它结束，每次最多等 2 分钟，没结束就再等一次，看完结果再结束回合。
常驻服务（dev server、watch、tail -f）：不用等。全部是常驻服务时，直接结束回合。
```

## 函数清单
### plugins/bb-spec-core/hooks/background-script-wait.sh
脚本从上到下顺序执行，风格和 `dep-version-check.sh` 一致：用 `jq` 解析，不定义多余函数。

| 步骤 | 职责 |
|---|---|
| 依赖和输入检查 | 没有 `jq`、输入非法、会话编号不合规时退出 0 |
| 筛选新命令 | 用 `jq` 读后台任务和已提示记录，得出新命令，全程在 `jq` 内比较编号，不让命令文字经过 shell |
| 写记录 | 把新编号写入本会话记录，失败时退出 0 |
| 输出提示 | 用 `jq` 拼出 JSON，格式化命令文字 |

## 协作关系
Claude Code 在回合结束时调用脚本，标准输入是 Stop JSON（`session_id`、`background_tasks`）。脚本依赖环境变量 `CLAUDE_PLUGIN_DATA` 和 `jq`。

## 验证方式
- 测试入口：`bash tests/background-script-wait.test.sh`，内部把 Stop JSON 通过标准输入传给 `plugins/bb-spec-core/hooks/background-script-wait.sh`。
- 测试输入：`CLAUDE_PLUGIN_DATA` 指向临时目录；`session_id` 和 `background_tasks` 按用例构造，每项含 `id`、`type`、`status`、`command`。
- 预期结果：
- [ ] 一条新命令：输出 JSON 的 `.hookSpecificOutput.hookEventName` 为 `Stop`，`.hookSpecificOutput.additionalContext` 和提示文本逐字一致，没有 `decision` 字段，退出码 0。
- [ ] 两条新命令：有两行 `- ` 列表。
- [ ] 同一会话、同一编号调用两次：第二次无输出。
- [ ] 先提示 A，再输入 A 和 B：只含 B；再输入一次：无输出。
- [ ] 会话 1 提示过 A，会话 2 输入 A：有输出。
- [ ] 空列表、缺 `background_tasks`、`subagent`、`monitor`、`status` 为 `completed`：无输出，退出码 0。
- [ ] 81 个字符的命令：前 80 个字符加 `…`；80 个字符：完整；`a\nb`：显示 `a b`。
- [ ] 命令里带 `$(touch x)` 这类文字：原样显示，不被执行。
- [ ] 非法 JSON、缺 `session_id`、`session_id` 为 `../x` 或 `a/b`：无输出，退出码 0，临时目录外没有新文件。
- [ ] `PATH` 里没有 `jq`：无输出，退出码 0。
- [ ] `CLAUDE_PLUGIN_DATA` 为空或指向不可写位置：无输出，退出码 0。
- [ ] 运行后当前工作目录没有新增文件。
- [ ] `hooks.json` 的 `Stop` 下有这个钩子，`SubagentStop` 下没有。
