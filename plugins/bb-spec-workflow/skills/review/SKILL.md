---
name: review
description: 本地 ultrareview——跨模型、多代理、对抗验证、只读的 PR 级 review（依赖 Workflow 工具，Claude Code ≥2.1.154）；第一参数指定待审分支（默认当前分支），对比基线固定 main（无则 master）；diff 按 ≤1500 行分片，每片并发 6 个 finder（质量/安全/简洁/鲁棒性/文档同步/Codex 跨模型），每条 🔴/🟡 发现交 3 个独立怀疑视角对抗验证、多数决去留，确认项再做同类扫描把兄弟位点并入一项、一次修一类；修复闭环后对修复 diff 自动复审一轮；报告落盘 .cache/review 并注入下一轮识别复发/已否决；可选追加本次 review 重点。触发：/review、给当前或指定分支做深度审查、PR 前 ultrareview。跳过：无 Workflow 工具、不在 git 仓库、待审分支=基线分支。
argument-hint: [branch] [本次 review 重点...]
disable-model-invocation: true
---

# 本地 ultrareview

跨模型、多代理、对抗验证、只读的 PR 级 review 协调者。

**核心原则**：跨模型独立 / prompt 自包含 / 只读不写 / 发现者与验证者隔离 / 基于 `file:line` 事实 / 一次修一类。

---

## 1. 输入与前置检查

`$ARGUMENTS` 形如 `[branch] [本次 review 重点...]`，两段都可选：

- 拿到 `$ARGUMENTS` 后按空白切成 tokens；为空则 branch 走默认、focus 为空
- 第一个 token 用 `git rev-parse --verify --quiet <token>` 探测：
  - 成功 → 该 token 当 branch（**待审分支**），剩余 tokens 用空格拼回当 focus（**本次 review 重点**，自然语言）
  - 失败 → branch 走默认，**全部** tokens 拼回当 focus
- branch 默认：当前分支
- base（对比基线）固定：`main`，不存在则 `master`，再不存在则提示用户

> 例：`/review 关注鉴权和密钥落盘` → branch=当前分支，focus=`关注鉴权和密钥落盘`；`/review feat/login 性能` → branch=feat/login，focus=`性能`；`/review` → branch=当前分支，focus 空。

前置检查：

- 确认 git 仓库 / branch ≠ base / branch 与 base 均存在 / 未提交改动仅警告不中止
- **Workflow 工具**：本 skill 依赖 Workflow 工具（Claude Code ≥ 2.1.154）。当前环境工具列表中没有 Workflow → **中止**，提示用户升级 Claude Code,不降级执行
- **Codex 探测**：`which codex` 失败 → finder 缩为 5 个（去掉 Codex），报告中说明
- 记下 `HEAD0 = git rev-parse <branch>`，修复复审（§4）以它为增量起点

回显：`review 范围：<base>..<branch> | commits：N | diff：M 文件 +L1/-L2 | 分片：K 片 | 重点：<focus 或「未指定」> | 上轮对照：<report 文件名 或「无」>`

### 分片

finder 单次输出有限，通读全量 diff 时写出十来条就会停笔，条数反映的是输出预算而非缺陷存量。分片让每个 finder 只对一段读得完的范围负责：

- `git diff --numstat <base>...<branch>` 取每文件改动行数（增删之和），按所在目录归组
- 贪心装箱：每片 **≤ 1500 行且 ≤ 15 文件**；同目录文件尽量同片（finder 需要看到模块内的调用关系）；单文件超过 1500 行独占一片
- 总量不超阈值则只有 1 片

每片记录：序号 `i/K`、文件清单（`path +a/-b`）、行数合计。

### 上轮对照（history）

report 目录：`<base_dir>/.cache/review/<branch>/`（`base_dir` 取 `.bb-spec.yaml` 的 `base_dir`，缺省 `.bb-spec`；branch 中的 `/` 替换为 `__`）。写入前确认 `<base_dir>/.cache/.gitignore` 存在且内容为单行 `*`，不存在则连目录一并创建。

