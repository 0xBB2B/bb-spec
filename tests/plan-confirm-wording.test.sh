#!/usr/bin/env bash
# /prd 确认弹窗、五份 README、流水线图、插件描述里的批准说法一致，旧说法清除
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." >/dev/null && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

has() {
  local file="$1" text="$2"
  if [[ ! -r "$ROOT/$file" ]]; then fail "读不到 ${file}"; return; fi
  if grep -qF -- "$text" "$ROOT/$file"; then pass; else fail "${file} 缺少：${text}"; fi
}

lacks_in() {
  local text="$1"; shift
  local rc=0
  grep -rqF -- "$text" "$@" 2>/dev/null || rc=$?
  case "$rc" in
    0) fail "不应含：${text}" ;;
    1) pass ;;
    *) fail "读不到搜索范围" ;;
  esac
}

echo "[write-files 弹窗说明]"
has plugins/bb-spec-workflow/skills/prd/references/write-files.md '| 已阅读，通过并执行（标推荐） | 提交 PRD，然后自动跑 /plan → /exec → /doc-update；要引入新技术时先问你，plan 里新增或修改表结构、接口、数据格式、配置时再请你确认一次，遇到设计判断时也会停下问你 | 进步骤 10 |'

echo "[README 新文字]"
has README.md '落盘 PRD + AGENTS.md 后请你读完批准需求,通过就自动跑 plan → exec → doc-update;要用新技术、plan 有技术变更时再停下请你确认'
has README.md ' ══► 自动衔接(引入新技术、plan 有技术变更或需设计裁决时停下)'
has README.md '落盘 PRD 后弹窗请你读完**批准需求**,通过后自动跑 `/plan` → `/exec` → `/doc-update`;要引入新技术时先问你,plan 里新增或修改表结构、接口、数据格式、配置时再请你确认一次'
has README.md '(DDL / API 契约 / 数据格式 / 配置)'
has README.md '要**引入新技术**时在写 plan 前停下,逐项列出理由在一个弹窗里请你批准'
has README.md '列出技术变更清单(每项带 `文件:行号` 指向成品定义)请你确认后再跑 `/exec`,没有技术变更就直接跑 `/exec`'

has README.zh-TW.md '請你讀完核可需求,核可就自動跑 plan → exec → doc-update;要用新技術、plan 有技術變更時再停下請你確認'
has README.zh-TW.md ' ══► 自動銜接(引入新技術、plan 有技術變更或需設計裁決時停下)'
has README.zh-TW.md '落盤 PRD 後彈窗請你讀完**核可需求**,核可後自動跑 `/plan` → `/exec` → `/doc-update`;要引入新技術時先問你,plan 裡新增或修改資料表結構、介面、資料格式、設定時再請你確認一次'
has README.zh-TW.md '(DDL / API 契約 / 資料格式 / 設定)'
has README.zh-TW.md '要**引入新技術**時在寫 plan 前停下,逐項列出理由在一個彈窗裡請你核准'
has README.zh-TW.md '列出技術變更清單(每項帶 `檔案:行號` 指向成品定義)請你確認後再跑 `/exec`,沒有技術變更就直接跑 `/exec`'

has README.en.md 'writes the PRD + AGENTS.md for you to read and approve the requirement, then it auto-runs plan → exec → doc-update, pausing for your confirmation on new tech or plan tech changes'
has README.en.md ' ══► chained automatically (pauses for new tech, plan tech changes, or design calls)'
has README.en.md 'once the PRD is written a prompt asks you to read it and **approve the requirement**, then `/plan` → `/exec` → `/doc-update` run on their own; new tech is confirmed with you first, and any new or changed table schema, API, data format or config in the plan is confirmed once more'
has README.en.md '(DDL / API contracts / data formats / config)'
has README.en.md 'when **new tech** is needed it stops before writing the plan, listing each item with its reasons in one prompt for your approval'
has README.en.md 'it lists the tech changes (each with a `file:line` pointing at the final-form definition) for you to confirm before running `/exec`, and with no tech change it runs `/exec` straight away'

has README.ja.md '読んで要件を承認すると plan → exec → doc-update を自動実行;新技術の導入や plan の技術変更がある時は止まって確認を求める'
has README.ja.md ' ══► 自動で接続(新技術の導入、plan の技術変更、設計判断がある時は停止)'
has README.ja.md 'ダイアログで読了と**要件の承認**を確認、承認後は `/plan` → `/exec` → `/doc-update` を自動実行;新技術を導入する時は先に確認し、plan でテーブル構造・API・データ形式・設定を追加または変更する時はもう一度確認を求める'
has README.ja.md '(DDL / API 契約 / データ形式 / 設定)'
has README.ja.md '**新技術の導入**が必要な時は plan を書く前に止まり、項目ごとに理由を挙げて一つのダイアログで承認を求め'
has README.ja.md '技術変更リスト(各項目に成果物定義を指す `ファイル:行番号` 付き)を出して確認を取ってから `/exec` を実行、技術変更がなければそのまま `/exec` を実行'

