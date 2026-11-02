---
name: 02-workflow-skill-rules
description: /prd、/revise 用外壳出原型，/exec、/revise 的界面对比只比框里的内容，校验脚本覆盖外壳
---
# 流程规则

## 目标

`/prd`、`/revise` 都用统一外壳出原型，界面对比只比框里的内容，结构校验能发现外壳文件丢失。

## 业务规则（来源：PRD 02-workflow-rules）

"外壳"是随插件发布的 `templates/ui-preview-shell.html`；"框"是外壳中间显示正式页面的区域，只有框里的内容要做进产品。

- `/prd`、`/revise` 的界面预览必须用外壳出原型，只往外壳里填内容，不改外壳本身。
- 正式页面只放进框里，说明写进底部三列，切换写进左栏；框里禁止放说明或切换控件。
- 同一次设计有多个方案时，放进同一份原型切换，不拆成多个文件。用户选定方案后，把没选中的方案删掉，再请用户确认。这样实现后对比时只有一个标准。
- 界面对比只比框里的内容；外壳的左栏、框上方提示、底部说明都不参与对比。
- 「只在原型里成立」里写明的假数据和假操作，与实际界面不同不算不一致。
- 把确认过的原型写进约束和验收时只写框里的内容，外壳不写成产品功能；`/revise` 把确认过的界面作为期望行为时同样如此。

## 涉及文件

- `plugins/bb-spec-workflow/skills/prd/SKILL.md`（修改）
- `plugins/bb-spec-workflow/skills/revise/SKILL.md`（修改）
- `plugins/bb-spec-workflow/skills/exec/SKILL.md`（修改）
- `tests/validate.sh`（修改）
- `tests/ui-preview-rules.test.sh`（新建）

## 成品定义

下面每处都是"原文 → 新文"，原样替换。

### prd/SKILL.md「界面预览」

把"做法："后面的 4 条列表换成：

```markdown
1. 把 `${CLAUDE_PLUGIN_ROOT}/templates/ui-preview-shell.html` 复制到 `${CACHE_DIR}/ui-preview/<YYYY-MM-DD>.<主题>.html`，文件名和步骤 7 的 PRD 目录名一致（`/exec` 收尾时按这个名字找到它，拿实际界面逐项对比）。写入前确保 `${CACHE_DIR}/.gitignore` 存在：不存在就连目录一起创建，内容写单行 `*`，把整个缓存目录排除出 git
2. 这个文件是统一的原型外壳：左栏放切换，中间的框放正式页面，底部放说明，只有框里的内容要做进产品。只改文件里 `PROTOTYPE-START` 到 `PROTOTYPE-END` 之间的填写区，格式按那里的说明写，外壳一律不改。正式页面只放进框里，框里禁止放说明或切换控件；说明写进 `note`（这个画面的说明）、`fake`（只在原型里成立）、`openQuestions`（还没确认的问题）
3. 图形界面：还原布局、配色、文案，画出正常、空数据、加载中、出错这几种状态，有交互的地方做成可点击的，框里的跳转用 `data-go`。终端界面：页面设 `terminal: true`，颜色按实际效果还原，多步交互每一步写成一个状态，并设 `stateLabel: '步骤'`
4. 同一次设计有多个方案时，都放进同一份原型的 `schemes`，不拆成多个文件；用户选定方案后，把没选中的方案删掉，再请用户确认
5. 用 `open <文件路径>` 在浏览器里打开给用户看
6. 用户提了意见就先改预览页，再请用户看，直到用户明确说"可以"
```

### prd/SKILL.md 步骤 4

原文：

```markdown
- 需求涉及界面时，把确认过的预览写成约束和验收：每块界面的布局和文案、每种状态（正常、空数据、加载中、出错）下用户看到什么、每个交互操作后发生什么
```

新文：

```markdown
- 需求涉及界面时，把确认过的预览里框中的内容写成约束和验收，外壳不写成产品功能：每块界面的布局和文案、每种状态（正常、空数据、加载中、出错）下用户看到什么、每个交互操作后发生什么
```

### revise/SKILL.md「界面预览」

把"做法："后面的 4 条列表换成：