取该目录下文件名最大的一份 report 作为上轮；不存在则 history 为空。从上轮 report 抽三份清单：

- **已修复**：上轮确认且状态为「已修」的项（标题 + 位置 + 修复 commit）——finder 再次命中同位置或同类时照常报出，并在 title 前加 `♻️`
- **已否决**：上轮否决项（标题 + 位置 + 关键理由）——无新证据不重报；有新证据必须在 fact 里写明新证据是什么
- **未处理 NIT**：上轮 NIT 中状态为「未处理」的项——照常报出，不需重复论证

history 为空时填「无上轮记录」。

### 修复主题摘要（≤ 300 字）

从 commit messages + CLAUDE.md 提取"想解决什么 / 修复策略 / 关键约束"，注入每个 finder prompt。

### 本次 review 重点（focus）

focus 是**用户希望优先关注的方向**（如"鉴权链路"/"新加的限流"/"重构后的事务边界"），不是"只看这块"——其他维度发现仍应照常报出，但凡命中 focus 的发现在 finder 内部应优先排序、严重度判定可酌情偏严。focus 为空时显式写「本次未指定，按各 finder 默认维度全面审视」。

---

## 2. 组装 finder

finder = **维度 × 分片**：每个维度对每一片各派一个 agent。每个 finder prompt 由对应定义文件（插件根目录 `agents/`）+ 本次 review 上下文组合而成。派工前用 Read 读取 agent 定义，填充模板变量：

- `{review_scope}`：`<base>..<branch>` + 本片序号 `i/K` + 本片文件清单（`path +a/-b`）+ 一句范围纪律：「本片每个文件都必须读完再收工；本片外的文件只作上下文查阅，不在本片报出」
- `{topic_summary}` / `{constraints}` / `{focus}`：全片相同；`{focus}` 为空时填入「本次未指定，按默认维度全面审视」
- `{history}`：§1 的三份清单；为空时填「无上轮记录」

| key | 图标 | 定义文件 | agentType |
|---|---|---|---|
| quality | 📐 | `agents/review-code-quality.md` | （默认） |
| security | 🛡️ | `agents/review-security.md` | （默认） |
| simplicity | 🧹 | `agents/review-simplicity.md` | （默认） |
| robustness | 🪨 | `agents/review-robustness.md` | （默认） |
| doc-sync | 📄 | `agents/review-doc-sync.md` | （默认） |
| codex | 🤖 | `agents/review-codex.md` | `codex:codex-rescue` |

图标是 finder 在最终报告中的身份标识（报告表格 by 列写图标 + 文字名，如 `📐质量`，多个 finder 空格分隔）；刻意用物体类 emoji，与严重度的 🔴🟡🟢 圆点在视觉上分属两类，避免混淆。

构造 `finders` 数组：`[{key, slice, prompt, agentType?}, ...]`（Codex 不可用则不含 codex 项）。

---

## 3. Workflow 编排

