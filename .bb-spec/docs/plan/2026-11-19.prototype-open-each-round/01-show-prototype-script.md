---
name: show-prototype-script
description: 新增 show-prototype.sh：在 Chrome/Safari 里找到原型标签页切过去刷新，找不到或出错时用 open 新开
---
# 展示原型的脚本

## 目标
主对话运行一条脚本就能展示原型：浏览器里已经开着这个原型文件时切过去并刷新，标签页数量不变；没开着或出错时新开一个标签页。

## 业务规则（来源：PRD open-each-round 约束 3、4，OVERVIEW 决策记录）
- 已经开着这个原型文件的标签页（Chrome 或 Safari）→ 把这个浏览器切到前台、把标签页所在窗口提到最前、切到这个标签页并刷新；这个文件的标签页数量不变。开着多个时只处理找到的第一个。
- Chrome 和 Safari 里都没有开着这个文件，或者查找、切换、刷新中任何一步出错（例如用户拒绝让终端控制浏览器、遍历时标签页正在新建或关闭导致"无效的索引"错误）→ 执行 `open <原型文件路径>` 新开 1 个标签页。出错不能让脚本以失败退出，主对话要照常往下走。
- 没在运行的浏览器不能被脚本启动：先判断 Chrome / Safari 是否在运行，只查在运行的那个。原因：AppleScript 里 `tell application "X"` 会把没开的浏览器启动起来。
- 先查 Chrome（用户默认浏览器），再查 Safari。
- 只支持 macOS：AppleScript 只在 macOS 上有；Windows、Linux 不处理。
- 实测依据：同一文件执行 3 次 `open`，Chrome 出现 3 个标签页；在 Chrome 里找到标签页后 `set active tab index` + `reload`，标签页仍是 1 个、内容变成新版本。
- 实测踩过的坑：同时开着两个 Chrome 实例（浏览器调试工具自己启动的那个）时，AppleScript 可能连到另一个实例而找不到标签页——按"找不到"处理，退回 `open`。

## 涉及文件
- `plugins/bb-spec-workflow/scripts/show-prototype.sh`（新建，可执行权限，`#!/usr/bin/env bash` + `set -euo pipefail`，风格同目录下 `bbspec-paths.sh`）
- `tests/show-prototype.test.sh`（新建）

## 新增技术
| 名称 | 类别 | 来源 | 用途 | 现有手段为什么不够 | 替代方案为什么不选 | 版本策略 |
|---|---|---|---|---|---|---|
| AppleScript（经 macOS 自带 `osascript` 运行） | 语言 | Claude 提议 | 在 Chrome、Safari 里找到原型文件的标签页、切过去并刷新 | 项目只用 `open`，实测同一文件 3 次 `open` 出现 3 个标签页，切不到已有标签页、也刷新不了 | Chrome 远程调试端口要求浏览器带特殊参数启动，用户平时的 Chrome 用不了；页面自检文件变化要改所有原型共用外壳，且本地文件页面一般读不到自身 | 用 macOS 系统自带版本，不安装、不锁版本 |

## 函数清单
### plugins/bb-spec-workflow/scripts/show-prototype.sh
| 函数名 | 职责 |
|---|---|
| `file_url` | 把原型文件转成浏览器里看到的地址：先取物理绝对路径（解开符号链接，如 `/tmp` → `/private/tmp`），再拼 `file://`，路径中除 `A-Z a-z 0-9 - . _ ~ /` 外的字节按 UTF-8 逐字节转成大写 `%XX` |
| `focus_and_reload` | 用 `osascript` 运行内联 AppleScript：按"先 Chrome 后 Safari、只查在运行的"顺序找地址完全相等的标签页，找到就切过去、刷新、把浏览器切到前台并输出 `reloaded`，找不到输出 `notfound`。Safari 切换用 `set current tab of <窗口> to <标签页>`，刷新用把标签页 URL 重新赋值为自身 |
| `main` | 校验参数和文件；调 `focus_and_reload`，结果是 `reloaded` 就输出 `reloaded`；其余情况（`notfound`、`osascript` 非 0 退出、输出别的内容）执行 `open <原型文件路径>` 并输出 `opened` |

## 协作关系
`main` → `file_url` → `focus_and_reload`（调用外部命令 `osascript`）→ 必要时调用外部命令 `open`。`osascript` 和 `open` 都按命令名调用（不写绝对路径），测试靠 PATH 换成假命令。文件地址作为 `osascript` 的最后一个参数传给 AppleScript（AppleScript 从 `on run argv` 取），不拼进脚本文本，避免路径里的引号破坏脚本。

## 验证方式
- 测试入口：`plugins/bb-spec-workflow/scripts/show-prototype.sh <原型文件路径>`
- 测试输入：临时目录里的 HTML 文件（含一个路径带空格和中文的，如 `<临时目录>/a b/原型.html`）；PATH 最前面放假的 `osascript`、`open`：假 `osascript` 把收到的全部参数逐行写进记录文件，然后按环境变量决定输出 `reloaded`、输出 `notfound`、或向 stderr 打一行错误并以 1 退出；假 `open` 把参数写进另一个记录文件
- 预期结果：
- [ ] 假 `osascript` 输出 `reloaded` → 脚本输出 `reloaded`、退出码 0，`open` 没被调用
- [ ] 假 `osascript` 输出 `notfound` → 脚本输出 `opened`、退出码 0，`open` 只被调用 1 次，参数是这个原型文件路径
- [ ] 假 `osascript` 以 1 退出 → 脚本输出 `opened`、退出码 0，`open` 被调用 1 次
- [ ] `osascript` 收到的最后一个参数是 `file://` 开头的物理绝对路径地址；路径带空格和中文时，空格是 `%20`，`原型` 是 `%E5%8E%9F%E5%9E%8B`
- [ ] 不带参数、或文件不存在 → 退出码非 0，stderr 有说明，`osascript` 和 `open` 都没被调用
- [ ] 脚本文本里查是否在运行的写法（`is running`）出现在 Chrome 和 Safari 两处，且 Chrome 在 Safari 之前
- [ ] 手动（macOS + Chrome）：先关掉测试文件的标签页，运行脚本 → 输出 `opened`，Chrome 新开 1 个；改文件内容后再运行 → 输出 `reloaded`，这个文件仍只有 1 个标签页、显示新内容
