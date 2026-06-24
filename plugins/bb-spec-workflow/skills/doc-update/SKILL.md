---
name: doc-update
description: 全仓 spec/文档/代码一致性维护——扫描仓库内 spec、README、CLAUDE.md、plan 与代码，找出描述与实现的漂移；默认改 spec/文档让其追平代码现态，代码明显违背硬约束或存在不合理设计时停下用 AskUserQuestion 请用户裁决再改代码；落盘前汇总展示、过程中 INDEX 同步维护。触发：/doc-update、文档和代码不一致、spec 跟代码对不上、批量同步 spec 与现状、维护一下文档。跳过：还没有 spec 可对照（→/init-spec）、单点 bug 或定向修复（→/revise）、纯新增需求（→/spec→/plan）。
argument-hint: [可选：限定范围，如某分区名 / 某目录 / 某 spec 文件]
---

# Doc-Update 全仓文档一致性维护

把仓库内 **spec、README、CLAUDE.md、plan、代码内说明性文字** 跟代码现态对齐：默认认为「代码是事实」，spec/文档追平代码；**仅当代码明显违背硬约束或存在不合理设计**时停下来用 `AskUserQuestion` 请用户裁决，确认后才改代码。

> 与相邻 skill 的边界
> - `/init-spec`：从零反向提炼 spec（无 spec 时用）；本 skill 维护已存在的 spec
> - `/revise`：单点 bug 或定向修复（用户带具体偏差描述）；本 skill 做全仓批量同步
> - `/review` 内的 `review-doc-sync` 子代理：PR diff 范围的只读发现器；本 skill 是全仓 + 落盘修改
> - `/spec`：新增需求规则；本 skill 不引入新规则、只追平既有规则与现态的漂移（**例外**：发现代码已稳定执行但 spec 未覆盖的硬约束级行为，可补一条新 spec，但仍走"先展示再批准"流程）

## 核心原则（兼硬约束）

1. **代码是事实，文档追平代码**：默认方向是 spec/文档/INDEX 跟代码现态对齐；禁止凭文档单方面"想当然"反推代码该怎么写
2. **改码必须用户裁决**：本 skill 默认 **不动代码**；发现代码"明显不合理"才停下用 `AskUserQuestion` 请用户拍板，用户同意后转 `/revise` 走 TDD 流程，本 skill 不直接改实现
3. **批改前先汇总**：所有漂移分类列表 + 默认动作 + 待裁决项必须一次性展示，用户批准后才落盘，禁逐条边问边改打断节奏
4. **冲突不自决**：spec 内部互斥（两份 spec 互相打架）或同一 README 段落与多份 spec 冲突时，一律抛 `AskUserQuestion`，禁主 agent 私自选边
5. **最小影响**：只改"确实漂移"的那几行/几条，不借维护之名整理排版、调整标题层级、清理无关 TODO
6. **INDEX 同步**：任何 spec 文件的新增/删除/重命名/description 变更，必须同步更新 `${DOCS_DIR}/spec/INDEX.md`
7. **不碰 plan 业务规则**：plan 是点状产物，若发现 plan 与实现偏离，挂回 `/revise`，本 skill 仅可修 plan 中的 INDEX / 文件清单类元数据
8. **纯净现态**：spec/文档只写当前代码已在执行的行为；禁加"原来是 X、现在改为 Y"或"已废弃保留兼容"类过渡式表达——废弃直接删
9. **语言跟随用户**：正文用用户工作语言（默认中文），标识符/API 名/错误码保持英文

---

## 工作流

### 步骤 0：读取配置 + 前置检查

```bash
cat .bb-spec.yaml 2>/dev/null
```

取 `base_dir`（缺省 `.bb-spec`），`${DOCS_DIR}` = `<base_dir>/docs`。

前置存在性检查：

```bash
ls ${DOCS_DIR}/spec/INDEX.md 2>/dev/null
```

- **INDEX.md 不存在或为空** → 提示"项目尚未生成 spec，请先跑 `/init-spec` 反向提炼后再来 `/doc-update`"并退出
- **存在** → 进入步骤 1

若 `$ARGUMENTS` 非空（用户限定了范围），把它作为 **本次扫描的过滤器**——只处理参数指定的分区/目录/文件相关的漂移。

### 步骤 1：盘点资产 + 建立"代码侧索引"

主 agent 自做，**禁派子代理**（避免来回传上下文）：