调用 Workflow 工具，**不使用 `args` 传参**（大对象经 args 易被序列化成字符串导致脚本取不到字段），把数据直接内嵌进脚本：将模板顶部的 `FINDERS` 替换为组装好的 finders 数组、`CONTEXT` 替换为一段自包含的 review 上下文文本（范围 `<base>..<branch>`、主题摘要、约束清单、**本次重点 focus**——为空时写「本次未指定」）、`CHANGED_FILES_CMD` 替换为实际的 `git diff --name-only <base>...<branch>`。内嵌长文本用模板字符串时注意转义内容中的 `` ` `` 与 `${`。`script` 用下面模板：

```js
export const meta = {
  name: 'local-ultrareview',
  description: '分片多维 finder 并行审查 + 逐条对抗验证 + 确认项同类扫描的本地 review',
  phases: [
    { title: 'Find', detail: '维度 × 分片 finder 并行审查' },
    { title: 'Verify', detail: '每条 🔴/🟡 × 3 个独立怀疑视角对抗验证' },
    { title: 'Sweep', detail: '每条确认项扫描同类兄弟位点并合并' },
  ],
}

// ===== review 输入（派工前由协调者填充，禁用 args 传参） =====
const FINDERS = [/* {key, slice, prompt, agentType?}, ... */]
const CONTEXT = `/* 自包含 review 上下文：范围、主题摘要、约束清单、本次重点 */`
const CHANGED_FILES_CMD = 'git diff --name-only <base>...<branch>'

// finder 的结构化发现 schema
const FINDINGS = {
  type: 'object', required: ['findings'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['title', 'file', 'lines', 'severity', 'fact', 'impact', 'suggestion'],
        properties: {
          title: { type: 'string', description: '命中上轮已修复项时以 ♻️ 开头' },
          file: { type: 'string', description: '相对仓库根的文件路径' },
          lines: { type: 'string', description: '行号或区间，如 "12" / "12-34"' },
          severity: { type: 'string', enum: ['BLOCKER', 'IMPORTANT', 'NIT'] },
          fact: { type: 'string', description: '3-5 行事实描述' },
          impact: { type: 'string', description: '正确性/安全/可维护性/可读性影响' },
          suggestion: { type: 'string', description: '≤3 行修复建议' },
        },
      },
    },
  },
}

// 验证者的裁决 schema
const VERDICT = {
  type: 'object', required: ['valid', 'reason'],
  properties: {
    valid: { type: 'boolean', description: '该发现在本仲裁视角下是否站得住脚' },
    reason: { type: 'string', description: '一句话裁决理由' },
  },
}

// 同类扫描的兄弟位点 schema
const SIBLINGS = {
  type: 'object', required: ['siblings'],
  properties: {
    siblings: {
      type: 'array',
      items: {
        type: 'object', required: ['file', 'lines', 'note'],
        properties: {
          file: { type: 'string', description: '相对仓库根的文件路径' },
          lines: { type: 'string', description: '行号或区间' },
          note: { type: 'string', description: '一句话：为何与主位点同类' },
        },
      },
    },
  },
}

function span(lines) {
  const m = String(lines).match(/(\d+)\D*(\d+)?/)
  const a = m ? +m[1] : 0
  return [a, m && m[2] ? +m[2] : a]
}
function overlap(a, b) {
  if (a.file !== b.file) return false
  const [s1, e1] = span(a.lines), [s2, e2] = span(b.lines)
  return s1 <= e2 && s2 <= e1
}

phase('Find')
// 模型钉死 opus，不继承会话模型（会话可能跑更贵的档位）；
// codex finder 例外：它只是调 Codex CLI 的壳，沿用其 agentType 定义里的廉价模型
const rounds = await parallel(FINDERS.map(f => () =>
  agent(f.prompt, {
    label: `find:${f.key}:${f.slice}`, phase: 'Find', schema: FINDINGS,
    ...(f.agentType ? { agentType: f.agentType } : { model: 'opus' }),
  })
))

// 展平并标注发现者（agent 被跳过/出错时 rounds 对应项为 null）
const raw = rounds
  .map((r, i) => (r ? r.findings.map(x => ({ ...x, by: FINDERS[i].key })) : []))
  .flat()

// 纯代码去重：同文件且行区间重叠 → 合并（发现者并集、严重度取最高）
// 去重必须等全部 finder 完成（跨片、跨维度操作），此处 barrier 是合法的
const SEV = { BLOCKER: 3, IMPORTANT: 2, NIT: 1 }
const merged = []
for (const f of raw) {
  const dup = merged.find(g => overlap(g, f))
  if (dup) {
    dup.by = [...new Set([...dup.by, f.by])]
    if (SEV[f.severity] > SEV[dup.severity]) dup.severity = f.severity
  } else {
    merged.push({ ...f, by: [f.by] })
  }
}

