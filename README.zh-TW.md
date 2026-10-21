<p align="center">
  <img src="./assets/banner.jpg" alt="bb-spec — A light-weight protocol for building trust" width="100%" />
</p>

<h1 align="center">📐 BB-Spec</h1>

<p align="center">
  <strong>一條 PRD 驅動的 Claude Code 流水線,把模糊需求一路帶到可交付的程式碼。</strong>
</p>

<p align="center">
  每個階段可追溯、可斷點恢復、經對抗驗證 —— 輔以 Go / Vue + bun / TDD / Git 紀律的技術棧約束套件。
</p>

<p align="center">
  <a href="https://github.com/0xBB2B/bb-spec/actions/workflows/ci.yml?query=branch%3Amain"><img src="https://img.shields.io/github/actions/workflow/status/0xBB2B/bb-spec/ci.yml?branch=main&style=for-the-badge&logo=github&label=CI" alt="CI 狀態" /></a>
  <a href="https://github.com/0xBB2B/bb-spec/releases"><img src="https://img.shields.io/github/v/release/0xBB2B/bb-spec?include_prereleases&style=for-the-badge&logo=github&color=blue" alt="GitHub release" /></a>
  <a href="https://github.com/0xBB2B/bb-spec/stargazers"><img src="https://img.shields.io/github/stars/0xBB2B/bb-spec?style=for-the-badge&color=yellow&logo=github" alt="GitHub Stars" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge" alt="MIT License" /></a>
  <a href="https://docs.anthropic.com/en/docs/claude-code/overview"><img src="https://img.shields.io/badge/Claude%20Code-Plugin-D97757?style=for-the-badge&logo=anthropic&logoColor=white" alt="Claude Code Plugin" /></a>
</p>

<p align="center">
  <a href="./README.md">简体中文</a> · <a href="./README.en.md">English</a> · <strong>繁體中文</strong> · <a href="./README.ja.md">日本語</a> · <a href="./README.ko.md">한국어</a>
</p>

<p align="center">
  <a href="#-30-秒上手">快速開始</a> ·
  <a href="#-核心流水線-prd--ship">流水線</a> ·
  <a href="#-階段一覽">階段一覽</a> ·
  <a href="#-配套約束-skills">約束 Skills</a> ·
  <a href="#-claude-code-安裝--install">安裝</a> ·
  <a href="#-預設啟用的-hooks">Hooks</a> ·
  <a href="#-設計淵源借鑒與對比">設計淵源</a>
</p>

---

## 🚀 30 秒上手

```bash
/plugin marketplace add 0xBB2B/bb-spec
/plugin install bb-spec-core@0xbb2b
/plugin install bb-spec-workflow@0xbb2b
```

日常要手動敲的 5 條命令:

| 命令 | 做什麼 | 何時用 |
|---|---|---|
| `/prd` | 質疑→釐清→拆解,落盤 PRD + AGENTS.md 後請你讀完確認一次,核可就自動跑 plan → exec → doc-update | 新需求開工、要改已合併功能的行為 |
| `/revise` | 按根因診斷→定向修正→回歸驗證,修完自動跑 doc-update | 有 bug、結果和預期不符 |
| `/git-push` | pre-review 自查 + 推送 + 開 PR | 準備提 PR |
| `/exec` | 從斷點接著執行 plan | 中斷或 `/clear` 之後 |
| `/doc-update` | 檢查整個儲存庫的文件與程式碼是否一致 | 想把整個儲存庫查一遍時(`/exec`、`/revise` 收尾已自動查本分支範圍) |

首次接入用 `/git-clone`(拉遠端專案到本地 + 落 `.bb-spec.yaml`);可選命令:`/test-webview` / `/test-api`(前端 / 後端 e2e)。

---

## 🔁 核心流水線 `prd → ship`

```
 (可選) /git-clone ──► 拉遠端 + 落 .bb-spec.yaml
   │
 /prd ══► /plan ══► /exec ══► /doc-update ──► /git-push
 做什麼   怎麼做    Red→Green 文件追平程式碼  pre-review+開 PR
 (唯一一次核可)     →Review

 ══► 自動銜接(僅新增第三方相依套件或需設計裁決時停下)
 ──► 由你手動觸發

 (可選) /test-webview · /test-api — 提 PR 前多加一道檢查:
        前端 e2e / 後端 e2e,掛在 /doc-update 與 /git-push 之間

 /revise(隨時介入,按根因路由,修完自動跑 /doc-update)
   PRD 缺陷 → 改本分支 PRD   ·   實作偏離 → TDD 修復   ·   大的需求變更 → /prd

 /doc-update(手動)— 掃整個儲存庫的文件與程式碼漂移 → 預設改文件,程式碼違反專案約束才停下問 → 掛 /revise
```