1. **读全部 spec**：递归 `${DOCS_DIR}/spec/` 下所有 `.md`，记录每条规则的 `name / 分区 / description / 约束 / 例子（含 file:line）`
2. **读项目根文档**：`README.md` / `README.zh.md` / `CLAUDE.md` / `CONTRIBUTING.md` / `ARCHITECTURE.md` 等存在者
3. **读 plan INDEX**：`${DOCS_DIR}/plan/INDEX.md`（如存在），仅取文件清单，不下钻 plan 内容
4. **建立代码侧索引**：按 spec 例子里的 `file:line` 反查当前代码 → 对比该位置/相邻函数当前的行为；codegraph 可用则 `codegraph_explore <规则相关 symbol>` 拉真实调用与源码，否则 `grep -rnE` + 读相关文件
5. **采集横切信号**：错误码格式、命名约定、版本号、env var、CLI flag、配置 key、超时阈值、默认行为等"易飘移"的硬约束逐一抽查

输出回显：spec 数量 / 分区清单 / 已读根文档 / 涉及代码文件数（仅数字与文件列表，不展开内容）。

### 步骤 2：漂移检测 + 分类

逐条 spec 比对代码与文档，把发现挂入下列六类。**每条发现必须落到具体 `file:line` + 一句话"漂移点"**，无定位的"感觉不一致"丢弃。

| 编号 | 类别 | 含义 | 默认动作 |
|---|---|---|---|
| A | **spec-stale** | spec 描述与代码现态不符，但代码看起来合理 | 改 spec 追平代码 |
| B | **doc-stale** | README/CLAUDE.md/根文档引用了被改名、删除、行为变更的函数/路径/命令/配置项 | 改文档追平代码 |
| C | **code-violation** | 代码**明显**违背 spec 的硬约束（如错误码格式、命名约定、安全 invariant），且无合理理由 | **AskUserQuestion** → 用户同意改码 → 挂 `/revise` |
| D | **spec-conflict** | 两份及以上 spec 内部互斥 / 同一文档段落同时与多条 spec 冲突 | **AskUserQuestion** 让用户选保留哪份 |
| E | **orphan-index** | INDEX.md 条目与实际 spec 文件不一致（缺条目 / 残留条目 / description 不同步） | 改 INDEX 追平实际文件 |
| F | **uncovered-rule** | 代码已稳定执行一条 spec 未覆盖的硬约束级行为，且非框架自带保证 | 默认补一条新 spec；用户在步骤 3 可选"跳过"或"调整为 C 类" |

**何为"明显不合理"（C 类高线）**：仅当满足以下任一项才升级 C，否则一律降为 A，让 spec 追平：

- 代码违反硬安全 invariant（如硬编码密钥、SQL 拼接、明文存密码）
- 代码违反单一来源约束（如时间戳精度、错误码格式跨模块不一致）
- 代码存在明显死路（不可达分支、永远 false 的判定、显然 off-by-one）
- 代码与同仓库其余实现风格严重背离且无注释解释（如其它 9 处都用 `errors.Is`，此处独用字符串比对）

**降级守则**：
- 性能/可读性/口味偏好 → 不算"明显不合理"，归 A
- 注释数量/风格 → 归 `/review` 的 code-quality 域，本 skill 不管
- "看起来可以更优雅" → 归 A 或丢弃

### 步骤 3：汇总展示 + 批准

把检测结果一次性输出，分类汇总，每条带"漂移点 + 提议动作"：

```
## /doc-update 漂移清单（共 N 条）

### A. spec-stale（X 条，默认改 spec）
- [分区/name] spec 第 Y 行说"超时 5s" → 代码 path/to/file.go:42 实际为 10s
  → 改 spec："超时 10s"
- ...

### B. doc-stale（X 条，默认改文档）
- README.md 第 Z 行引用 `oldFunc()` → 已重命名为 `newFunc()`（commit abc1234）
  → 改 README
- ...

### C. code-violation（X 条，需用户裁决）
- [分区/name] 硬约束「错误码 A-BBB-CCCC」→ path/to/file.go:88 返回 `"bad request"`
  → 提议：改代码遵循 spec（走 /revise）

### D. spec-conflict（X 条，需用户裁决）
- spec/auth.md（超时 5s）vs spec/service.md（超时 10s）→ 同一信号
  → 需用户选保留哪份

### E. orphan-index（X 条，默认改 INDEX）
- INDEX.md 仍引用已删除的 spec/old-rule.md
  → 移除条目

### F. uncovered-rule（X 条，默认补 spec）
- 代码已稳定执行：所有 handler 必经 ctx.WithTimeout（grep 命中 14 处）
  → 提议补 spec/observability/handler-timeout.md

—— 待裁决类别（C/D）逐条用 AskUserQuestion；A/B/E/F 默认动作请确认整体批准。
```

