---
name: revise
description: Diagnose the root cause of a deviation between spec→plan→exec output and expectation (definition problem / implementation drift / requirement change) and route to the matching fix flow; covers bug fixes, output optimization, and requirement changes. TRIGGER — /revise / there's a bug here / the result is wrong / doesn't match expectations / this output needs optimizing / a review found a violation to fix. ｜ 诊断 spec→plan→exec 产出与预期的偏差根因（定义问题 / 实现偏离 / 需求变更），按分类走对应修正流程；覆盖修 bug、产出优化、需求变更三类场景。常见触发：用户输入 `/revise`、"这里有 bug"、"结果不对"、"和预期不符"、"这个产出需要优化"、review 发现违规需修复。
argument-hint: <问题或优化诉求描述>
---

# 产出修订（Revise）：诊断 → 定向修正 → 回归验证

对 spec→plan→exec 流水线产出与预期的偏差做**根因归类 → 定向修正 → 回归验证**，覆盖修 bug、产出优化、需求变更三类场景。所有 review 发现问题需修正时，统一走此流程。

> 仅处理"对既有产出的修正"。与对错无关的**纯新增需求**走 `/spec` → `/plan`，不进本流程。

## 核心原则（兼硬约束）

1. **先诊断再修正**：禁止跳过归因直接改代码；诊断结果必须向用户展示并确认后才修
2. **三类归因**：每个问题必须归入 spec-defect / impl-defect / requirement-change 之一
3. **TDD 修正**：涉及代码修改时必须先有失败测试（Red）再改实现（Green），测试须能暴露 bug
4. **分层修复起点**：spec-defect 必先改 spec 再改代码（禁只改代码不改 spec）；requirement-change 必先用户确认新需求再动手
5. **修正闭环**：修正后必须验证——全量测试通过 + spec 合规 + 索引同步
6. **最小影响**：只改必须改的层，不借修正之名扩展功能或重构（额外需求走 `/spec` → `/plan`）
7. **Agent 隔离同 exec**：Test 不看实现，Impl 不看 spec，Review 只读不写
8. **输出中文**

## 三类归因

| 类型 | 含义 | 根因在哪层 | 修复起点 |
|---|---|---|---|
| **spec-defect** | spec/plan 没有正确描述预期行为 | 定义层 | 改 spec → 级联 plan → TDD 重新实现 |
| **impl-defect** | spec 正确，实现不符合 | 实现层 | 补测试(Red) → 改实现(Green) → 验证 |
| **requirement-change** | 用户实际需要与现有 spec 不同 | 需求层 | 确认新需求 → 改 spec → 级联 |

---

## 工作流

### 步骤 0：收集问题信息

**有参数**（`$ARGUMENTS` 非空）：直接使用用户传入的问题/优化描述。
**无参数**：向用户提问（一次 2-3 个）——预期行为是什么？实际行为是什么？在哪个场景/功能下出现？

### 步骤 1：读取配置 + 定位关联资产

`cat .bb-spec.yaml 2>/dev/null` 取 `docs_dir`（缺省 `.bb-spec/docs`），记作 `${DOCS_DIR}`，后续所有路径基于此值。读 `${DOCS_DIR}/spec/INDEX.md` 与 `${DOCS_DIR}/plan/INDEX.md`，据问题描述定位四层资产并全部读取：

| 资产 | 定位方式 | 目的 |
|---|---|---|
| spec 文件 | INDEX.md + 关键词匹配 | 确认"期望行为"的定义 |
| plan 文件 | INDEX.md + spec 溯源 | 确认"怎么做"的设计 |
| 实现代码 | plan 中的文件路径 / codegraph | 确认"实际做了什么" |
| 测试文件 | 测试目录 + 命名惯例 | 确认"验了什么" |

建立完整链路：**spec 说什么 → plan 怎么做 → 代码做了什么 → 测试验了什么**。

### 步骤 2：诊断归因

按决策树逐层判定：

```
1. spec 是否正确描述了预期行为？
   ├─ 否 → spec 规则本身有错误/遗漏/歧义？
   │   ├─ 是（spec 翻译需求时出错）→ spec-defect
   │   └─ 否（用户的实际需求变了）→ requirement-change
   └─ 是 →
2. plan 是否正确翻译了 spec？
   ├─ 否（plan 误读 spec）→ spec-defect
   └─ 是 →
3. 实现是否符合 plan + spec？
   ├─ 否 → impl-defect
   └─ 是 →
4. 测试是否覆盖了出问题的场景？
   ├─ 否（测试遗漏）→ impl-defect
   └─ 是（测试断言有误）→ impl-defect
```

**向用户展示诊断结果**（必须确认后才修正）：

