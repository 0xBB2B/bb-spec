export const meta = {
  name: 'exec-group',
  description: '一个执行组内各 plan 并发、各自串行走 Red→Green→Gate→Review 的三 Agent 隔离 TDD 流水线',
  phases: [
    { title: 'Red', detail: 'test-engineer 只读 spec 写失败测试' },
    { title: 'Green', detail: 'impl-engineer 只看测试写最小实现' },
    { title: 'Gate', detail: '重跑本 plan 范围测试 + 依赖守卫 + 简洁性审视' },
    { title: 'Review', detail: 'spec-reviewer 对照 spec 合规审查并逐条归因' },
  ],
}

// ===== 执行组输入（派工前由主 agent 填充，禁用 args 传参） =====
const SITE = '/abs/path/to/execution-site'
const PROJECT = `/* 语言 / 框架 / 架构约束 */`
const TESTING = `/* 测试框架、目录、命名风格、一段已有测试示例 */`
const PLANS = [/* { name, rules, verification, functions, artifacts, deps, testScope }, ... */]

const RED = {
  type: 'object', required: ['status', 'testFiles', 'caseCount', 'coverage', 'detail'],
  properties: {
    status: { type: 'string', enum: ['red', 'behavior_exists', 'failed'], description: 'red=编译通过且断言失败；behavior_exists=全部意外 PASS 且确认行为已存在；failed=无法得到有效 Red' },
    testFiles: { type: 'array', items: { type: 'string' }, description: '相对 SITE 的测试文件路径' },
    caseCount: { type: 'integer' },
    coverage: { type: 'string', description: '每条规则对应的用例名' },
    detail: { type: 'string', description: 'failed / behavior_exists 时写清原因与证据' },
  },
}
const GREEN = {
  type: 'object', required: ['testsPass', 'implFiles', 'functions', 'failures', 'extraDeps'],
  properties: {
    testsPass: { type: 'boolean' },
    implFiles: { type: 'array', items: { type: 'string' }, description: '相对 SITE 的实现文件路径' },
    functions: { type: 'array', items: { type: 'string' }, description: '函数名 + 所在文件' },
    failures: { type: 'string', description: '未通过时列失败用例 + 错误信息，通过则空串' },
    extraDeps: { type: 'array', items: { type: 'string' }, description: 'plan 清单外确属必需的第三方库（未 import、未安装），无则空数组' },
  },
}
const GATE = {
  type: 'object', required: ['testsPass', 'testOutput', 'depViolations', 'overDesign'],
  properties: {
    testsPass: { type: 'boolean' },
    testOutput: { type: 'string', description: '失败时截取失败部分，通过则一行摘要' },
    depViolations: { type: 'array', items: { type: 'string' }, description: '依赖文件 diff 中超出允许清单的第三方库' },
    overDesign: { type: 'array', items: { type: 'string' }, description: 'file:line + plan 未要求的抽象/防御/功能，为何多余' },
  },
}
const REVIEW = {
  type: 'object', required: ['findings', 'summary'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object', required: ['kind', 'file', 'lines', 'issue', 'suggestion', 'rootCause'],
        properties: {
          kind: { type: 'string', enum: ['spec-violation', 'test-gap', 'discipline', 'robustness', 'security'] },
          file: { type: 'string' },
          lines: { type: 'string' },
          issue: { type: 'string', description: '具体问题 + 触发条件或攻击路径' },
          suggestion: { type: 'string', description: '修复方向' },
          rootCause: { type: 'string', enum: ['impl-defect', 'spec-defect', 'uncertain'], description: 'impl-defect=spec 正确、实现或测试不符；spec-defect=spec 自身矛盾/缺失；uncertain=证据不足或疑似需求层变化' },
        },
      },
    },
    summary: { type: 'string', description: 'spec 合规 N/M 条，违规 X 条，测试遗漏 Y 条，代码纪律违规 Z 条，鲁棒/安全 W 条' },
  },
}

const site = `执行现场：${SITE}——所有文件读写与命令都在此目录下执行，禁止碰其他目录。禁止写 PROGRESS.md，禁止任何 git 写操作（add/commit/stash/checkout 等）。`
const union = (a, b) => [...new Set([...a, ...b])]