// NIT 不值得验证成本，直接带回报告；🔴/🟡 逐条进对抗验证
const nits = merged.filter(f => f.severity === 'NIT')
const toVerify = merged.filter(f => f.severity !== 'NIT')
log(`去重后 ${merged.length} 条：🔴/🟡 ${toVerify.length} 条进入对抗验证，🟢 ${nits.length} 条直接列出`)

phase('Verify')
// 三个独立怀疑视角，每个只裁决一个维度，多数决（≥2/3）定去留
const LENSES = [
  { key: 'importance', q: '这个问题对用户/业务/维护者真的重要吗，还是风格偏好或凑数？' },
  { key: 'root-cause', q: '它指出的是根因还是表层症状？建议是根本修复还是缓解/绕过？' },
  { key: 'risk', q: '不修复会在真实场景触发正确性/安全/重大可维护性问题吗？' },
]
const verified = await parallel(toVerify.map(f => () =>
  parallel(LENSES.map(l => () =>
    agent(
      `你是独立的 review 仲裁者，立场是怀疑：优先尝试否决下面这条发现，证据不足或站不住脚就判 valid=false。\n\n` +
      `仲裁视角（只回答这一个维度）：${l.q}\n\n` +
      `Review 上下文：\n${CONTEXT}\n\n` +
      `待仲裁发现（由 ${f.by.join('/')} 提出）：\n` +
      `标题：${f.title}\n位置：${f.file}:${f.lines}\n严重度：${f.severity}\n` +
      `事实：${f.fact}\n影响：${f.impact}\n建议：${f.suggestion}\n\n` +
      `要求：先用 Read/Grep 实地核对 ${f.file} 相关代码再裁决，不得仅凭描述判断。只读，不修改任何文件、不操作 git。`,
      { label: `verify:${l.key}:${f.file}`, phase: 'Verify', schema: VERDICT, model: 'opus' },
    )
  )).then(vs => {
    const votes = vs.map((v, i) => (v ? { lens: LENSES[i].key, ...v } : null)).filter(Boolean)
    return { ...f, votes, pass: votes.filter(v => v.valid).length >= 2 }
  })
))

const kept = verified.filter(Boolean)
const rejected = kept.filter(f => !f.pass)

phase('Sweep')
// 每条确认项扫一遍同类兄弟位点：点修不修类是 review 不收敛的主因
const swept = await parallel(kept.filter(f => f.pass).map(f => () =>
  agent(
    `你是同类扫描者。下面是一条已经对抗验证确认的缺陷，任务不是复核它，而是找出它的兄弟位点：` +
    `在 review 范围内的改动文件里（先执行 \`${CHANGED_FILES_CMD}\` 取清单），同一缺陷模式在别处的出现——` +
    `同类调用缺同样的处理、同类输入缺同样的校验、同类路径缺同样的信号检查。\n\n` +
    `判定标准：把这条缺陷的修法原样搬过去也成立，才算同类；只是"看起来相似"的不算。` +
    `每个位点必须实地 Read 核对，不得凭文件名或函数名猜测。只读，不修改任何文件、不操作 git。无同类位点返回空数组。\n\n` +
    `Review 上下文：\n${CONTEXT}\n\n` +
    `已确认缺陷：\n标题：${f.title}\n主位点：${f.file}:${f.lines}\n事实：${f.fact}\n建议：${f.suggestion}`,
    { label: `sweep:${f.file}`, phase: 'Sweep', schema: SIBLINGS, model: 'opus' },
  ).then(r => ({
    ...f,
    sites: [{ file: f.file, lines: f.lines, note: '主位点' }, ...((r && r.siblings) || [])],
  }))
))