has README.ko.md '읽고 요구사항을 승인하면 plan → exec → doc-update를 자동 실행; 새 기술 도입이나 plan의 기술 변경이 있으면 멈추고 확인을 구함'
has README.ko.md ' ══► 자동 연결(새 기술 도입, plan의 기술 변경, 설계 판단이 있으면 멈춤)'
has README.ko.md '대화상자로 읽었는지와 **요구사항 승인** 여부를 확인하며, 승인 후 `/plan` → `/exec` → `/doc-update`를 자동 실행; 새 기술을 도입할 때는 먼저 묻고, plan에서 테이블 구조·API·데이터 형식·설정을 추가하거나 변경할 때 한 번 더 확인을 구함'
has README.ko.md '(DDL / API 계약 / 데이터 형식 / 설정)'
has README.ko.md '**새 기술 도입**이 필요하면 plan을 쓰기 전에 멈추고 항목별 이유를 나열해 하나의 대화상자에서 승인을 구하며'
has README.ko.md '기술 변경 목록(각 항목에 산출물 정의를 가리키는 `파일:행번호` 포함)을 보여 주고 확인을 받은 뒤 `/exec`를 실행, 기술 변경이 없으면 바로 `/exec`를 실행'

echo "[流水线图 →Review 列位]"
for entry in README.md:20 README.zh-TW.md:20 README.en.md:21 README.ja.md:20 README.ko.md:20; do
  f="${entry%%:*}"; n="${entry##*:}"
  if [[ ! -r "$ROOT/$f" ]]; then fail "读不到 ${f}"; continue; fi
  lines="$(grep -F -- '→Review' "$ROOT/$f" || true)"
  if [[ "$lines" =~ ^\ {$n}→Review$ ]]; then pass; else fail "${f} 的 →Review 行应为 ${n} 个空格 + →Review，实际：${lines}"; fi
done

echo "[插件描述]"
has .claude-plugin/marketplace.json 'prd（质疑→澄清→拆解，落盘 PRD + AGENTS.md 项目约束，用户批准需求）→ 自动 plan（新技术、技术变更先请用户确认）→'
has plugins/bb-spec-workflow/.claude-plugin/plugin.json 'prd 需求入口（质疑→澄清→拆解，落盘 PRD + AGENTS.md 项目约束，用户批准需求）→ 自动 plan 实施计划（新技术、技术变更先请用户确认）→'
for f in .claude-plugin/marketplace.json plugins/bb-spec-workflow/.claude-plugin/plugin.json; do
  if python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$ROOT/$f" 2>/dev/null; then pass; else fail "${f} 不是合法 JSON"; fi
done

echo "[旧说法清除]"
SCOPE=("$ROOT/plugins" "$ROOT/README.md" "$ROOT/README.zh-TW.md" "$ROOT/README.en.md" "$ROOT/README.ja.md" "$ROOT/README.ko.md" "$ROOT/site" "$ROOT/DESIGN.md" "$ROOT/.claude-plugin/marketplace.json")
for t in 只批准这一次 只批准一次 唯一一次批准 一次批准 批准一次 读完确认一次 只有要引入新技术时才停下 只在需要引入新技术时停下 '只有需要**引入新技术**时才停下' 仅需引入新技术或需设计裁决时停下 \
  只核可這一次 唯一一次核可 讀完確認一次 一次核准 '只有需要**引入新技術**時才停下' 僅需引入新技術或需設計裁決時停下 \
  'approve once' 'the only approval' 'Stops only when new tech' 'stops only for new tech' 'it stops only when **new tech**' 'for a single approval' \
  '1 回承認' '承認はこの 1 回だけ' 唯一の承認 必要な時だけ止まり '新技術の導入や設計判断が必要な時のみ停止' 一度で承認 \
  '한 번 승인' '이 한 번만 승인' '유일한 승인' '필요할 때만 멈추고' '새 기술 도입이나 설계 판단이 필요할 때만 멈춤' '한 번에 승인'; do
  lacks_in "$t" "${SCOPE[@]}"
done

echo "[DESIGN.md：标签只在表格一节]"
source "$(dirname "$0")/lib/md.sh"
PIPE="$(md_section "$ROOT/DESIGN.md" '### 流水线图')"
TABLE="$(md_section "$ROOT/DESIGN.md" '### 表格')"
if [[ -z "$TABLE" ]]; then fail "DESIGN.md「表格」一节截不到"
elif grep -qF -- '子插件名后面的标签 `<span class="badge">`：1px primary 边框、primary 文字、圆角 4px、内边距 0 8px、12px/20px；全站只有这里用标签' <<<"$TABLE"; then pass
else fail "DESIGN.md「表格」一节缺少标签规格"; fi
if [[ -z "$PIPE" ]]; then fail "DESIGN.md「流水线图」一节截不到"
elif grep -qF -- 'badge' <<<"$PIPE"; then fail "DESIGN.md「流水线图」一节不应含 badge"
else pass; fi

echo "通过 ${PASS}，失败 ${FAIL}"
[[ "$FAIL" -eq 0 ]]
