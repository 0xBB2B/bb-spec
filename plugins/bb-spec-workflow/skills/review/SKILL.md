---
name: review
description: Workflow-orchestrated adversarially-verified local review of the current branch vs a base branch (requires Claude Code >= 2.1.154 for the Workflow tool). Base defaults to main; override with /review <base-branch>. Phase 1 spawns 5 finders in parallel (code quality, security, simplicity, doc sync, Codex cross-model independent review) with schema-enforced structured findings; findings are deduped in plain code, then every BLOCKER/IMPORTANT finding is adversarially verified by 3 independent skeptic lenses (importance / root-cause / risk-if-unfixed) with majority vote deciding keep-or-drop. Read-only — never auto-edits code. ｜ 用 Workflow 工具编排的"多代理 + 对抗验证"本地 review（依赖 Workflow 工具，要求 Claude Code ≥ 2.1.154）。默认 base = main，可用 /review <base-branch> 指定。Phase 1 并发 5 个 finder（代码质量、安全视角、代码简洁性、文档同步、Codex 跨模型独立 review），schema 强制结构化发现；纯代码去重后，每条 🔴/🟡 发现交由 3 个独立怀疑视角（重要性 / 根源性 / 不修风险）对抗验证，多数决定去留。只读审视，不自动修改代码。
argument-hint: <base-branch>
disable-model-invocation: true
---

# 本地 ultrareview

跨模型、多代理、对抗验证、只读的 PR 级 review 协调者。

**核心原则**：跨模型独立 / prompt 自包含 / 只读不写 / 发现者与验证者隔离 / 基于 `file:line` 事实。

---

## 1. 输入与前置检查

`$ARGUMENTS` = base 分支名（默认 `main`，不存在则 `master`，再不存在则提示用户）。

前置检查：

- 确认 git 仓库 / 当前分支 ≠ base / base 存在 / 未提交改动仅警告不中止
- **Workflow 工具**：本 skill 依赖 Workflow 工具（Claude Code ≥ 2.1.154）。当前环境工具列表中没有 Workflow → **中止**，提示用户升级 Claude Code，不降级执行
- **Codex 探测**：`which codex` 失败 → finder 缩为 4 个（去掉 Codex），报告中说明

回显：`review 范围：<base> .. HEAD | 分支：<name> | commits：N | diff：M 文件 +L1/-L2`

### 修复主题摘要（≤ 300 字）

从 commit messages + CLAUDE.md 提取"想解决什么 / 修复策略 / 关键约束"，注入每个 finder prompt。

---

## 2. 组装 finder

每个 finder prompt 由对应定义文件（插件根目录 `agents/`）+ 本次 review 上下文（范围、主题摘要、约束清单）组合而成。派工前用 Read 读取 agent 定义，填充 `{review_scope}` / `{topic_summary}` / `{constraints}` 模板变量。

| key | 定义文件 | agentType |
|---|---|---|
| quality | `agents/review-code-quality.md` | （默认） |
| security | `agents/review-security.md` | （默认） |
| simplicity | `agents/review-simplicity.md` | （默认） |
| doc-sync | `agents/review-doc-sync.md` | （默认） |
| codex | `agents/review-codex.md` | `codex:codex-rescue` |

构造 `finders` 数组：`[{key, prompt, agentType?}, ...]`（Codex 不可用则不含 codex 项）。

---

## 3. Workflow 编排