// 兄弟位点命中另一条确认项 → 两条是同一类，合并为一项（发现者并集、严重度取高、位点并集）
const confirmed = []
for (const f of swept.filter(Boolean)) {
  const host = confirmed.find(g => g.sites.some(s => f.sites.some(t => overlap(s, t))))
  if (host) {
    host.by = [...new Set([...host.by, ...f.by])]
    if (SEV[f.severity] > SEV[host.severity]) host.severity = f.severity
    for (const s of f.sites) if (!host.sites.some(t => overlap(s, t))) host.sites.push(s)
  } else {
    confirmed.push(f)
  }
}
log(`确认 ${confirmed.length} 项（同类合并前 ${swept.length} 条），含兄弟位点的 ${confirmed.filter(f => f.sites.length > 1).length} 项`)

return { confirmed, rejected, nits }
```

---

## 4. 输出

主 agent 拿 workflow 返回值（`confirmed` / `rejected` / `nits`）写最终报告。

**输出节奏：先全景简表，后逐个展开。** 开局只给概览 + 简表表格（让用户知道有几个问题、严重度分布、各由哪个 finder 发现），**禁止一次性平铺所有问题的详细分析与修复方案**——详细内容只在逐个解决模式中一次一条给出。理由：前面的修复可能让后面的问题自然消失，提前展开既浪费也误导。

### 测试缺陷类 finding 处理

当 finding 指向**测试本身**（断言写错、用例设计不合理、覆盖场景缺失）而非实现代码时：

- 在该 finding 标题后追加 `[测试缺陷]` 标签
- 逐个解决模式展开该项时，修复方向不给修测试的代码方案，只给 /revise 归因提示：写 `测试层 impl-defect`；若 finding 暗示 spec 对预期行为描述不清导致测试写错，写 `疑似 spec-defect`

### 概览

```
本地 ultrareview 完成 · <base>..<branch>（N commits / M 文件 / +L1 -L2 / K 片）
重点：<focus 一句话；未指定时写「未指定，全面审视」>
finder：📐质量 🛡️安全 🧹简洁 🪨鲁棒 📄文档 🤖Codex（6/6 就绪 × K 片）
去重 N 条 → ✅ A 确认（含同类位点 a''）/ ❌ B 否决 / 🟢 C 未验证 ｜ 🔴 a（⭐a'）· 🟡 b（⭐b'）· ♻️ 复发 r
上轮对照：<report 文件名 或「无」>
消耗：X agents · ~Y tokens · Z 分钟
```

finder 行必须完整列出（Codex 不可用时该行写 `（5/6 就绪，🤖Codex 不可用）`）；后续表格 by 列写图标 + 文字名（与 finder 行一致，如 `📐质量`）。⭐ = 被 ≥ 2 个 finder 命中的交叉验证强信号，由表格里的 ⭐ 标记与 by 列多 finder 直接呈现，不设独立汇总行。♻️ = 命中上轮已修复项的复发。

### ✅ 确认问题表（质量/安全优先排序）

排序键依次为：①by 含 📐质量 或 🛡️安全 的优先；②其中"风险"仲裁视角 ✓（不修会出真实问题）的优先；③严重度 🔴 → 🟡；④⭐ 交叉验证优先。逐个解决模式按此表顺序处理。

```
**✅ 确认问题**（回复编号即从该项开始讲解）

| # | 级 | 问题 | 位置 | by |
|---|----|------|------|----|
| 1 | 🔴⭐ | 标题 | file:lines（+2 同类） | 📐质量 🧹简洁 |
| 2 | 🟡 | ♻️ 标题 | file:lines | 🤖Codex |
```

- 标题 ≤ 20 字（`[测试缺陷]` 标签与 ♻️ 不计入）——详细分析本就留给逐个解决模式，压短无信息损失，且防止表格在窄终端折行
- 位置列写主位点完整相对路径 `file:lines`（保持可点击），不得截断；有兄弟位点时追加 `（+N 同类）`，全部位点在展开时列出

### 🟢 NIT 表（未对抗验证）

```
**🟢 NIT**（未对抗验证；回复"批量清 NIT"可一次处理）

