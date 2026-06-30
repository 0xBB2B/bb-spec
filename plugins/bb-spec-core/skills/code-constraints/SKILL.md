---
name: code-constraints
description: 跨语言通用代码纪律——注释 WHY 不解释 WHAT、禁 spec 溯源注释、禁未要求的功能/抽象/防御、外科手术式改动、反历史包袱。触发：编写或审查实现/测试代码；被 impl-engineer/test-engineer/spec-reviewer 及 /revise 轻量修复显式加载。跳过：纯文档、纯配置、生成代码、vendor/node_modules。
user-invocable: false
---

# 代码纪律（跨语言通用）

适用：所有语言的代码新增 / 修改 / 审查。与 [[tdd-workflow]] 互补——TDD 管「怎么写」（Red-Green-Refactor 循环），本 skill 管「写成什么样」（代码内容本身的约束）。

> 核心：**任何写代码的子代理（test-engineer / impl-engineer）开工前必须加载本 skill，任何审查代码的子代理（spec-reviewer）合规校验时必须把本 skill 当作和 spec 规则同级的合规项。**

## 0. 触发与跳过

**TRIGGER**：编写或审查实现 / 测试代码；test-engineer / impl-engineer / spec-reviewer / `/revise` 轻量修复显式调用。
**SKIP**：纯文档、纯配置、生成代码、vendor/node_modules。

---

## 1. 注释纪律

### R1.1 注释 WHY，不解释 WHAT

代码读得懂 WHAT（命名 + 控制流就够了），注释只解释读者**看不出来的 WHY**——隐藏约束、微妙不变量、特定 bug 的绕道、违反直觉的写法。

- ✅ `// 这里禁用 timeout，否则会触发 PostgreSQL 12 的 prepared-statement bug`
- ❌ `// 调用 saveUser 保存用户`（命名已说明）
- ❌ `// 此函数被 X 流程调用 / 为 issue #123 添加`（属 PR description，必然 rot）

### R1.2 禁 spec 溯源注释

**不得**在代码注释里写 spec 路径 / 规则编号 / 章节名作为溯源标记。

- ❌ `// 实现 spec foo 规则 3`
- ❌ `// 加载（spec system-configs）`
- ❌ `// 读出（spec platform/system-configs R 类）`
- ❌ `// 见 .bb-spec/docs/spec/admin/mcp-tool-coverage-boundary 规则 1`

理由（三点都成立）：
1. **属性错位**——spec 溯源是 commit message / PR description 的事，不属于代码注释。
2. **必然 rot**——spec 路径、规则编号、章节名会随着 spec 演化而改名、拆分、合并；没人会回头同步注释里的引用。
3. **零信息量**——去掉这类括号注释，紧邻的代码照样读懂；留着只是噪声。

需要追溯实现源自哪条 spec？走 `git blame` + commit message。

---

## 2. 反过度设计

### R2.1 禁未要求的功能

只实现需求清单（plan / spec / 用户指令）里写明的功能。**禁** "顺手加个 X 反正可能用得上"。

### R2.2 禁过度抽象

- 禁单实现 interface（只有一个实现却包一层 interface）
- 禁为想象中的将来设计（"以后可能要支持 Y，所以现在抽出个 BaseHandler"）
- 三行类似代码 > 一个过早抽象——重复出现第三次再考虑抽象

### R2.3 禁过度防御

只在系统边界（用户输入、外部 API、跨进程调用）做校验与错误处理。**内部代码相信内部代码**：

- ❌ 内部函数对所有参数 `if x == nil { return err }` 兜底
- ❌ 为"理论上不会发生"的场景加 fallback
- ❌ 已被语言 / 框架保证的不变量再校验一遍

「真实可能发生的故障路径」与「不可能场景的冗余防御」边界判断不清时停下问用户。

---

## 3. 外科手术式改动

### R3.1 只动必须动的

只改本次需求**必须**改的代码。**禁**：
- 顺手优化邻近无关代码
- 顺手重构变量名 / 提取函数 / 调整目录结构
- 顺手统一代码风格

发现可优化的相邻代码 → 提出后续单独处理，**不混入本次改动**。

### R3.2 清孤立残留

本次改动**导致**的不再使用的 import / 变量 / 函数必须清掉。但**不清**本次改动无关的、原本就死的代码（那是另外一次「反历史包袱」清理的事，见 R4）。

---

## 4. 反历史包袱

### R4.1 不留过渡式表述

**禁**在新写的代码 / 文档里出现：
- "保留原 X 以兼容"
- "// DEPRECATED：新代码请用 Y"
- "v1 / v2 双轨并列"
- "暂时保留，后续清理"
- 无负责人 / 无截止日期的 TODO

发现想写这类表述 → 停下问用户：要么彻底替换，要么不动。

### R4.2 顺手清死代码（仅本次改动文件附近）

修改某文件时，若顺手发现该文件 / 紧邻文件里有死代码（无 import、无引用、无人调用的过时实现），**可以**清掉——但仅限本次改动文件附近的孤立残留。跨模块的大范围死代码清理走 `/revise` 单独走一次。

---

## 5. 落地形式

### 写代码前（test-engineer / impl-engineer / `/revise` 主 agent 直接修）

1. 调用 `Skill code-constraints`（即本 skill），把 R1-R4 装入工作记忆。
2. 写代码过程中持续对照——尤其是：要写注释时检查 R1，要新增一层抽象时检查 R2，发现可优化邻近代码时检查 R3，发现旧代码遗留时按 R4 决策。
3. 产出报告时，无需重述本 skill 内容；只在确实违反时如实说明并解释为什么不得不违反。

### 审查代码时（spec-reviewer）

1. 调用 `Skill code-constraints`，把 R1-R4 与 spec 规则同级纳入合规项。
2. 逐项核对变更文件：违反 R1-R4 与违反 spec 规则**同等报告**——给出 `file:line` 与具体违反的规则编号。
3. 不修改文件——发现问题走 `/revise` 修复。

---

## 6. 与其他 skill 的边界

| Skill | 管什么 | 与本 skill 关系 |
|---|---|---|
| [[tdd-workflow]] | Red-Green-Refactor 循环本身 | 互补：TDD 管"怎么写"，本 skill 管"写成什么样" |
| [[golang-constraints]] / [[vue-constraints]] 等 | 语言/栈绑定的特定约束 | 不重叠：本 skill 跨栈，栈特异约束归各自 |
| `/review` 多 finder（code-quality / simplicity / robustness） | 评审「预先未声明的代码问题」 | 不重叠：本 skill 是「预先声明的输入约束」（写之前 / 审之中），`/review` 在功能完成后 |