之后：

1. **C/D 类逐条 `AskUserQuestion`**：把"漂移点 / 候选方向 / 各方向代价"做成选项让用户选；C 类选项至少含「改代码（走 /revise）」「改 spec（认可代码现态）」「跳过本条」；D 类至少含「保留 spec X」「保留 spec Y」「合并为一条」「跳过」
2. **A/B/E/F 整体批准**：一次 `AskUserQuestion` 让用户选「全部批准 / 逐条裁决 / 取消」；"逐条裁决"模式下退化为对每条单独问

未获明确批准的条目 **一律不动**。

### 步骤 4：应用修改

按批准结果落盘，遵守：

1. **改 spec 文件**：用 `Edit` 精准替换段落；保留 frontmatter；不动无关行；超 100 行的 spec 不在本 skill 内拆，提示用户后续走 `/spec` 拆解
2. **改 INDEX.md**：新增/删除条目按分区字母序插入/移除；description 同步对应文件 frontmatter
3. **改 README/CLAUDE.md**：精准替换被引用的旧 symbol / 路径 / 命令；语言保留与原文一致
4. **新增 spec（F 类）**：用与 `/spec` / `/init-spec` 一致的模板（`目的 / 逻辑 / 约束 / 例子 / 验收`），落 `${DOCS_DIR}/spec/<分区>/<name>.md`，例子末尾标注 `来源：file:line`，同步 INDEX
5. **C 类已批准改码项**：本 skill **不直接改实现**，而是产出一份"挂单清单"（每条含 `分区/规则 / 涉及文件 / 期望行为 / 不符点 / 建议测试切入`），让用户复制给 `/revise`
6. **不允许的动作**：改 plan 文件正文、改测试、改 commit 历史、动 git、改任何 .bb-spec 之外的代码（C 类挂回 `/revise`）

每改一处先回显简短行：`✏️ ${file}: <一句话变更>`，便于用户中途叫停。

### 步骤 5：回归校验

落盘后主 agent 自查：

1. **INDEX 闭环**：`ls ${DOCS_DIR}/spec/**/*.md` 全部出现在 INDEX；INDEX 无残留条目
2. **frontmatter 一致**：被改过的 spec 的 `description` 与 INDEX 一行简介保持一致
3. **链接可达**：被改过的 README/CLAUDE.md 里引用的相对路径真实存在
4. **未引入跨文档引用**：被改过的 spec 不出现"详见 X.md / 参考 Y.md"
5. **代码未被本 skill 改动**：`git diff --stat -- <非 spec/非文档路径>` 期望为空（C 类挂回 /revise 由用户后续触发）

任何一项不通过 → 当场修，无法当场修 → 列入完成简报"待处理"。

### 步骤 6：完成简报

```
## /doc-update 完成简报

- 范围：<全仓 / 限定参数 $ARGUMENTS>
- 检测漂移：A/B/C/D/E/F 各 N 条
- 已落盘：
  - spec 编辑 X 处（<分区/name> ×N）
  - INDEX 同步 Y 条
  - 根文档编辑 Z 处（README/CLAUDE.md/…）
  - 新增 spec K 条（F 类）
- 待用户后续处理：
  - C 类 → 走 /revise（清单见上方挂单）
  - D 类未裁决 J 条（如有）
- 回归校验：✅ 全部通过 / ⚠️ 待处理 <说明>
- 下一步建议：
  - C 类挂单 → `/revise` 逐条修
  - 若新增/调整规则 → `/plan` 重生成相关实施计划
  - 落地 commit → `/git-push-pr` 走推送 PR 流程
```

> 本 skill 不自动 commit、不自动 push。所有改动停在工作区，由用户决定何时提交。

---

## 与其它 skill 的串联

- **上游**：`/init-spec`（首次反向提炼）→ `/spec`（持续新增规则）→ `/plan` + `/exec` 实施 → 长期演进后跑 `/doc-update` 做一致性体检
- **下游**：`/doc-update` 产出的 C 类挂单 → `/revise` 逐条 TDD 修码；落地后 → `/git-push-pr` 推送

```
[实施已落地的项目]
  ↓
/doc-update（扫漂移、改 spec/文档，挂出改码清单）
  ↓
/revise（逐条修码、跑 TDD）
  ↓
/git-push-pr（推送 PR）
```
