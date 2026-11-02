---
name: 02-prototype-skill
description: 新增 /prototype，把原型做法和界面对比规则收进一处，/prd、/revise、/exec 改成调用它
---
# /prototype

## 目标

原型的做法和界面对比规则只写在 `/prototype` 一处，用户能单独运行它，`/prd`、`/revise`、`/exec` 都调用它。

## 业务规则（来源：PRD 02-prototype-skill）

"外壳"是随插件发布的 `templates/ui-preview-shell.html`；"框"是外壳中间显示正式页面的区域，只有框里的内容要做进产品。

- `/prototype` 能直接运行，也能被 `/prd`、`/revise`、`/exec` 调用。
- 规则写明：什么算界面、复制外壳、只改填写区、三类内容各放哪里、各种状态、终端写法、多方案、打开文件、改到用户说"可以"。
- 项目有自己的设计时，读项目现有样式后写进 `css` 照实还原；没有时不写 `css`，用默认页面样式。
- 单独运行时不写 PRD、不改产品代码，用户确认后告诉用户文件路径并结束；文件存到缓存目录的 `ui-preview/<YYYY-MM-DD>.<主题>.html`，不是 bb-spec 项目时存到会话临时目录。调用方可以指定文件路径。
- `/prd` 的界面预览只写什么时候出原型和文件名规则；`/revise` 同样，文件名是 `revise-<YYYY-MM-DD>-<主题>.html`。两者都不写做法细节。
- 把确认过的原型写进约束或作为期望行为时，只取框里的内容，外壳不写成产品功能。
- 对比模式：把实际界面跑起来，和原型框里的内容逐项对比布局、文案、每种状态、每个交互操作后的结果。外壳不参与对比；「只在原型里成立」写明的假数据和假操作，与实际界面不同不算不一致。返回一致、不一致（逐条写原型里是什么、实际是什么）、没跑起来（写清卡在哪）；截图放缓存目录的 `ui-compare/`。
- `/exec`、`/revise` 调用对比模式，只写拿到结果后怎么处理。

## 涉及文件

- `plugins/bb-spec-workflow/skills/prototype/SKILL.md`（新建）
- `plugins/bb-spec-workflow/skills/prd/SKILL.md`（修改）
- `plugins/bb-spec-workflow/skills/revise/SKILL.md`（修改）
- `plugins/bb-spec-workflow/skills/exec/SKILL.md`（修改）
- `tests/ui-preview-rules.test.sh`（修改）

## 成品定义

### plugins/bb-spec-workflow/skills/prototype/SKILL.md

原样落盘：