**為什麼這條流水線靠得住**——每次交接物都是**磁碟上的檔案**、不是會話裡的暫時記憶,這是它能斷點續、能換 AI 接手、能逐級追溯的根本。

### 🎯 階段一覽

- **`/git-clone`** — *一次性 onboarding*:把遠端儲存庫拉到本地、寫好 `.bb-spec.yaml`。
  - **AskUserQuestion 兩連**:① 單 repo / 多 repo 工作區(決定目錄結構) ② `base_dir`(決定後續所有 bb-spec 交付物落點)
  - **多 repo 工作區**建立統一父目錄 + 各成員儲存庫獨立 clone(復原建構工具期待的相對佈局),禁巢狀、禁覆寫
  - 職責嚴格收斂:**只**拿程式碼 + 寫 `base_dir`,不讀程式碼、不裝相依套件

- **`/prd`** — 新需求的唯一入口,回答**「做什麼、為什麼」**。要改已合併功能或舊程式碼的行為時也從這裡開始(再小也算,例如把逾時從 120 秒改成 600 秒、把按鈕文字從「提交」改成「儲存」),新開一份 PRD 記下這次的取捨。
  - 質疑前置(允許結論是「不值得做」)→ 遞進釐清 → 拆解,對齊階段**唯讀**,需求涉及介面時先出 HTML 預覽頁請你確認;落盤 PRD 後彈窗請你讀完確認,使用者**只核可這一次**,核可後自動跑完 `/plan` → `/exec` → `/doc-update`
  - 落盤 **PRD**(`docs/prd/<日期>.<主題>/`:背景、目標、非目標、使用者故事、可測的約束與驗收、決策紀錄)和 **AGENTS.md**(對整個專案生效的約束,如「禁止泛型」)
  - PRD 在本分支內可改(實施中發現方案問題直接改它),合併後凍結;**程式碼是「現在做什麼」的唯一來源**,PRD 只回答「為什麼」
  - 之後每個 commit 帶 `Requirement: <PRD 目錄名>` 標記:`git log -L :函式:檔案` 就能列出改過這個函式的需求,讀對應 PRD 的決策紀錄就知道當時為什麼這樣設計
  - 支援多儲存庫工作區(如 `docs/` 與各服務是獨立儲存庫):PRD 與 AGENTS.md 放在文件儲存庫,每個儲存庫的 commit 都帶標記

- **`/plan`** — PRD → 自包含、**函式級**實施計畫,回答**「怎麼做」**。
  - 每檔案一獨立問題,詳細到函式名與職責;宣告式產物(DDL / API 契約 / 設定)**直接內聯最終成品**,exec 原樣落盤
  - 由 `/prd` 自動呼叫,產出後直接跑 `/exec`;只有需要**新增第三方相依套件**時才停下請使用者同意,同意即視為 version-policy 要求的授權
  - plan 只在執行期間存在,全部完成後由 `/exec` 刪除,避免和 PRD 重複

- **`/exec`** — **三 Agent 隔離執行**,核心反作弊設計。
  - *Test* Agent 只讀 PRD 約束寫失敗測試(Red)
  - *Impl* Agent **看不到 PRD**,只看測試 + 函式清單寫實作(Green),無法「照著意圖作弊」;新增第三方函式庫受 plan 已核可相依清單約束
  - *Review* Agent 對照 PRD 驗收與 AGENTS.md 檢查並過一遍強健性/安全視角,唯讀不寫
  - 每步進度寫 `PROGRESS.md`,token 耗盡也能**無損續接**
  - 實施中發現方案有問題,停下讓你選:改程式碼 / 改本次 PRD / 暫停;小改就地改,大改回到 `/prd` 重新核可
  - 全部完成後自動跑 `/doc-update` 收尾模式,讓本次 PRD 和 README 等文件追平實際交付