```
## 诊断结果
- 归因：<spec-defect / impl-defect / requirement-change>
- 证据：spec 说<原文> / plan 说<原文> / 代码做了<实际行为> / 测试验了<覆盖情况>
- 结论：<一句话说明哪层出了什么问题>
- 影响范围：<受影响的文件/功能列表>
确认归因后开始修复？
```

**冲突分析简报**（代码行为与 spec 定义存在可争议分歧时，附在诊断后辅助用户判断方向；明确的实现 bug 无需此简报）：

```
## 冲突分析：<一句话描述>
| | 代码现状 | Spec 定义 |
|---|---|---|
| 行为 | <代码实际做了什么> | <spec 要求做什么> |
- 保留代码（改 Spec）：<理由——如代码已上线验证、覆盖了 spec 遗漏的边界、性能更优>
- 遵循 Spec（改代码）：<理由——如更贴合业务意图、更安全、当前代码是历史妥协>
- **建议**：<推荐方向> — <一句话理由>
- **代价**：<选该方向的改动范围与风险>
确认修复方向后开始修复？
```

### 步骤 3：按类型修复

**轻量修复判断**：进入修复前评估改动规模，**同时满足全部条件**时可向用户提议跳过 3-Agent 隔离直接修——归因为 impl-defect（spec/plan 无需变动）+ 改动 ≤ 1 个文件 ≤ 10 行 + 修复逻辑显而易见（拼写错误、off-by-one、条件取反）。

提议话术：`"这个修复只改 <文件>，约 <N> 行，是否跳过 3-Agent 隔离直接修？"`
- 同意 → 主 agent 直接 TDD 修复（仍须先补失败测试再改实现），跳过 3a/3b/3c 的 Agent 派发
- 拒绝或未回应 → 走标准流程

不满足上述条件时，**禁止提议跳过，直接走标准流程**。

#### 3a. spec-defect — 定义层出错，从 spec 起向下级联

1. **改 spec**：编辑 spec 文件修正规则（遵守 spec skill 变更判定：修改=编辑原文件，废弃=删文件 + 移除索引条目）
2. **检查 plan 影响**：需更新则改对应 plan 的业务规则/验证方式，无影响则跳过
3. **TDD 修复实现**：派 Test Agent（`bb-spec:test-engineer`）按修正后 spec 写/改测试→Red；派 Impl Agent（`bb-spec:impl-engineer`）改实现→Green；派 Review Agent（`bb-spec:spec-reviewer`）验证合规
4. **同步索引**：spec/plan 的 INDEX.md 如有变动则更新

#### 3b. impl-defect — spec 正确，只修实现层

1. 派 Test Agent 按被违反的 spec 规则写测试→Red（测试必须暴露 bug）
2. 派 Impl Agent 改代码→Green
3. 派 Review Agent 检查修复后代码 vs spec

#### 3c. requirement-change — 需求层变化，先确认再级联

1. **确认新需求**：与用户对话明确新预期行为（一次 2-3 个关键问题）
2. **更新 spec**：走 spec 变更流程（编辑/新增/删除 spec 文件 + 同步 INDEX.md）
3. **评估级联影响**：检查哪些 plan 和实现受影响，向用户展示范围
4. **级联修复**：按 3a 步骤 2-4 执行（改 plan → TDD 修实现 → Review 验证）

### 步骤 4：回归验证

1. **全量测试**：运行项目全量测试，确认无回归
2. **spec 合规**：检查修复是否引入新的 spec 违规
3. **索引同步**：确认 spec/plan INDEX.md 与文件实际状态一致
4. **本地 commit**：上述通过后做一次**本地** commit——先 `git branch --show-current` 确认分支（**在 main 上则跳过**并提示按 git-workflow 先建分支），只提交本次涉及文件（spec/plan/实现/测试），message 遵循仓库历史风格（先 `git log --oneline -10`）、不硬编码类型前缀，**仅本地、不自动 push**

### 步骤 5：完成简报

```
## 修订完成简报
- 归因：<spec-defect / impl-defect / requirement-change>
- 根因：<一句话>
- 修改文件：spec / plan / 实现 / 测试（各列路径，无则省略）
- 测试结果：✅ 全部通过 / ❌ 仍有失败（列出）
- 回归检查：✅ 无回归 / ⚠️ <说明>
- 待解决：<残留问题列表，无则"无">
- 下一步：<如"运行 /review 复查" / "无">
```

---

## Agent 隔离规则

修复阶段复用 exec 的三 Agent 隔离，信息边界不变：

| Agent | 可见 | 不可见 |
|---|---|---|
| Test Agent | 修正后的 spec 规则 + 验证预期 + 项目测试惯例 | 函数清单、实现路径、现有实现代码 |
| Impl Agent | 函数清单 + 文件路径 + 成品定义（如有）+ 测试文件 + 项目约束 | spec 原文 |
| Review Agent | spec 规则 + 验证预期 + 所有变更文件 | 不修改任何文件 |
