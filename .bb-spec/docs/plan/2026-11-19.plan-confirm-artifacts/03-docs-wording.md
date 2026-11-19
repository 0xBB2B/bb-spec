---
name: docs-wording
description: 五份 README、插件描述、/prd 弹窗选项说明改成"PRD 批准需求；新技术先问；技术变更再确认一次"，并全量搜旧说法
---
# README、插件描述、/prd 弹窗说法

## 目标
所有对外说明和 `/prd` 弹窗说明都写成：读完 PRD 批准需求；要用新技术时先问；plan 新增或修改表结构、接口、数据格式、配置时再确认一次，其余自动跑完。旧说法"只批准一次"等在指定范围内搜不到。

## 业务规则（来源：PRD public-wording）
- `/prd` 确认弹窗「已阅读，通过并执行」的说明改成「成品定义」A 的文字（用户在原型里确认过）；弹窗问题、另外两个选项和各选项的后续行为不变。
- 五份 README（简体、繁体、英、日、韩）介绍 `/prd`、`/plan` 和流水线图的地方说法一致；五份在同一次改动里一起改（AGENTS.md 项目约束）。
- 流水线图 `/prd` 下面的括号标注去掉（和主页去掉 `/prd` 节点标签一致），`→Review` 保持原来的列位；图例补上技术变更。
- marketplace 和 plugin.json 的插件描述不用"一次批准"概括 `/prd`。
- 在 `plugins/`、五份 README、`site/`、`DESIGN.md`、`.claude-plugin/marketplace.json` 里，下面「验证方式」列的旧说法都搜不到；已合并的 PRD（`.bb-spec/docs/prd/`）不在搜索范围内。

## 涉及文件
- `plugins/bb-spec-workflow/skills/prd/references/write-files.md` — 修改
- `README.md`、`README.zh-TW.md`、`README.en.md`、`README.ja.md`、`README.ko.md` — 修改
- `.claude-plugin/marketplace.json`、`plugins/bb-spec-workflow/.claude-plugin/plugin.json` — 修改
- `tests/new-tech-workflow.test.sh` — 修改（测试阶段处理）
- `tests/plan-confirm-wording.test.sh` — 新建（测试阶段处理）

## 成品定义

**A. `write-files.md` 步骤 9 选项表第一行（原第 43 行）整行替换为：**

```
| 已阅读，通过并执行（标推荐） | 提交 PRD，然后自动跑 /plan → /exec → /doc-update；要引入新技术时先问你，plan 里新增或修改表结构、接口、数据格式、配置时再请你确认一次，遇到设计判断时也会停下问你 | 进步骤 10 |
```

**B. 五份 README，每份改 6 处。** 定位按"含哪句原文的那一行"，整行替换。

B1. 阶段一览表 `/prd` 行（含 `` | `/prd` | `` 开头的那行）：

- README.md：`| `/prd` | 质疑→澄清→拆解,落盘 PRD + AGENTS.md 后请你读完批准需求,通过就自动跑 plan → exec → doc-update;要用新技术、plan 有技术变更时再停下请你确认 | 新需求开工、要改已合并功能的行为 |`
- README.zh-TW.md：`| `/prd` | 質疑→釐清→拆解,落盤 PRD + AGENTS.md 後請你讀完核可需求,核可就自動跑 plan → exec → doc-update;要用新技術、plan 有技術變更時再停下請你確認 | 新需求開工、要改已合併功能的行為 |`
- README.en.md：`| `/prd` | Challenge → clarify → break down; writes the PRD + AGENTS.md for you to read and approve the requirement, then it auto-runs plan → exec → doc-update, pausing for your confirmation on new tech or plan tech changes | New requirement, or changing how a merged feature behaves |`
- README.ja.md：`| `/prd` | 質疑→明確化→分解、PRD + AGENTS.md を書き出し、読んで要件を承認すると plan → exec → doc-update を自動実行;新技術の導入や plan の技術変更がある時は止まって確認を求める | 新規要件の着手時、マージ済み機能の振る舞いを変える時 |`
- README.ko.md：`| `/prd` | 질의→명확화→분해, PRD + AGENTS.md를 작성한 뒤 읽고 요구사항을 승인하면 plan → exec → doc-update를 자동 실행; 새 기술 도입이나 plan 의 기술 변경이 있으면 멈추고 확인을 구함 | 새 요구사항 착수 시, 머지된 기능의 동작을 바꿀 때 |`

B2. 流水线图里 `/prd` 下面的括号标注行（含 `→Review` 的那行）：括号连同其中文字删掉，只留空格和 `→Review`，`→Review` 列位不变。README.md、README.zh-TW.md、README.ja.md、README.ko.md 是 20 个空格加 `→Review`；README.en.md 是 21 个空格加 `→Review`。

B3. 流水线图图例 `══►` 那一行：