- **`/doc-update`** — 文件與程式碼**一致性體檢**。
  - 四類發現:doc-stale(根文件過期)/ prd-stale(本分支 PRD 與交付不符)/ code-violation(程式碼違反 AGENTS.md)/ agents-conflict(專案約束互相矛盾)
  - **程式碼是事實、文件追平程式碼**;改程式碼一律先問、掛回 `/revise` 走 TDD;已合併的 PRD 任何模式都不碰
  - 維護專案根的 **ARCHITECTURE.md** 大綱(有哪些模組、各在哪、怎麼協作,資料表與 API 只寫概覽):全倉模式沒有時讀程式碼起草,核可後落盤;收尾模式隨本分支增刪、搬遷模組或改動資料表、API 分組自動追平。AI 了解現狀時先讀它定位模組,再讀程式碼
  - **收尾模式**(`--tail`):`/exec`、`/revise` 結束時自動呼叫,只處理本分支改動涉及的範圍

- **`/git-push`** — 使用者觸發的推送 + PR 流程(單 / 多儲存庫)。
  - 本機裝了 `ocr`([open-code-review](https://github.com/alibaba/open-code-review))時,rebase 後先跑一次 `ocr review`:Claude 逐條讀程式碼核實,按 🔴/🔶/🔷 列出建議修復項,你勾選後交給 `/revise` 修
  - 存在 AGENTS.md、本分支 PRD 或本分支 commit 指向已合併 PRD 時先跑**分支規範自查(pre-review)**:subagent 比對專案約束、PRD 與 commit 正文的改動說明 vs 分支 diff,違規循環修復
  - PR 標題跟隨倉庫 commit 風格,描述帶 `Requirement:` 標記;倉庫需只允許 squash 合併(GitHub 只勾「Allow squash merging」並把預設說明設為「Default to pull request title and description」,主分支規則集的「Allowed merge methods」也只留 Squash;GitLab 選「Fast-forward merge」,squash 設為「Require」,squash 說明範本填 `%{title}`、空一行、`%{description}`),每個 PR 在主分支上只留一個 commit,說明就是 PR 標題和描述,開發中途推翻的 commit 不進主分支
  - 起草 **6 段 PR 描述**(背景 / 需求 / 方案 / 結果 / 測試 / 規範,< 50 行)直接用作 PR body

- **`/revise`** — 隨時介入的例外處理。
  - 先讀程式碼確認現狀、經 `git log -L` 查回相關 PRD,再把偏差**歸因**為三類:*PRD 缺陷*、*實作偏離*、*需求變更*
  - 需求變了(*PRD 缺陷*、*需求變更*):只在本分支 PRD 上改,並記進它的決策紀錄;PRD 已合併或沒有 PRD 時停下,轉 `/prd` 新開一份
  - bug、安全、穩健性問題(*實作偏離*):已合併的 PRD 也在這裡修,修訂原因和取捨(選了什麼、否掉了什麼、為什麼)寫進 commit 正文
  - 所有需修復的 review 發現都匯入此處
  - 修完自動跑 `/doc-update` 收尾模式

- **`/test-webview`** — (可選) 前端 / 網頁專案的**互動驗收**。
  - Docker 整棧拉起(首次確認後記住,跑完 `down -v` 清理),瀏覽器 MCP 驅動真實瀏覽器
  - **每個用例派隔離串列 subagent**,幾百用例也不爆主上下文;全程串列(瀏覽器單一實例)
  - 用例自動從本分支 PRD 的驗收與驗證路徑歸納生成(不讀已合併的歷史 PRD);跑前**覆蓋對齊**,缺口不靜默漏測;失敗轉 `/revise`
  - 需瀏覽器 MCP(playwright / chrome-devtools)

- **`/test-api`** — (可選) 後端**介面 e2e**。
  - `compose.e2e.yaml` 拉起整棧,md 用例**機械渲染為單檔 Bun TS runner**,`bun run` 一次跑完
  - **零 subagent、零並發**——HTTP 是確定性腳本,時鐘共享禁並發
  - **時間敏感規則**(token 過期、訂單逾時、點數過期)經 `/test/advance-time`、`/test/backdate`、`/test/trigger-job` 協定測試
  - 應用端**產雙 image**:test image 帶 `/test/*` 路由 + `ENV TESTAPI=1`;生產 image **物理排除** `/test/*` 原始碼;`/test/healthz` 探測失敗即中止、禁降級

**附帶產物**

- **5 個編排 subagent**(被上述環節驅動):`test-engineer` / `impl-engineer` / `prd-reviewer` / `webview-test-runner` / `pre-reviewer`
- **4 個被動 hook**(自動生效):攔截 npm/yarn、攔截 main commit、相依版本自檢、Stop 四項自檢

---

## 🧩 配套約束 Skills

向流水線灌入規則——只裝你需要的層。

### bb-spec-core — 通用紀律

- **`tdd-workflow`** — Red-Green-Refactor 紀律,涵蓋增 / 改 / 刪三場景標準流程
- **`version-policy`** — 官方函式庫 / 標準函式庫優先,新增第三方函式庫須經使用者明確同意(`/plan` 階段使用者同意的相依清單視為已同意);釘版本前先查相依套件官方最新版,禁憑訓練記憶
- **`git-workflow`** — 分支決策、階段性 commit、六段式 PR 描述、合併後清理

### bb-spec-backend — 後端技術框架約束

- **`golang-constraints`** — Go 全生命週期:三層架構、禁過度抽象、測試服從生產設計
- **`golang-testing`** — Go 測試組織:table-driven、subtests、benchmark、fuzz
- **`api-design`** — REST 設計:資源命名、狀態碼、分頁、`A-BBB-CCCC` 結構化錯誤碼
- **`database-constraints`** — 應用層 UUIDv7 主鍵、軟刪除 + 聯合 UNIQUE、DB 管理時間戳記、全鏈路 UTC
- **`auth-constraints`** — 認證(authN):雙 token(JWT + 不透明 refresh)輪換 + 重放偵測、滑動續期、argon2id
- **`authz-constraints`** — 授權(authZ):預設拒絕、判定集中、粗粒度角色 + 細粒度資源 ownership 兩級校驗防 IDOR
- **`observability-constraints`** — 日誌 / 鏈路 / 指標基於 OTel:一處裝配、JSON 日誌帶穩定 trace_id、label 基數有限
- **`service-constraints`** — 執行時治理:env 注入密鑰 fail-fast、優雅生命週期、寫冪等、逾時 + 安全重試
- **`config-constraints`** — 設定載體三分:env/secret 裝啟動必需且不熱更、yaml/configmap 裝可熱更預設值、DB 裝動態業務設定;核心憑證僅 secret/KMS,下沉 DB 須 envelope encryption

### bb-spec-frontend — 前端技術框架約束

- **`vue-constraints`** — Vue 3 + TypeScript + Vite + Tailwind + bun 技術棧強約束
- **`frontend-constraints`** — 工程約定:統一請求 client、錯誤碼→UI 對應集中、路由守衛僅 UX、型別來自契約

---

## 📦 Claude Code 安裝 / Install

BB-Spec 拆成**四個可獨立安裝的子 plugin**——只裝你需要的約束層。

先加入一次 marketplace(在 Claude Code 裡執行):

```bash
/plugin marketplace add 0xBB2B/bb-spec
```

再按需安裝對應層:

| 子 plugin | 裝了得到什麼 | 安裝命令 |
|---|---|---|
| **bb-spec-core** _(推薦基座)_ | TDD / 版本策略 / Git 紀律 + 3 個被動 hook | `/plugin install bb-spec-core@0xbb2b` |
| **bb-spec-workflow** _(核心功能)_ | prd → plan → exec → doc-update → revise → git-push(+ 可選 test-webview / test-api e2e)、git-clone 一次性初始化 + 5 個 subagent | `/plugin install bb-spec-workflow@0xbb2b` |
| **bb-spec-backend** | Go / REST API / 資料庫 / 認證 / 授權 / 可觀測性 / 服務治理 / 設定約束 | `/plugin install bb-spec-backend@0xbb2b` |
| **bb-spec-frontend** | Vue 3 + TS + Vite + Tailwind + bun 技術棧與工程約定(含 bun hook) | `/plugin install bb-spec-frontend@0xbb2b` |

按需取用——例如只要紀律與工作流、不要技術棧意見:裝 `bb-spec-core` + `bb-spec-workflow`;想要全套:四個全裝。

或手動加入到 `~/.claude/settings.json`(只 enable 你想要的):

```json
{
  "extraKnownMarketplaces": {
    "0xbb2b": {
      "source": { "source": "github", "repo": "0xBB2B/bb-spec" }
    }
  },
  "enabledPlugins": {
    "bb-spec-core@0xbb2b": true,
    "bb-spec-workflow@0xbb2b": true,
    "bb-spec-backend@0xbb2b": false,
    "bb-spec-frontend@0xbb2b": false
  }
}
```

## 🔄 版本與更新 / Versioning

```bash
claude plugin update bb-spec-workflow@0xbb2b   # 在終端機裡更新某個子 plugin
```

一次更新全部:在會話裡執行 `/plugin`,到 **Marketplaces** 頁選 `0xbb2b`,再選 **Update marketplace**。

四個子 plugin 共用同一條同步版本線。

### 從 13 及更早版本升級

不需要遷移。專案裡舊的 `.bb-spec/` 目錄刪掉或保留都行,升級後直接用 `/prd` 開始下一個需求。

保留舊目錄時(下面的 `.bb-spec/docs/` 是預設位置,在 `.bb-spec.yaml` 裡改過 `base_dir` 的按你的設定):

- 舊的 `.bb-spec/docs/spec/`、`.bb-spec/docs/prd/.archive/`、`.bb-spec/docs/plan/INDEX.md` 都不會被讀取,也不會被修改。
- 還沒有 `.bb-spec/docs/prd/GLOSSARY.md` 時,`/prd` 沿用 `.bb-spec/docs/spec/GLOSSARY.md` 裡的術語;第一次登記術語時會整份複製到新位置,舊表不動。
- 13 版本沒做完的 plan 不能接著執行,請用 `/prd` 重新開始。`plan/INDEX.md` 和其中登記的主題目錄不再需要時,可以用 `git rm -r` 刪掉。

接入前寫的舊程式碼,commit 裡沒有 `Requirement:` 標記,查不到對應的 PRD。修它的 bug 用 `/revise`,以你描述的期望行為為準;要改它的設計或行為,用 `/prd` 新開一份 PRD。

`.bb-spec/` 以外有兩處要手動處理:

1. 裝過 `bb-spec-product` 的,執行 `/plugin uninstall bb-spec-product@0xbb2b` 解除安裝。`/prd` 已經移到 `bb-spec-workflow` 裡。
2. 從舊的 `CLAUDE.template.md` 複製過 CLAUDE.md 的(全域 `~/.claude/CLAUDE.md` 或專案根),把「任务分流」(任務分流)第 4 條的 `/spec → /plan → /exec` 改成 `/prd`,第 3 條的「有现成 spec/plan/代码可对照」改成「有现成 PRD 或代码可对照」(模板原文為簡體)。

---

## 🪝 預設啟用的 Hooks

每個 hook 隨「負責該關注點的子 plugin」一起發布——裝了對應 plugin 才有。

| Hook | 所屬子 plugin | 觸發時機 | 作用 |
|---|---|---|---|
| `block-non-bun-pm` | bb-spec-frontend | PreToolUse(Bash) | 攔截 `npm` / `yarn` / `pnpm` 的套件管理動作,強制 `bun`;既有專案已存在匹配 lockfile(如 `package-lock.json`)時放行 |
| `git-workflow-guard` | bb-spec-core | PreToolUse(Bash) | 攔截 `main` / `master` 分支的 `git commit`;其餘 git 流程動作(開分支 / push / worktree / merge / PR)放行並注入 git-workflow 紀律與即時 git 狀態 |
| `dep-version-check` | bb-spec-core | PostToolUse(Write\|Edit) | 編輯相依檔案後注入「先查官方最新版」自檢提示 |
---

## 🧪 測試

```bash
bash tests/validate.sh
```

校驗多 plugin 結構:marketplace.json 有效性與 plugin 條目一致性(每個 `source` 都指向真實存在、且 name 匹配的 plugin 目錄)、各子 plugin 的 plugin.json 欄位、agent frontmatter 完整性(必填欄位、name 一致性、agent-type 合法值、安全基線段落)、skill SKILL.md 格式、hooks.json 有效性及腳本存在性、個人路徑洩漏偵測。

CI 在 PR 和 push 到 main 時自動執行(`.github/workflows/ci.yml`)。

---

## 🛠️ 推薦配套

### AGENTS.md:專案約束與查詢規矩

`/prd` 把對整個專案生效的約束(如「禁止泛型」「SQL join 不超過 3 張表」)寫進專案根的 `AGENTS.md`,只屬於某個功能的約束寫進 PRD,同一條約束不會寫兩處。`AGENTS.md` 裡還有一節「查功能、查問題的規矩」:回答「系統現在怎麼做」必須先讀程式碼並給出 `檔案:行號`;查「為什麼」用 `git log -L` 找到改過該函式的需求再讀 PRD;PRD 和程式碼不一致時以程式碼為準。Claude Code 只讀 `CLAUDE.md`、不直接讀 `AGENTS.md`,所以 `/prd` 會確保專案根 `CLAUDE.md` 含一行 `@AGENTS.md` 把它匯入。

### .bb-spec.yaml 專案設定

`/prd` 和 `/plan` 預設輸出至 `.bb-spec/docs/` 下(`.bb-spec/docs/prd/`、`…/plan/`);執行時瞬態產物(如 webview 截圖)落在與之平級的 `.bb-spec/.cache/`(自動 gitignore)。在專案根建立 `.bb-spec.yaml` 可覆寫 bb-spec 根目錄:

```yaml
base_dir: my/bb  # → my/bb/docs/{prd,plan,test}/ 與 my/bb/.cache/;填 ./ 則直接落專案根
```

參考範本:[`.bb-spec.template.yaml`](./.bb-spec.template.yaml)。

---

## ⚙️ Hook 開關速查

| 場景 | 開關 |
|---|---|
| 暫時允許 npm / yarn / pnpm | 暫時停用 `bb-spec-frontend` |
| 暫時允許 main commit | 暫時停用 `bb-spec-core` |
| 跳過 Stop 自檢 | 目前無開關——這是核心鐵律,不建議跳過 |

---

## 💡 設計淵源:借鑒與對比

BB-Spec 站在三個優秀專案的肩上。它們各自塑造了 BB-Spec 設計的不同部分——下表致謝其所長,並說明 BB-Spec 借鑒了什麼、又把這個想法推進到了哪一步。

| 專案 | 它最擅長 | BB-Spec 借鑒並強化的點 |
|---|---|---|
| [**Superpowers**](https://github.com/obra/Superpowers)(obra)—— 一套完整的編碼代理方法論 | 端到端分階段工作流、子代理驅動開發 + 分階段審查、TDD 紅-綠-重構、git worktree 隔離、蘇格拉底式頭腦風暴、可組合技能庫 | 整條 `prd → ship` 流水線骨架、按角色拆分子 Agent 協作、強制 TDD、多階段 / 對抗式審查、對話先行的需求澄清 |
| [**ECC**](https://github.com/affaan-m/ECC)(affaan-m)—— 一個 agent harness「作業系統」 | agents / skills / hooks / rules 的大規模分層體系、被動 hook 自動強制、規則即基礎設施、跨會話記憶持久化 | 分層、可獨立安裝的子插件套件、用被動 hook 強制紀律、把工程規範沉澱為可載入的約束 skill |
| [**skills**](https://github.com/mattpocock/skills)(mattpocock)——「Skills For Real Engineers」 | 直擊真實失敗模式(需求不對齊 / 冗長 / 品質 / 架構)、深度提問對齊意圖、共享域語言、使用者呼叫 vs 模型呼叫雙形態 skill、垂直切片 | 質疑前置、動手前先對話鎖定需求、雙觸發 skill(slash 命令 + 模型自動觸發)、只留一份事實來源的極簡組織 |

**BB-Spec 自己的取捨**——三者都未同時具備的差異化:

- **三 Agent 隔離執行**——Impl Agent *物理上看不到 PRD*,只看測試,無法「照著意圖矇混」;測試、實作、審查由互相看不見的三方分別完成。
- **磁碟檔案作為唯一交接物**——每階段交接的是檔案而非會話記憶,因此跨會話、`/clear` 乃至換一個模型接手都能無損續接。
- **程式碼 ⇄ PRD 經 git 雙向可查**——程式碼是唯一事實來源,PRD 只寫為什麼;每個 commit 帶需求標記,從功能能找到程式碼,從函式能查回當時的需求與取捨,中間沒有需要人工同步、會過時的規則文件。

---

## 📜 License

MIT —— 詳見 [LICENSE](./LICENSE)。

<p align="center">
  <sub>Built with ❤️ for the Claude Code community.</sub>
</p>