```markdown
1. 把 `${CLAUDE_PLUGIN_ROOT}/templates/ui-preview-shell.html` 复制到 `${CACHE_DIR}/ui-preview/revise-<YYYY-MM-DD>-<主题>.html`（主题 kebab-case）。写入前确保 `${CACHE_DIR}/.gitignore` 存在：不存在就连目录一起创建，内容写单行 `*`，把整个缓存目录排除出 git
2. 这个文件是统一的原型外壳：左栏放切换，中间的框放正式页面，底部放说明，只有框里的内容要做进产品。只改文件里 `PROTOTYPE-START` 到 `PROTOTYPE-END` 之间的填写区，格式按那里的说明写，外壳一律不改。正式页面只放进框里，框里禁止放说明或切换控件；说明写进 `note`（这个画面的说明）、`fake`（只在原型里成立）、`openQuestions`（还没确认的问题）
3. 画出修好之后的样子。图形界面：还原布局、配色、文案，画出正常、空数据、加载中、出错这几种状态，有交互的地方做成可点击的，框里的跳转用 `data-go`。终端界面：页面设 `terminal: true`，颜色按实际效果还原，多步交互每一步写成一个状态，并设 `stateLabel: '步骤'`
4. 同一次修复有多个方案时，都放进同一份原型的 `schemes`，不拆成多个文件；用户选定方案后，把没选中的方案删掉，再请用户确认
5. 用 `open <文件路径>` 在浏览器里打开给用户看
6. 用户提了意见就先改预览页，再请用户看，直到用户明确说"可以"
```

### revise/SKILL.md 期望行为

原文：

```markdown
确认过的界面就是这次的期望行为：要改本分支 PRD 时（3a、3c）写进它的约束和验收，PRD 里不写预览页路径；派 test-engineer、prd-reviewer 时把它作为期望行为传过去。
```

新文：

```markdown
确认过的原型里框中的内容就是这次的期望行为，外壳不算：要改本分支 PRD 时（3a、3c）写进它的约束和验收，PRD 里不写预览页路径；派 test-engineer、prd-reviewer 时把它作为期望行为传过去。
```

### revise/SKILL.md 界面对比

把这一句：

```markdown
出过界面预览时，把实际界面跑起来和预览逐项对比：布局、文案、每种状态、每个交互操作后的结果。
```

换成：

```markdown
出过界面预览时，把实际界面跑起来，和预览框里的内容逐项对比：布局、文案、每种状态、每个交互操作后的结果。外壳的左栏、框上方提示、底部说明不参与对比；「只在原型里成立」写明的假数据和假操作，与实际界面不同不算不一致。
```

### exec/SKILL.md 界面对比

把这一句：

```markdown
这时把实际界面跑起来，和预览逐项对比：布局、文案、每种状态（正常、空数据、加载中、出错）、每个交互操作后的结果。
```

换成：

```markdown
这时把实际界面跑起来，和预览框里的内容逐项对比：布局、文案、每种状态（正常、空数据、加载中、出错）、每个交互操作后的结果。外壳的左栏、框上方提示、底部说明不参与对比；「只在原型里成立」写明的假数据和假操作，与实际界面不同不算不一致。
```

### tests/validate.sh

在 `=== 路径泄露检测 ===` 这一段之前加一段检查：skill 里每个 `${CLAUDE_PLUGIN_ROOT}/templates/<文件>` 引用都要指向存在的文件，缺失时 `fail` 并写出引用它的 skill 和文件名。路径泄露检测的 `grep` 增加 `--include='*.html'`，让外壳文件也被检查到。

## 函数清单

本 plan 只改规则文字和校验脚本里的一段检查，没有新函数。

## 协作关系

`/prd`、`/revise` 复制外壳文件；`/exec`、`/revise` 按外壳的分区做界面对比；`tests/validate.sh` 检查外壳文件存在。

## 验证方式

- 测试入口：`bash tests/validate.sh`（退出码 0 为通过）和 `bash tests/ui-preview-rules.test.sh`（新建，CI 的 `tests/*.sh` 循环自动执行）。
- 测试输入：仓库里的 `plugins/bb-spec-workflow/skills/{prd,revise,exec}/SKILL.md`；`validate.sh` 的 `ROOT` 由脚本位置推出，可复制到临时目录后删掉外壳文件来测缺失场景。
- 预期结果：
  - [ ] `prd`、`revise` 的 SKILL 都含 `${CLAUDE_PLUGIN_ROOT}/templates/ui-preview-shell.html`、`PROTOTYPE-START`、`框里禁止放说明或切换控件`、`` `schemes` ``、`不拆成多个文件`、`把没选中的方案删掉`、`terminal: true`、`data-go`。
  - [ ] `prd` 的 SKILL 含 `外壳不写成产品功能`；`revise` 的 SKILL 含 `外壳不算`。
  - [ ] `exec`、`revise` 的 SKILL 都含 `和预览框里的内容逐项对比`、`不参与对比`、`假数据和假操作`。
  - [ ] `prd`、`revise` 的 SKILL 不再含 `CSS 和 JS 都写在文件里`（外壳已包含，这句话过期）。
  - [ ] 外壳文件存在时 `tests/validate.sh` 全部通过；外壳文件被删掉时 `tests/validate.sh` 退出码非 0，输出里有 `ui-preview-shell.html`。
  - [ ] 外壳文件里写入 `/Users/` 这样的个人路径时，`tests/validate.sh` 退出码非 0。