调用 Workflow 工具，**不使用 `args` 传参**（大对象经 args 易被序列化成字符串导致脚本取不到字段），把数据直接内嵌进脚本：将模板顶部的 `FINDERS` 替换为组装好的 finders 数组、`CONTEXT` 替换为一段自包含的 review 上下文文本（范围 `<base>..HEAD`、主题摘要、约束清单）。内嵌长文本用模板字符串时注意转义内容中的 `` ` `` 与 `${`。`script` 用下面模板：

```js
export const meta = {
  name: 'local-ultrareview',
  description: '多维 finder 并行审查 + 逐条对抗验证的本地 review',
  phases: [
    { title: 'Find', detail: '多维 finder 并行审查' },
    { title: 'Verify', detail: '每条 🔴/🟡 × 3 个独立怀疑视角对抗验证' },
  ],
}

// ===== review 输入（派工前由协调者填充，禁用 args 传参） =====
const FINDERS = [/* {key, prompt, agentType?}, ... */]
const CONTEXT = `/* 自包含 review 上下文：范围、主题摘要、约束清单 */`

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
          title: { type: 'string' },
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

phase('Find')
const rounds = await parallel(FINDERS.map(f => () =>
  agent(f.prompt, {
    label: `find:${f.key}`, phase: 'Find', schema: FINDINGS,
    ...(f.agentType ? { agentType: f.agentType } : {}),
  })
))

// 展平并标注发现者（agent 被跳过/出错时 rounds 对应项为 null）
const raw = rounds
  .map((r, i) => (r ? r.findings.map(x => ({ ...x, by: FINDERS[i].key })) : []))
  .flat()

// 纯代码去重：同文件且行区间重叠 → 合并（发现者并集、严重度取最高）
// 去重必须等全部 finder 完成（跨条目操作），此处 barrier 是合法的
function span(lines) {
  const m = String(lines).match(/(\d+)\D*(\d+)?/)
  const a = m ? +m[1] : 0
  return [a, m && m[2] ? +m[2] : a]
}
const SEV = { BLOCKER: 3, IMPORTANT: 2, NIT: 1 }
const merged = []
for (const f of raw) {
  const [s, e] = span(f.lines)
  const dup = merged.find(g =>
    g.file === f.file && span(g.lines)[0] <= e && s <= span(g.lines)[1])
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
      { label: `verify:${l.key}:${f.file}`, phase: 'Verify', schema: VERDICT },
    )
  )).then(vs => {
    const votes = vs.map((v, i) => (v ? { lens: LENSES[i].key, ...v } : null)).filter(Boolean)
    return { ...f, votes, pass: votes.filter(v => v.valid).length >= 2 }
  })
))