````markdown
---
name: prototype
description: 界面原型的唯一规程——用统一的蓝图外壳出 HTML 原型：左栏放切换、中间的框只放正式页面、底部放说明，多方案放同一份原型切换，改到用户明确说"可以"；也负责做完后拿实际界面和原型对比。触发：/prototype、做个原型、出个界面预览；/prd、/revise 要出原型时调用；/exec、/revise 收尾时用 --compare 调用。跳过：改动不影响用户看到的界面。
argument-hint: <主题> [--file <原型文件路径>] | --compare <原型文件路径>
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/*)
---

# 界面原型

用统一的外壳出 HTML 原型给用户确认，做完后拿实际界面和原型对比。

下文的"外壳"是所有原型共用的外框，"框"是外壳中间显示正式页面的区域。只有框里的内容要做进产品。

## 两种模式

| 调用 | 模式 |
|---|---|
| `/prototype <主题>` | 单独出原型，用户确认后结束 |
| `<主题> --file <路径>` | 被 `/prd`、`/revise` 调用出原型，用户确认后回到调用方 |
| `--compare <路径>` | 拿实际界面和原型对比，返回结果给调用方 |

## 出原型

界面包括两类：

- 图形界面：网页、桌面或手机 App 的页面、组件、样式、布局、交互
- 终端界面：命令行输出的排版、颜色、表格、进度条、交互提示

改动再小（只换一个按钮文字、一个颜色值）也要出原型。

1. 确定文件位置。调用方给了 `--file` 就用它。没给时运行 `${CLAUDE_PLUGIN_ROOT}/scripts/bbspec-paths.sh` 取 `cache_dir`，文件是 `${CACHE_DIR}/ui-preview/<YYYY-MM-DD>.<主题>.html`（主题 kebab-case）；项目没有 `.bb-spec/` 和 `.bb-spec.yaml` 时放会话临时目录。放在 `${CACHE_DIR}` 下时，写入前确保 `${CACHE_DIR}/.gitignore` 存在：不存在就连目录一起创建，内容写单行 `*`，把整个缓存目录排除出 git
2. 把 `${CLAUDE_PLUGIN_ROOT}/templates/ui-preview-shell.html` 复制到这个位置
3. 只改文件里 `PROTOTYPE-START` 到 `PROTOTYPE-END` 之间的填写区，格式按那里的说明写，外壳一律不改。正式页面只放进框里，框里禁止放说明或切换控件；说明写进 `note`（这个画面的说明）、`fake`（只在原型里成立）、`openQuestions`（还没确认的问题）
4. 判断页面样式。项目有自己的设计时，先读项目现有的样式文件和页面代码，把项目样式写进 `css`，照实还原；写了 `css` 后默认页面样式完全不生效。项目没有自己的设计时不写 `css`，直接用默认页面样式
5. 图形界面：还原布局、文案，画出正常、空数据、加载中、出错这几种状态，有交互的地方做成可点击的，框里的跳转用 `data-go`。终端界面：页面设 `terminal: true`，文字颜色用外壳提供的绿、黄、蓝、红，多步交互每一步写成一个状态，并设 `stateLabel: '步骤'`
6. 同一次设计有多个方案时，都放进同一份原型的 `schemes`，不拆成多个文件；用户选定方案后，把没选中的方案删掉，再请用户确认
7. 用 `open <文件路径>` 在浏览器里打开给用户看
8. 用户提了意见就先改原型，再请用户看，直到用户明确说"可以"

确认后：

- 单独运行：告诉用户文件路径，到此结束。不写 PRD，不改产品代码
- 被调用：回到调用方继续

## 对比（--compare）

把实际界面跑起来，和原型框里的内容逐项对比：布局、文案、每种状态、每个交互操作后的结果。外壳的左栏、框上方提示、底部说明不参与对比；「只在原型里成立」写明的假数据和假操作，与实际界面不同不算不一致。

网页或 App 打开对应页面截图；终端界面直接运行命令看输出；截图放 `${CACHE_DIR}/ui-compare/`。

只返回结果，后续怎么处理由调用方决定：

- 一致
- 不一致：逐条写原型里是什么、实际是什么，附截图路径
- 没跑起来：写清卡在哪（缺服务、缺账号等）
````

### prd/SKILL.md「界面预览」

把从 `**界面预览**：需求改变用户看到的界面时` 开始、到 `预览获用户确认后才进步骤 4。` 这一行之前的内容，整段换成：

```markdown
**界面预览**：需求改变用户看到的界面时，界面这个维度用原型来问，改动再小（只换一个按钮文字、一个颜色值）也要出。调用 `Skill bb-spec-workflow:prototype`，参数 `<主题> --file ${CACHE_DIR}/ui-preview/<YYYY-MM-DD>.<主题>.html`，文件名和步骤 7 的 PRD 目录名一致（`/exec` 收尾时按这个名字找到它，拿实际界面逐项对比）。
```

### revise/SKILL.md「界面预览」

把从 `**界面预览**：修复会改变用户看到的界面时` 开始、到 `确认过的原型里框中的内容就是这次的期望行为` 这一行之前的内容，整段换成：

```markdown
**界面预览**：修复会改变用户看到的界面时（改动再小，只换一个按钮文字、一个颜色值也算），进步骤 3 之前先出原型，用户明确说"可以"后再改代码。调用 `Skill bb-spec-workflow:prototype`，参数 `<主题> --file ${CACHE_DIR}/ui-preview/revise-<YYYY-MM-DD>-<主题>.html`（主题 kebab-case），原型画出修好之后的样子。
```

### revise/SKILL.md 界面对比

把 `3. **界面对比**：` 这一项开头到"截图放 `${CACHE_DIR}/ui-compare/`。"这部分换成：

```markdown
3. **界面对比**：出过界面预览时，调用 `Skill bb-spec-workflow:prototype`，参数 `--compare <预览页路径>`。
```

这一项后面"全部一致 → ……"的处理文字保留不动。

### exec/SKILL.md 界面对比

把这一句：

```markdown
这时把实际界面跑起来，和预览框里的内容逐项对比：布局、文案、每种状态（正常、空数据、加载中、出错）、每个交互操作后的结果。外壳的左栏、框上方提示、底部说明不参与对比；「只在原型里成立」写明的假数据和假操作，与实际界面不同不算不一致。网页或 App 打开对应页面截图；终端界面直接运行命令看输出；截图放 `${CACHE_DIR}/ui-compare/`。
```

换成：

```markdown
这时调用 `Skill bb-spec-workflow:prototype`，参数 `--compare <预览页路径>`，按返回结果处理：
```

## 函数清单

本 plan 只有规则文字和测试，没有新函数。

## 协作关系

`/prd`、`/revise` 调用 `/prototype` 出原型；`/exec`、`/revise` 调用 `/prototype --compare`；`/prototype` 复制 `templates/ui-preview-shell.html`。

## 验证方式

- 测试入口：`bash tests/ui-preview-rules.test.sh` 和 `bash tests/validate.sh`，退出码 0 为通过。`tests/ui-preview-rules.test.sh` 已存在，要按新规则更新。
- 测试输入：`plugins/bb-spec-workflow/skills/{prototype,prd,revise,exec}/SKILL.md`。
- 预期结果：
  - [ ] `prototype` 的 SKILL frontmatter 的 `name` 是 `prototype`，没有 `disable-model-invocation`（要能被其他 skill 调用）。
  - [ ] `prototype` 的 SKILL 含：`${CLAUDE_PLUGIN_ROOT}/templates/ui-preview-shell.html`、`PROTOTYPE-START`、`PROTOTYPE-END`、`外壳一律不改`、`框里禁止放说明或切换控件`、`` `note` ``、`` `fake` ``、`` `openQuestions` ``、`` `css` ``、`照实还原`、`默认页面样式`、`` `schemes` ``、`不拆成多个文件`、`把没选中的方案删掉`、`terminal: true`、`data-go`、`open <文件路径>`、`明确说"可以"`、`不写 PRD`、`--file`、`--compare`、`和原型框里的内容逐项对比`、`不参与对比`、`假数据和假操作`、`ui-compare/`、`没跑起来`。
  - [ ] `prd`、`revise` 的 SKILL 都含 `bb-spec-workflow:prototype`，并且都不含：`PROTOTYPE-START`、`terminal: true`、`把没选中的方案删掉`、`框里禁止放说明或切换控件`、`templates/ui-preview-shell.html`。
  - [ ] `prd` 含 `外壳不写成产品功能`，`revise` 含 `外壳不算`。
  - [ ] `exec`、`revise` 的 SKILL 都含 `--compare`，并且都不含 `不参与对比`、`假数据和假操作`。
  - [ ] `exec` 的 SKILL 保留 `全部一致`、`有不一致`、`实际界面跑不起来` 这三种处理。
  - [ ] `prototype` 引用的外壳文件存在。
  - [ ] `tests/validate.sh`：在仓库副本里删掉外壳文件时退出码非 0、输出含 `ui-preview-shell.html`；外壳文件写入 `/Users/someone/x` 时退出码非 0。
