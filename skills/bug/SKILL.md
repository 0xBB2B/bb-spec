---
name: bug
description: 诊断 spec→plan→exec 产出的 bug 根因（定义问题 / 实现偏离 / 需求变更），按分类走对应修复流程。常见触发：用户输入 `/bug`、"这里有 bug"、"结果不对"、"和预期不符"、review 发现违规需修复。
user-invocable: true
argument-hint: <bug 描述>
---

# Bug 诊断与修复

对 spec→plan→exec 流水线产出的问题做**根因归类 → 定向修复 → 回归验证**。所有 review 发现 bug 需修复时，统一走此流程。

## 核心原则

1. **先诊断再修复**：禁止跳过归因直接改代码
2. **三类归因**：每个 bug 必须归入 spec-defect / impl-defect / requirement-change 之一
3. **修复闭环**：修复后必须验证（测试通过 + spec 合规）
4. **最小影响**：只改必须改的层，不借修 bug 之名扩展功能或重构
5. **TDD 修复**：涉及代码修改时必须先有失败测试再改实现

## Bug 三类归因

| 类型 | 含义 | 根因在哪层 | 修复起点 |
|---|---|---|---|
| **spec-defect** | spec/plan 没有正确描述预期行为 | 定义层 | 改 spec → 级联 plan → TDD 重新实现 |
| **impl-defect** | spec 正确，实现不符合 | 实现层 | 补测试(Red) → 改实现(Green) → 验证 |
| **requirement-change** | 用户实际需要与现有 spec 不同 | 需求层 | 确认新需求 → 改 spec → 级联 |

---

## 工作流

### 步骤 0：收集 bug 信息

**有参数**（`$ARGUMENTS` 非空）：直接使用用户传入的 bug 描述。

**无参数**：向用户提问（一次 2-3 个问题）：
- 预期行为是什么？
- 实际行为是什么？
- 在哪个场景/功能下出现？

### 步骤 1：读取项目配置 + 定位关联资产

```bash
cat .bb-spec.yaml 2>/dev/null
```

有 `docs_dir` → 用其值作为基础路径；文件不存在或无该字段 → 默认 `.bb-spec/docs`。后续所有路径基于此值。

```bash
cat ${DOCS_DIR}/spec/INDEX.md 2>/dev/null
cat ${DOCS_DIR}/plan/INDEX.md 2>/dev/null
```

根据 bug 描述定位四层资产：

| 资产 | 定位方式 | 目的 |
|---|---|---|
| spec 文件 | INDEX.md + 关键词匹配 | 确认"期望行为"的定义 |
| plan 文件 | INDEX.md + spec 溯源 | 确认"怎么做"的设计 |
| 实现代码 | plan 中的文件路径 / codegraph | 确认"实际做了什么" |
| 测试文件 | 测试目录 + 命名惯例 | 确认"验了什么" |

全部读取，建立完整链路：**spec 说什么 → plan 怎么做 → 代码做了什么 → 测试验了什么**。

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
4. 测试是否覆盖了出 bug 的场景？
   ├─ 否（测试遗漏）→ impl-defect
   └─ 是（测试断言有误）→ impl-defect
```

**向用户展示诊断结果**（必须确认后才修复）：

```
## Bug 诊断

- 归因：<spec-defect / impl-defect / requirement-change>
- 证据：
  - spec 说：<引用 spec 原文>
  - plan 说：<引用 plan 原文>
  - 代码做了：<实际行为>
  - 测试验了：<测试覆盖情况>
- 结论：<一句话说明哪层出了什么问题>
- 影响范围：<受影响的文件/功能列表>

