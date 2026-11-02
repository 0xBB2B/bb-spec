---
name: 02-docs-and-git-push
description: git-push 改成前台循环等 ocr，插件说明和 README 写上新钩子
---
# git-push 等待方式和说明同步

## 目标
`/git-push` 等 ocr 审查时不提前结束回合；所有说明里的钩子数量和实际一致。

## 业务规则（来源：PRD 01-wait-background-scripts）
- `/git-push` 启动 ocr 审查后，用前台循环等待它结束，每次前台调用最多等 2 分钟，不靠结束回合等完成通知。一次审查可能超过 10 分钟，所以仍用后台方式启动。
- `plugin.json`、`marketplace.json` 对 bb-spec-core 的说明和五份 README 的钩子表都写上 `background-script-wait`，钩子数量和实际一致：bb-spec-core 3 个，全部插件共 4 个。
- README 的“4 个被动 hook”列表里，“Stop 四项自检”这一项已经没有对应的钩子，换成新钩子，保持数量正确。

## 涉及文件
- `plugins/bb-spec-workflow/skills/git-push/SKILL.md`（修改第 83 行）
- `plugins/bb-spec-core/.claude-plugin/plugin.json`（修改说明）
- `.claude-plugin/marketplace.json`（修改 bb-spec-core 说明）
- `README.md`、`README.en.md`、`README.ja.md`、`README.ko.md`、`README.zh-TW.md`（修改）
- `tests/background-script-wait.test.sh`（修改，补文档检查）

## 成品定义

`plugins/bb-spec-workflow/skills/git-push/SKILL.md` 第 83 行改成：

```markdown
- 用 Bash 的 `run_in_background` 运行，再用前台 Bash 循环等它结束，每次前台调用最多等 2 分钟，没结束就再等一次：一次审查可能超过 10 分钟，直接前台运行会被超时掐断
```

`plugin.json` 的 `description`：

```text
BB-Spec 核心纪律：TDD 红绿重构、依赖版本策略、Git 分支与提交纪律；含 git-workflow-guard / dep-version-check / background-script-wait 三个被动 hook，是其余子套件的推荐基座。
```

`marketplace.json` 中 bb-spec-core 的 `description`：

```text
BB-Spec 核心纪律（推荐基座）：TDD 红绿重构、依赖版本策略、Git 分支与提交纪律；含 git-workflow-guard / dep-version-check / background-script-wait 三个被动 hook。
```

`README.md` 钩子表在 `dep-version-check` 一行后加：

```markdown
| `background-script-wait` | bb-spec-core | Stop | 发现本会话没提示过的运行中后台命令时提示一次:Claude 用前台循环等完会结束的脚本,常驻服务不等 |
```

`README.md` 第 146 行的最后一项改成 `等后台脚本跑完`。

## 函数清单
无代码函数，只改文档和说明。其他语言的 README 按对应语言翻译同样的两处改动，半角标点和各文件现有写法一致。

## 协作关系
说明文字只描述 `01-stop-hook` 交付的钩子，不影响运行。

## 验证方式
- 测试入口：`bash tests/background-script-wait.test.sh` 和 `bash tests/validate.sh`。
- 测试输入：仓库里的上述文件。
- 预期结果：
- [ ] `git-push/SKILL.md` 含“每次前台调用最多等 2 分钟”，不含“等完成通知”。
- [ ] `plugin.json`、`marketplace.json` 含 `background-script-wait` 和“三个被动 hook”，不含“两个被动 hook”。
- [ ] 五份 README 的钩子表都有 `background-script-wait` 一行。
- [ ] 五份 README 都不含 `Stop 四项自检` 及其译文。
- [ ] `tests/validate.sh` 通过，版本同步等既有检查不受影响。

## 整体验收（代码完成后由执行者实际操作）
1. 用隔离的 tmux 服务器启动 `claude --plugin-dir plugins/bb-spec-core`，让 Claude 后台启动约 45 秒的脚本和一个常驻服务 → 屏幕显示 “Stop hook feedback” 提示，和确认过的预览一致。
2. 观察 → Claude 等完脚本才汇报，服务保持运行，下一条消息不再提示。
3. 前台等待期间发一条消息 → 约 2 分钟内得到回复。
4. 真实 Vibe42 里不弹“回合完成”这一项交给用户人工确认。