| # | 问题 | 位置 | by |
|---|------|------|----|
| N1 | 标题 | file:lines | 📐质量 |
```

### ❌ 否决表（透明化，用户可质询）

```
**❌ 否决**（多数视角判不成立，未展开；回复"展开否决项"可质询）

| 原级 | 问题 | 重要 | 根源 | 风险 | 票 | 关键理由 |
|------|------|:--:|:--:|:--:|----|----------|
| 🔴 | 标题 | ✗ | ✗ | ✗ | 3:0 | 一句话（多数 ✗ 维度的核心依据） |
```

票 = 否决:通过。用户回复 `展开否决项` / `展开第 N 项` 才给完整内容。

### 报告落盘

简表输出后立即把本轮结果写入 `<base_dir>/.cache/review/<branch>/<YYYYMMDD-HHMM>.md`（目录规则见 §1），后续每闭环一项就更新该项状态，收尾时再写一次终态。内容：

```
# review <base>..<branch> @ <HEAD0 短 sha> · <时间>

## 确认
| # | 级 | 标题 | 位点（全部） | by | 票 | 状态 |
状态 ∈ 已修 <commit> / 跳过 / 自然解决（被 #N 顺带）/ 未处理

## 否决
| 标题 | 位置 | 票 | 关键理由 |

## NIT
| # | 标题 | 位置 | by | 状态 |
状态 ∈ 已清 <commit> / 不成立 / 未处理