- README.md：` ══► 自动衔接(引入新技术、plan 有技术变更或需设计裁决时停下)`
- README.zh-TW.md：` ══► 自動銜接(引入新技術、plan 有技術變更或需設計裁決時停下)`
- README.en.md：` ══► chained automatically (pauses for new tech, plan tech changes, or design calls)`
- README.ja.md：` ══► 自動で接続(新技術の導入、plan の技術変更、設計判断がある時は停止)`
- README.ko.md：` ══► 자동 연결(새 기술 도입, plan 의 기술 변경, 설계 판단이 있으면 멈춤)`

B4. `/prd` 详细说明第一条（含"质疑前置"或对应语言的那一行）里，把旧的后半句替换掉，前半句不动：

- README.md：`落盘 PRD 后弹窗请你读完确认,用户**只批准这一次**,通过后自动跑完 `/plan` → `/exec` → `/doc-update`` → `落盘 PRD 后弹窗请你读完**批准需求**,通过后自动跑 `/plan` → `/exec` → `/doc-update`;要引入新技术时先问你,plan 里新增或修改表结构、接口、数据格式、配置时再请你确认一次`
- README.zh-TW.md：`落盤 PRD 後彈窗請你讀完確認,使用者**只核可這一次**,核可後自動跑完 `/plan` → `/exec` → `/doc-update`` → `落盤 PRD 後彈窗請你讀完**核可需求**,核可後自動跑 `/plan` → `/exec` → `/doc-update`;要引入新技術時先問你,plan 裡新增或修改資料表結構、介面、資料格式、設定時再請你確認一次`
- README.en.md：`once the PRD is written a prompt asks you to read and confirm it, you **approve once**, then `/plan` → `/exec` → `/doc-update` run on their own` → `once the PRD is written a prompt asks you to read it and **approve the requirement**, then `/plan` → `/exec` → `/doc-update` run on their own; new tech is confirmed with you first, and any new or changed table schema, API, data format or config in the plan is confirmed once more`
- README.ja.md：`PRD を書き出した後、ダイアログで読了と承認を確認、ユーザーの**承認はこの 1 回だけ**、承認後は `/plan` → `/exec` → `/doc-update` を自動で最後まで実行` → `PRD を書き出した後、ダイアログで読了と**要件の承認**を確認、承認後は `/plan` → `/exec` → `/doc-update` を自動実行;新技術を導入する時は先に確認し、plan でテーブル構造・API・データ形式・設定を追加または変更する時はもう一度確認を求める`
- README.ko.md：`PRD 작성 후 대화상자로 읽었는지와 승인 여부를 확인하며, 사용자는 **이 한 번만 승인**하고, 승인 후 `/plan` → `/exec` → `/doc-update`까지 자동 실행` → `PRD 작성 후 대화상자로 읽었는지와 **요구사항 승인** 여부를 확인하며, 승인 후 `/plan` → `/exec` → `/doc-update`를 자동 실행; 새 기술을 도입할 때는 먼저 묻고, plan 에서 테이블 구조·API·데이터 형식·설정을 추가하거나 변경할 때 한 번 더 확인을 구함`

B5. `/plan` 详细说明第一条里的声明式产物括号：

- README.md：`(DDL / API 契约 / 配置)` → `(DDL / API 契约 / 数据格式 / 配置)`
- README.zh-TW.md：`(DDL / API 契約 / 設定)` → `(DDL / API 契約 / 資料格式 / 設定)`
- README.en.md：`(DDL / API contracts / config)` → `(DDL / API contracts / data formats / config)`
- README.ja.md：`(DDL / API 契約 / 設定)` → `(DDL / API 契約 / データ形式 / 設定)`
- README.ko.md：`(DDL / API 계약 / 설정)` → `(DDL / API 계약 / 데이터 형식 / 설정)`

B6. `/plan` 详细说明第二条（"由 `/prd` 自动调用"或对应语言开头的那一行）整行替换：

- README.md：`  - 由 `/prd` 自动调用;要**引入新技术**时在写 plan 前停下,逐项列出理由在一个弹窗里请你批准,批准即视为 version-policy 要求的授权;plan 新增或修改表结构、接口、数据格式、配置(技术变更)时,列出技术变更清单(每项带 `文件:行号` 指向成品定义)请你确认后再跑 `/exec`,没有技术变更就直接跑 `/exec``
- README.zh-TW.md：`  - 由 `/prd` 自動呼叫;要**引入新技術**時在寫 plan 前停下,逐項列出理由在一個彈窗裡請你核准,核准即視為 version-policy 要求的授權;plan 新增或修改資料表結構、介面、資料格式、設定(技術變更)時,列出技術變更清單(每項帶 `檔案:行號` 指向成品定義)請你確認後再跑 `/exec`,沒有技術變更就直接跑 `/exec``
- README.en.md：`  - Auto-invoked by `/prd`; when **new tech** is needed it stops before writing the plan, listing each item with its reasons in one prompt for your approval, and that approval counts as the authorization version-policy requires; when the plan adds or changes a table schema, API, data format or config (a tech change), it lists the tech changes (each with a `file:line` pointing at the final-form definition) for you to confirm before running `/exec`, and with no tech change it runs `/exec` straight away`
- README.ja.md：`  - `/prd` から自動呼び出し;**新技術の導入**が必要な時は plan を書く前に止まり、項目ごとに理由を挙げて一つのダイアログで承認を求め、承認は version-policy が要求する承認とみなす;plan がテーブル構造・API・データ形式・設定を追加または変更する時(技術変更)は、技術変更リスト(各項目に成果物定義を指す `ファイル:行番号` 付き)を出して確認を取ってから `/exec` を実行、技術変更がなければそのまま `/exec` を実行`
- README.ko.md：`  - `/prd`가 자동 호출; **새 기술 도입**이 필요하면 plan 을 쓰기 전에 멈추고 항목별 이유를 나열해 하나의 대화상자에서 승인을 구하며, 승인은 version-policy가 요구하는 승인으로 간주; plan 이 테이블 구조·API·데이터 형식·설정을 추가하거나 변경하면(기술 변경) 기술 변경 목록(각 항목에 산출물 정의를 가리키는 `파일:행번호` 포함)을 보여 주고 확인을 받은 뒤 `/exec`를 실행, 기술 변경이 없으면 바로 `/exec`를 실행`