function redPrompt(p, feedback, repair) {
  return `${site}\n\n## 行为规则（来自 spec）\n${p.rules}\n\n## 验证预期\n${p.verification}\n\n## 项目约束\n${PROJECT}\n\n## 项目测试惯例\n${TESTING}\n\n` +
    (repair
      ? `## 任务（自修补测试）\n合规审查发现下列问题，请为每一条补充或修正测试，使当前实现在这些点上失败；纯测试遗漏项补上用例即可（可能立即 PASS，如实以 behavior_exists 报告）。已有测试文件：${repair.testFiles.join(', ')}\n\n${repair.findings.map((f, i) => `${i + 1}. [${f.kind}] ${f.issue}`).join('\n')}\n\n`
      : `## 任务\n按行为规则写测试，每条规则至少一个用例，覆盖正常 + 边界 + 错误场景。\n\n`) +
    `测试只跑本 plan 范围：\`${p.testScope}\`（同组其他 plan 可能仍在 Red，禁跑全量）。编译失败先自行修 import / 类型后重跑；编译通过且断言失败 → status=red；全部意外 PASS 且确认行为已存在 → status=behavior_exists；无法得到有效 Red → status=failed 并在 detail 写清原因。不得猜测实现的函数名、文件路径或内部结构，不写实现代码。` +
    (feedback ? `\n\n## 上一轮问题\n${feedback}` : '')
}

function greenPrompt(p, testFiles, feedback) {
  return `${site}\n\n## 实施计划（函数清单 + 文件路径 + 协作关系）\n${p.functions}\n\n` +
    (p.artifacts ? `## 成品定义（原样落盘，不得改写）\n${p.artifacts}\n\n` : '') +
    `## 允许新增的第三方依赖\n${p.deps}\n\n## 测试文件（先读取，理解要实现的行为）\n${testFiles.map(f => `- ${f}`).join('\n')}\n\n## 项目约束\n${PROJECT}\n\n` +
    `## 任务\n用最小代码让测试全部通过。测试只跑本 plan 范围：\`${p.testScope}\`。新增第三方库以上面清单为界；清单外确属必需时**不 import、不安装**，把库名写进 extraDeps 后停止。不改测试、不加测试未覆盖的功能。` +
    (feedback ? `\n\n## 上一轮问题（逐条解决）\n${feedback}` : '')
}

function gatePrompt(p, out) {
  return `${site}\n\n你是执行守门员，只读不改。\n\n` +
    `1. 运行 \`${p.testScope}\`，如实返回 testsPass；失败时 testOutput 截取失败部分。\n` +
    `2. 依赖守卫：\`git diff\` 依赖文件（go.mod / package.json / Cargo.toml / pyproject.toml / requirements*.txt 等）中新增的第三方库，与允许清单比对，清单外的每一项写进 depViolations。允许清单：\n${p.deps}\n` +
    `3. 简洁性审视：读实现文件 ${out.implFiles.join(', ')}，对照函数清单找出 plan 未要求的抽象 / 防御 / 功能 / 参数化 / helper，每项写 file:line + 为何多余进 overDesign。只报确凿的，不报风格偏好。函数清单：\n${p.functions}`
}

function reviewPrompt(p, out, prev) {
  return `${site}\n\n## Spec 规则\n${p.rules}\n\n## 验证预期\n${p.verification}\n\n## 变更文件（读取完整内容）\n${union(out.testFiles, out.implFiles).map(f => `- ${f}`).join('\n')}\n\n` +
    (prev ? `## 本轮是 impl-defect 自修后的复审\n上一轮发现：\n${prev.map((f, i) => `${i + 1}. [${f.kind}] ${f.file}:${f.lines} ${f.issue}`).join('\n')}\n已自修一次，请核对是否解决并按同一标准审查修复代码。\n\n` : '') +
    `## 任务\n逐条 spec 规则核对实现合规与测试覆盖，再以代码纪律、鲁棒性、安全视角过一遍。每条发现必须给 file:line + 具体触发条件或攻击路径 + 修复方向，并判定 rootCause：impl-defect（spec 正确，实现或测试不符，纯执行层可修）/ spec-defect（spec 自身矛盾、缺失或与验证预期冲突）/ uncertain（证据不足，或疑似用户实际需要与 spec 不同）。给不出具体触发条件的不报，零发现是合法结果。`
}