const kept = verified.filter(Boolean)
return {
  confirmed: kept.filter(f => f.pass),
  rejected: kept.filter(f => !f.pass),
  nits,
}
```

---

## 4. 输出

主 agent 拿 workflow 返回值（`confirmed` / `rejected` / `nits`）写最终报告。

**输出节奏：先全景简表，后逐个展开。** 开局只给概览 + 单行简表（让用户知道有几个问题、严重度分布），**禁止一次性平铺所有问题的详细分析与修复方案**——详细内容只在逐个解决模式中一次一条给出。理由：前面的修复可能让后面的问题自然消失，提前展开既浪费也误导。

### 测试缺陷类 finding 处理

当 finding 指向**测试本身**（断言写错、用例设计不合理、覆盖场景缺失）而非实现代码时：

- 在该 finding 标题后追加 `[测试缺陷]` 标签
- 逐个解决模式展开该项时，修复方向统一写 `走 /revise 诊断（测试层 impl-defect）`，不直接给修测试的代码方案
- 若 finding 暗示 spec 对预期行为描述不清导致测试写错，修复方向写 `走 /revise 诊断（疑似 spec-defect）`

### 概览

```
本地 ultrareview 完成
范围：<base>..HEAD (N commits, M 文件, +L1/-L2)
finder：代码质量 / 安全 / 简洁性 / 文档同步 / Codex
去重后 N 条 → 对抗验证通过 A 条 / 否决 B 条 / 🟢 未验证 C 条
确认分布：🔴 a(⭐a') / 🟡 b(⭐b')
交叉验证强信号：<by ≥ 2 个 finder 的项>
```

### 确认问题简表（按 🔴 → 🟡 重排，⭐ 优先；单行列出，不展开细节）

```
1. [🔴] 标题 [⭐] · file:lines（by <finder>）
2. [🟡] 标题 · file:lines（by <finder>）
```

### 🟢 NIT 简表（未验证，单行列出）

```
- file:lines · 标题（by <finder>）
```

### 被否决项（透明化，单行列出，用户可质询）

```
对抗验证否决 N 条（多数视角判不成立，未展开）：
- [原 🟡] 标题（重要性 ✗：<reason> / 根源性 ✓ / 风险 ✗）
- ...
```

用户回复 `展开否决项` / `展开第 N 项` 才给完整内容。

### 询问是否逐个解决

简表之后立即询问，不预先展开任何一项：

`接下来怎么办？回复以下任一项：`
`  · "开始" → 从第 1 个问题起，一个一个对话解决（推荐）`
`  · 项目编号（如 "3"）→ 从该项开始逐个解决`
`  · "展开否决项" → 看看被对抗验证否决的那些，怕误杀`
`  · "结束" → 看完了，不修了`

### 逐个解决模式

用户选择开始后进入循环，**一轮只展开、只处理一个问题**：

1. **展开当前问题**（仅此一条）：

   ```
   ### [🔴/🟡] 项N · 标题 [⭐ 交叉验证]（第 i / 共 K 个）
   位置：file:lines
   发现者：<by> · 对抗验证：X/3 票通过（重要性 ✓/✗ · 根源性 ✓/✗ · 风险 ✓/✗）
   背景：用业务语言讲清问题所处机制的全貌——这套机制为何存在、分哪几条路径 /
     哪几层，并单独点出理解本问题所必需的"关键设计"事实；问题源于多条路径行为
     不一致时，附一张逐路径对比表（路径 | 行为 | 代码位置）。目标：隔几天再看的
     读者不翻代码也能进入上下文
   时间线（执行触发时间线，非 git 提交史；按 finding 性质二选一，不许只给抽象描述）：
     · 行为类（正确性 / 安全 / 性能）→ 虚构一个具名触发方带具体参数（如"玩家
       小明的 150 元"），把抽象缺陷讲成具体故事：按"时刻 T0..Tn | 事件"表格推进，
       每行一个事件并落到代码位置（file:line / 函数名），最后一行停在出问题的
       代码行为上
     · 非行为类（可维护性 / 简洁性 / 文档同步）→ 无执行时间线，改用代码证据 +
       后果场景：摘录实际片段，说明"下次有人改 X 会因 Y 踩坑" / "文档说 A 代码
       做 B，照文档写会错"
   结果对比（问题造成的"应然 vs 实然"，不是修复前后对比——那是第 3 步的事）：
     逐项对比应然（真实发生的 / 文档承诺的 / 预期的）与实然（系统账面 / 代码
     实际），✅/❌ 标注且每个 ❌ 旁注一句成因；表后用一段业务语言讲清后果有多重
     （谁受损、损失为何无人知晓）；若某项设计初衷反而被该缺陷放大 / 架空，单独
     一小段点破
   修复方向（只给一个）：一句话说明改哪个文件哪几行、怎么改；优先复用既有的
     同类处理路径，让同类场景走同一道安全网；可另附一句最低限度兜底。完整代码
     改动等用户确认后动手时再写
   根源性自检（呈现修复方向前自问，结论对用户可见）：①该方向触及根源还是缓解
     症状？②有无更优做法？自检发现更优 → 直接替换上面的修复方向再呈现（不追加
     备选）；确认已是根源解 → 一句话给出判断依据。注意：Verify 阶段的根源性仲裁
     裁决的是 finder 的原始 suggestion，此处修复方向是展开时新写的，必须独立自检，
     不得以"对抗验证已通过"代替
   ```

2. **对话解决**：停下等用户回应——确认修 / 讨论调整方案 / 跳过。用户确认后才动手，修复遵循外科手术式改动，只修当前这一个问题。
3. **修复后对照确认**：修完立即给一张前后对照表请用户确认。表格的行直接复用"时间线"的内容——行为类沿原编号触发步骤把修复后的代码重走一遍，逐步对比；非行为类对照原代码证据与后果场景：

   | 时刻 / 对比项 | 修复前 | 修复后 |
   |---|---|---|
   | 触发步骤 1..n（每步一行） | 该步原行为 / 走到的分支 | 该步新行为 / 走到的分支 |
   | 最终表现 | 问题后果 ❌ | 预期结果 ✅ |

   用户确认通过才进入下一步；不认可则回到对话继续调整修复。
4. **复核剩余问题**：每修完一个，先用 Read 实地核对队列中剩余每条是否仍然成立——前面的修复可能已顺带解决后面的问题。已自然解决的单行说明（`项M 已被项N 的修复顺带解决：<一句话原因>`）并移出队列，不再展开。
5. 进入下一条，直到队列清空或用户喊停。
6. **收尾小结**：修复 a 条 / 跳过 b 条 / 自然解决 c 条，列出涉及的文件清单。

---

## 5. 硬约束

- review 过程不修代码、不操作 git、不扩大范围（只看 base..HEAD）；唯一例外是逐个解决模式中经用户逐条确认的修复
- 详细分析与修复方案只在逐个解决模式中一次一条给出，禁止开局全量平铺
- finder / 验证者 prompt 自包含（agent 看不到本对话）
- 编排必须走 Workflow 工具；环境无 Workflow 工具 → 中止提示升级，禁止退回主 agent 手工派工
- 发现者与验证者隔离：验证者必须实地核对代码，不得只复读 finding 描述
- Codex 不可用时 finder 缩为 4 个
- 输出语言跟随用户工作语言