**C. `.claude-plugin/marketplace.json` 里 bb-spec-workflow 的 description，把 `prd（质疑→澄清→拆解，一次批准落盘 PRD + AGENTS.md 项目约束）→ 自动 plan →` 替换为：**

```
prd（质疑→澄清→拆解，落盘 PRD + AGENTS.md 项目约束，用户批准需求）→ 自动 plan（新技术、技术变更先请用户确认）→
```

**D. `plugins/bb-spec-workflow/.claude-plugin/plugin.json` 的 description，把 `prd 需求入口（质疑→澄清→拆解，一次批准落盘 PRD + AGENTS.md 项目约束）→ 自动 plan 实施计划 →` 替换为：**

```
prd 需求入口（质疑→澄清→拆解，落盘 PRD + AGENTS.md 项目约束，用户批准需求）→ 自动 plan 实施计划（新技术、技术变更先请用户确认）→
```

## 函数清单
无过程式代码：产物全部是文档和描述文本，按「成品定义」A~D 原样替换。

## 协作关系
`/prd` 步骤 9 读 `write-files.md` 弹出确认弹窗；README 和插件描述只给人读。依赖 01（plan 规程的新行为）和 02（主页说法），说法以它们为准。

## 验证方式
- 测试入口：`bash tests/plan-confirm-wording.test.sh`（新建）；`bash tests/new-tech-workflow.test.sh`；`bash tests/readme-structure.test.sh`；`bash tests/validate.sh`。
- 测试输入：仓库里的上述文件。
- 预期结果：
- [ ] `write-files.md` 含成品定义 A 那一整行；`tests/new-tech-workflow.test.sh` 第 61 行断言的 `需要引入新技术或遇到设计判断时停下问你` 改为断言 `要引入新技术时先问你，plan 里新增或修改表结构、接口、数据格式、配置时再请你确认一次，遇到设计判断时也会停下问你`，并通过。
- [ ] 五份 README 各自含 B1、B3、B4 新文字、B5 新括号、B6 新行；含 `→Review` 的那行除空格外只有 `→Review`，且 `→Review` 前的空格数为 20（README.en.md 为 21）。
- [ ] marketplace.json、plugin.json 的描述含成品定义 C、D 的新片段，且仍是合法 JSON。
- [ ] 在 `plugins/`、`README.md`、`README.zh-TW.md`、`README.en.md`、`README.ja.md`、`README.ko.md`、`site/`、`DESIGN.md`、`.claude-plugin/marketplace.json` 中逐个 `grep -rF` 下列旧说法，均无命中：
  - 简体：`只批准这一次`、`只批准一次`、`唯一一次批准`、`一次批准`、`批准一次`、`读完确认一次`、`只有要引入新技术时才停下`、`只在需要引入新技术时停下`、`只有需要**引入新技术**时才停下`、`仅需引入新技术或需设计裁决时停下`
  - 繁体：`只核可這一次`、`唯一一次核可`、`讀完確認一次`、`一次核准`、`只有需要**引入新技術**時才停下`、`僅需引入新技術或需設計裁決時停下`
  - 英文：`approve once`、`the only approval`、`Stops only when new tech`、`stops only for new tech`、`it stops only when **new tech**`、`for a single approval`
  - 日文：`1 回承認`、`承認はこの 1 回だけ`、`唯一の承認`、`必要な時だけ止まり`、`新技術の導入や設計判断が必要な時のみ停止`、`一度で承認`
  - 韩文：`한 번 승인`、`이 한 번만 승인`、`유일한 승인`、`필요할 때만 멈추고`、`새 기술 도입이나 설계 판단이 필요할 때만 멈춤`、`한 번에 승인`
- [ ] `tests/readme-structure.test.sh` 照常通过（五份 README 章节结构一致）。