// Green + Gate 一轮：返回 { fatal, issues }；issues 为空即通过
async function greenGate(p, out, feedback) {
  const green = await agent(greenPrompt(p, out.testFiles, feedback),
    { agentType: 'bb-spec-workflow:impl-engineer', label: `green:${p.name}`, phase: 'Green', schema: GREEN })
  if (!green) return { fatal: true, issues: 'impl-engineer 未返回结果' }
  out.implFiles = union(out.implFiles, green.implFiles)
  if (green.extraDeps.length) return { fatal: true, issues: `需要 plan 清单外的第三方库：${green.extraDeps.join(', ')}` }
  const gate = await agent(gatePrompt(p, out),
    { agentType: 'general-purpose', label: `gate:${p.name}`, phase: 'Gate', schema: GATE, effort: 'low' })
  if (!gate) return { fatal: true, issues: 'gate 未返回结果' }
  const issues = [
    ...(gate.testsPass ? [] : [`测试未全部通过：\n${gate.testOutput}`]),
    ...gate.depViolations.map(d => `依赖守卫：${d}——改用标准库或项目已有依赖`),
    ...gate.overDesign.map(o => `过度设计：${o}——删掉，用最少代码让测试通过`),
  ]
  return { fatal: false, issues: issues.join('\n') }
}

async function runPlan(p) {
  const out = { plan: p.name, status: 'blocked', stage: 'Red', reason: '', testFiles: [], implFiles: [], review: null, retries: { red: 0, green: 0 }, selfRepaired: false }
  const block = (stage, reason) => { out.stage = stage; out.reason = reason; return out }

  // Red：≤1 次重试
  let red = null, feedback = ''
  for (let i = 0; i < 2; i++) {
    red = await agent(redPrompt(p, feedback, null),
      { agentType: 'bb-spec-workflow:test-engineer', label: `red:${p.name}`, phase: 'Red', schema: RED })
    if (!red) return block('Red', 'test-engineer 未返回结果')
    out.testFiles = union(out.testFiles, red.testFiles)
    if (red.status !== 'failed') break
    feedback = red.detail; out.retries.red++
  }
  if (red.status === 'failed') return block('Red', red.detail)
  if (red.status === 'behavior_exists') { out.status = 'skipped'; out.reason = red.detail; return out }

  // Green + Gate：≤1 次重试；清单外依赖立即阻塞
  let issues = ''
  for (let i = 0; i < 2; i++) {
    const r = await greenGate(p, out, issues)
    if (r.fatal) return block('Green', r.issues)
    issues = r.issues
    if (!issues) break
    out.retries.green++
  }
  if (issues) return block('Green', issues)

  // Review：全部 impl-defect 且未自修过 → 自修一次（补 Red → Green → Gate → 复审）；否则阻塞交用户
  let prev = null
  for (let round = 0; round < 2; round++) {
    const review = await agent(reviewPrompt(p, out, prev),
      { agentType: 'bb-spec-workflow:spec-reviewer', label: `review:${p.name}`, phase: 'Review', schema: REVIEW })
    if (!review) return block('Review', 'spec-reviewer 未返回结果')
    out.review = review
    if (review.findings.length === 0) { out.status = 'done'; out.stage = 'Review'; return out }
    const allImpl = review.findings.every(f => f.rootCause === 'impl-defect')
    if (!allImpl) return block('Review', '存在 spec-defect / 归因存疑项，需用户裁决')
    if (round === 1) return block('Review', '自修 1 次后仍有 impl-defect 违规')
    out.selfRepaired = true
    prev = review.findings
    const fix = await agent(redPrompt(p, '', { testFiles: out.testFiles, findings: prev }),
      { agentType: 'bb-spec-workflow:test-engineer', label: `red-fix:${p.name}`, phase: 'Red', schema: RED })
    if (!fix || fix.status === 'failed') return block('Review', `自修补测试失败：${fix ? fix.detail : '未返回结果'}`)
    out.testFiles = union(out.testFiles, fix.testFiles)
    const r = await greenGate(p, out, prev.map((f, i) => `${i + 1}. ${f.file}:${f.lines} ${f.issue}——${f.suggestion}`).join('\n'))
    if (r.fatal || r.issues) return block('Review', `自修实现未通过守门：${r.issues}`)
  }
  return out
}

const results = (await parallel(PLANS.map(p => () => runPlan(p)))).filter(Boolean)
const stats = {
  total: PLANS.length,
  done: results.filter(r => r.status === 'done').length,
  skipped: results.filter(r => r.status === 'skipped').length,
  blocked: results.filter(r => r.status === 'blocked').length,
  selfRepaired: results.filter(r => r.selfRepaired).length,
}
log(`组内 ${stats.total} 个 plan：done ${stats.done} / skipped ${stats.skipped} / blocked ${stats.blocked}`)
return { results, stats }