确认归因后开始修复？
```

**冲突分析简报**（代码行为与 spec 定义存在可争议的分歧时，附在诊断后辅助用户判断修复方向；明确的实现 bug 无需此简报）：

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

#### 3a. spec-defect

定义层出错，必须从 spec 开始修，向下级联。

1. **改 spec**：直接编辑 spec 文件，修正规则描述。遵守 spec skill 的变更判定（修改 = 编辑原文件，废弃 = 删文件 + 移除索引条目）
2. **检查 plan 影响**：
   - plan 需更新 → 修改对应 plan 文件中的业务规则 / 验证方式
   - plan 无影响 → 跳过
3. **TDD 修复实现**：
   - 派 Test Agent（`subagent_type: "bb-spec:test-engineer"`）：根据修正后的 spec 写/改测试 → 确认 Red
   - 派 Impl Agent（`subagent_type: "bb-spec:impl-engineer"`）：改实现 → 确认 Green
   - 派 Review Agent（`subagent_type: "bb-spec:spec-reviewer"`）：验证合规
4. **同步索引**：spec/plan 的 INDEX.md 如有变动则更新

#### 3b. impl-defect

spec 正确，只需修实现层。

1. **补/改测试**：派 Test Agent 根据 spec 中被违反的规则写测试 → 确认 Red（测试必须暴露 bug）
2. **修复实现**：派 Impl Agent 改代码 → 确认 Green
3. **合规验证**：派 Review Agent 检查修复后的代码 vs spec

#### 3c. requirement-change

需求层变化，必须先确认新需求再级联。

1. **确认新需求**：与用户对话明确新的预期行为（一次 2-3 个关键问题）
2. **更新 spec**：走 spec 变更流程（编辑/新增/删除 spec 文件 + 同步 INDEX.md）
3. **评估级联影响**：检查哪些 plan 和实现受影响，向用户展示范围
4. **级联修复**：按 3a 的步骤 2-4 执行（改 plan → TDD 修实现 → Review 验证）

### 步骤 4：回归验证

修复完成后必须执行：

1. **全量测试**：运行项目全量测试，确认无回归
2. **spec 合规**：检查修复是否引入新的 spec 违规
3. **索引同步**：确认 spec/plan INDEX.md 与文件实际状态一致

### 步骤 5：完成简报

```
## Bug 完成简报

- 归因：<spec-defect / impl-defect / requirement-change>
- 根因：<一句话>
- 修改文件：
  - spec: <路径列表，无则省略>
  - plan: <路径列表，无则省略>
  - 实现: <路径列表>
  - 测试: <路径列表>
- 测试结果：✅ 全部通过 / ❌ 仍有失败（列出）
- 回归检查：✅ 无回归 / ⚠️ <说明>
- 待解决：<残留问题列表，无则写"无">
- 下一步：<建议操作——如"运行 /review 复查""无">
```

---

## Agent 隔离规则

修复阶段复用 exec 的三 Agent 隔离，信息边界不变：

| Agent | 可见 | 不可见 |
|---|---|---|
| Test Agent | 修正后的 spec 规则 + 验证预期 + 项目测试惯例 | 函数清单、实现路径、现有实现代码 |
| Impl Agent | 函数清单 + 文件路径 + 测试文件 + 项目约束 | spec 原文 |
| Review Agent | spec 规则 + 验证预期 + 所有变更文件 | 不修改任何文件 |

---

## 硬约束

- 诊断结果必须向用户展示并确认后才修复
- impl-defect 修复必须先有失败测试再改实现（TDD）
- spec-defect 必须先改 spec 再改代码，禁止只改代码不改 spec
- requirement-change 必须用户确认新需求后再动手
- 修复范围不超出 bug 影响范围，不借修 bug 之名加功能
- Agent 隔离规则同 exec（Test 不看实现，Impl 不看 spec，Review 只读）
- 输出中文

---

## 反面案例

- ❌ 不诊断就改代码——可能改错层、治标不治本
- ❌ impl-defect 却跳过测试直接改实现——无法验证 bug 确实被修复
- ❌ spec 有问题却只改实现——下次生成代码仍会重现同样的错误
- ❌ 需求变了却只改代码不改 spec——spec 与实现脱节，后续开发会混乱
- ❌ 修 bug 时顺手加新功能——额外需求走 `/spec` → `/plan`
- ❌ 不跑回归就宣布完成——可能修一个 bug 引入新 bug
- ❌ 归因未经用户确认就开始修——用户可能有不同判断