## 修复复审
<无 / 复审范围 HEAD0..HEAD、确认 n 条及各自状态>
```

下一轮 /review 读取它生成 history（§1）。

### 询问下一步

简表之后立即用 AskUserQuestion 询问（不预先展开任何一项），选项：
  · **开始**（推荐）→ 从第 1 个问题起，逐个讲解、逐项确认后修
  · **展开否决项** → 看看被对抗验证否决的那些，怕误杀
  · **批量清 NIT** → 一次处理 🟢 NIT 表
  · **结束** → 看完了，不修了
  （要从指定项开始讲解，用 Other 直接填项目编号，如 "3"）

确认队列清空后再问一次同样的问题（去掉「开始」）；用户选「结束」或队列与 NIT 都清空时进入修复复审。

### 逐个解决模式

用户选择开始后进入循环，**一轮只展开、只处理一个问题**，处理顺序 = 确认问题表顺序（质量/安全 → 风险 ✓ → 严重度 → ⭐）。

**修复一律走 /revise，一次修一类**：用户确认修某个问题后，用 Skill 工具调用 `revise`，把该 finding 的完整上下文（标题、**全部位点**（主位点 + 兄弟位点各自的 file:lines 与同类说明）、事实、影响、初步修复方向，`[测试缺陷]` 类附归因提示）作为参数传入，并写明「以上位点属同一缺陷类，须在同一次修复中全部处理，禁止只修主位点」。归因诊断及确认、修复方案、TDD 修正、全量测试、本地 commit、完成简报全部由 revise 闭环——review 端不自行改代码、不另跑测试、不另做前后对照确认，禁止绕过 revise 在对话里直接改代码。

**文档同步类例外（自动修复，不询问）**：finding 同时满足 ①仅由 📄文档 发现 ②修复只涉及文档/注释、不改变任何代码行为 → 展开后不等待用户确认、不走 /revise，直接外科手术式修好，单行说明改动后进入复核与下一条。两个条件任一不满足 → 按普通问题处理。

1. **展开当前问题**（仅此一条），按下方骨架输出——每个字段独立成段、空行分隔，段内用子弹或表格分点，禁止把任何字段写成连排长段：

   ```
   ### [🔴/🟡] 项N · 标题 [⭐ 交叉验证] [♻️ 复发]（第 i / 共 K 个）

   位置：file:lines
   同类位点：file:lines — <为何同类>（一行一个；无则省略本行）
   发现者：📐质量 🧹简洁 · 对抗验证：X/3 票通过（重要性 ✓/✗ · 根源性 ✓/✗ · 风险 ✓/✗）

   **背景**

   <机制全貌：这套机制为何存在、分哪几条路径/哪几层，2-4 句>

   - 关键设计：<理解本问题所必需的设计事实，一条一行>

   <问题源于多条路径行为不一致时，附逐路径对比表：路径 | 行为 | 代码位置>

   **时间线**

   | 时刻 | 事件 |
   |---|---|
   | T0 | <一行一个事件，落到代码位置（file:line / 函数名）> |
   | …  | <…> |
   | Tn | <最后一行停在出问题的代码行为上> |

   **结果对比**

   | 项 | 应然 | 实然 | 判定 |
   |---|---|---|---|
   | <对比项> | <真实发生的 / 文档承诺的 / 预期的> | <系统账面 / 代码实际> | ❌ <一句成因> |

   <表后一段：后果有多重——谁受损、损失为何无人知晓；若某项设计初衷反被该缺陷放大/架空，单独一小段点破>

   **修复方向**（初步，只给一个）

   - 定性：<根源解 / 缓解症状 / 临时绕过，三选一开门给出>
   - 替代：<更根源的方向> · 代价：<选当前方向的代价，如"成本高 X 倍，本次先绕过">（仅当定性非「根源解」时必有此行）
   - 改动：<哪个文件哪几行、怎么改；同类位点走同一道安全网，优先复用既有的同类处理路径>
   ```

   各字段写法：

   - **背景**：用业务语言讲清问题所处机制的全貌，目标是隔几天再看的读者不翻代码也能进入上下文。
   - **时间线**：执行触发时间线，非 git 提交史；按 finding 性质二选一，不许只给抽象描述：
     - 行为类（正确性 / 安全 / 性能）→ 虚构一个具名触发方带具体参数（如"玩家小明的 150 元"），把抽象缺陷讲成具体故事，按上表逐行推进。
     - 非行为类（可维护性 / 简洁性 / 文档同步）→ 无执行时间线，删掉该表，改用代码证据 + 后果场景：摘录实际片段，说明"下次有人改 X 会因 Y 踩坑" / "文档说 A 代码做 B，照文档写会错"。
   - **结果对比**：问题造成的"应然 vs 实然"，不是修复前后对比——那是第 3 步的事；逐项 ✅/❌ 标注，每个 ❌ 必须旁注一句成因。
   - **修复方向**：写之前先做三问自审——①指向根源还是缓解症状？②是最优解还是次优妥协？（次优必须点名"更优做法是什么、为何不做"）③是否只是暂时绕过 / 打补丁 / 加临时开关？自审结论落进「定性」行；只写一个建议，不写"其实还有 A/B/C"式含糊列举。本字段仅供用户决策修/不修，并作为 /revise 的输入——归因（spec/impl/需求哪层出错）与最终修法由 /revise 诊断裁定，此处不写完整代码改动。

2. **对话解决**：展开当前问题后必须结束回合，停下等用户回应——确认修 / 讨论调整方案 / 跳过。「开始」选项与回复编号只是进入讲解流程，不构成任何一项的修复授权；每项的修复授权必须是用户看到该项完整展开后针对该项的显式回复。用户确认后调用 /revise 修复（见上方规则），一次只修当前这一类问题；revise 的完成简报即该项闭环。
3. **复核剩余问题**：每闭环一个，先用 Read 实地核对队列中剩余每条是否仍然成立——前面的修复可能已顺带解决后面的问题。已自然解决的单行说明（`项M 已被项N 的修复顺带解决：<一句话原因>`）并移出队列，不再展开。
4. 进入下一条，直到队列清空或用户喊停。
5. **收尾小结**：修复 a 条 / 跳过 b 条 / 自然解决 c 条，列出涉及的文件清单，随后进入修复复审。

### 批量清 NIT

NIT 不做对抗验证，也从不进逐个解决队列，放着就会每轮原样重报。用户选「批量清 NIT」后：

1. 用户回复要清的编号（`全部` 或 `N1 N3 N7`）
2. 逐条 Read 实地核对；不成立的标「不成立」并跳过，不改代码
3. 按性质分两路：
   - **非行为类**（文档/注释/命名/死代码/重复声明/只写不读字段等，修复不改变任何运行行为）→ 主 agent 直接外科手术式修好，全部改完做**一次**本地 commit（message 遵循仓库历史风格，仅本地不 push），逐条单行说明改了什么
   - **行为类**（修复会改变运行行为）→ 追加到确认队列末尾，按逐个解决模式走 /revise（用户可逐项跳过）
4. 更新 report 中各 NIT 的状态

### 修复复审

修复代码没有经过与初始代码同等强度的审查，是下一轮 review 冒出"新"问题的直接来源。确认队列与 NIT 处理都结束后：

1. `git rev-list --count <HEAD0>..HEAD` 为 0（本轮没有修复 commit）→ 跳过，收尾写「修复复审：无」
2. 否则以 `<HEAD0>..HEAD` 为范围再跑一次 §3 的 Workflow：finder 只派 📐质量 🛡️安全 🪨鲁棒（修复 diff 小，单片；`{review_scope}` 写清「本范围是上一轮 review 的修复代码」；`{history}` 注入本轮已修清单，命中同类标 ♻️），Verify 与 Sweep 照常
3. 输出 `🔁 修复复审 · <HEAD0 短 sha>..<HEAD 短 sha>（n commits / m 文件）` + 同格式的确认/NIT/否决表；有确认项则回到逐个解决模式处理
4. **复审只做一轮**：复审修复后的代码不再自动复审，留给下一次 /review；收尾小结与 report 都写明这一点

最终收尾：`本轮闭环：修复 a 条（含同类位点 a''）/ 跳过 b / 自然解决 c / NIT 已清 d / 复审确认 e 并修复 e'；report：<路径>`。

---

## 5. 硬约束

- review 过程不修代码、不做写性 git 操作、不扩大范围（只看 base..branch 与修复复审的 HEAD0..HEAD）；唯一的写入例外：①逐个解决模式中的修复——普通问题经用户逐条确认后走 /revise，文档同步类按例外规则自动修复；②批量清 NIT 的非行为类直接修；③report 写入 `<base_dir>/.cache/review/`
- finder 必须按维度 × 分片派工，禁止把多片合并给一个 finder；每片 ≤ 1500 行且 ≤ 15 文件
- 确认项必须经 Sweep 同类扫描后才出报告；交给 /revise 时必须带全部位点并要求一次修一类
- focus 仅影响**关注优先级与排序**，不缩小审视面：finder 不得因「不在 focus 内」而丢弃本应报出的发现，尤其安全/正确性维度
- history 中的已否决项无新证据不重报；已修复项再次命中必须标 ♻️，禁止静默当新问题
- 逐个解决模式的修复必须经 /revise 执行（文档同步类例外），禁止在对话里直接改代码
- 逐个解决模式中，任何一项未完整展开并获得用户对该项的显式确认前，禁止调用 /revise 或改动任何文件（文档同步类例外除外）
- 详细分析与修复方案只在逐个解决模式中一次一条给出，禁止开局全量平铺
- 本轮有修复 commit 就必须跑修复复审，且只跑一轮
- finder / 验证者 / 同类扫描者 prompt 自包含（agent 看不到本对话）
- 编排必须走 Workflow 工具；环境无 Workflow 工具 → 中止提示升级，禁止退回主 agent 手工派工
- 发现者与验证者隔离：验证者必须实地核对代码，不得只复读 finding 描述
- Codex 不可用时 finder 缩为 5 个
- 输出语言跟随用户工作语言
