<p align="center">
  <img src="./assets/banner.jpg" alt="bb-spec — A light-weight protocol for building trust" width="100%" />
</p>

<h1 align="center">📐 BB-Spec</h1>

<p align="center">
  <strong>一條 spec 驅動的 Claude Code 流水線,把模糊需求一路帶到可交付的程式碼。</strong>
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
  <a href="./README.md">English</a> · <a href="./README.zh.md">简体中文</a> · <strong>繁體中文</strong> · <a href="./README.ja.md">日本語</a> · <a href="./README.ko.md">한국어</a>
</p>

<p align="center">
  <a href="#-30-秒上手">快速開始</a> ·
  <a href="#-核心流水線-spec--ship">流水線</a> ·
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

主流水線 5 條命令:

| 命令 | 做什麼 | 何時用 |
|---|---|---|
| `/spec` | 把需求拆成一規則一文件 | 新需求開工 |
| `/plan` | spec → 函式級實施計畫 | spec 就緒 |
| `/exec` | 三 Agent 隔離跑 Test→Impl→Review | plan 就緒 |
| `/review` | 多 finder 並行 + 對抗驗證 | 提 PR 前 |
| `/git-push` | pre-review 自查 + 推送 + 開 PR | 準備發版 |

三條支線隨時可介入:`/git-clone`(拉遠端專案到本地 + 落 `.bb-spec.yaml` 一次性 onboarding)、`/revise`(任何偏差按根因回到正確階段)、`/doc-update`(全儲存庫 spec/文件/程式碼一致性體檢)。

可選上游:`/prd`(PM / 需求方頭腦風暴 PRD,由 bb-spec-product 單獨提供)。

---

## 🔁 核心流水線 `spec → ship`

```
 (可選) /git-clone ──► 拉遠端 + 落 .bb-spec.yaml
   │
 (可選) /prd ──► PRD 文件
   │
 /spec ──► /plan ──► /exec ──► /review ──► /git-push
 做什麼     怎麼做    Red→Green→Review  並發+對抗  pre-review+開 PR
                                                          │
        ┌─────────────────────────────────────────────────┘
        │
        ▼ /revise(隨時介入,按根因路由)
          spec 缺陷 → /spec   ·   實作偏離 → /exec   ·   review 問題 → 定向修復

 (可選) /test-webview · /test-api — 前端 / 後端 e2e,掛在 /exec 與 /review 之間
 /doc-update(定期 / 按需)— 掃全儲存庫漂移 → 預設改 spec/文件,程式碼明顯不合理才停下問 → 掛 /revise
```

**為什麼這條流水線靠得住**——每次交接物都是**磁碟上的檔案**、不是會話裡的暫時記憶,這是它能斷點續、能換 AI 接手、能逐級追溯的根本。

### 🎯 階段一覽

- **`/git-clone`** — *一次性 onboarding*:把遠端儲存庫拉到本地、寫好 `.bb-spec.yaml`。
  - **AskUserQuestion 兩連**:① 單 repo / 多 repo 工作區(決定目錄結構) ② `base_dir`(決定後續所有 bb-spec 交付物落點)
  - **多 repo 工作區**建立統一父目錄 + 各成員儲存庫獨立 clone(復原建構工具期待的相對佈局),禁巢狀、禁覆寫
  - 職責嚴格收斂:**只**拿程式碼 + 寫 `base_dir`,不讀程式碼、不裝相依套件

- **`/spec`** — 透過對話做需求拆解,回答**「做什麼」**。
  - 一檔一規則、≤100 行、只說一件事 + 一個範例,互不重疊
  - 輕量 `INDEX.md` 統領,讀者先掃索引再按需載入

- **`/plan`** — spec → 自包含、**函式級**實施計畫,回答**「怎麼做」**。
  - 每個檔案一獨立問題,詳細到函式名與職責;宣告式產物(DDL / API 契約 / 設定)**直接內聯最終成品**,exec 原樣落盤
  - 呼叫即進入 **plan 模式唯讀對齊**,核可後才落盤;**新增第三方相依套件單獨成節**,核可即視為 version-policy 要求的使用者同意

- **`/exec`** — **三 Agent 隔離執行**,核心反作弊設計。
  - *Test* Agent 只讀 spec 規則寫失敗測試(Red)
  - *Impl* Agent **看不到 spec**,只看測試 + 函式清單寫實作(Green),無法「照著意圖作弊」;新增第三方函式庫受 plan 已核可相依清單約束
  - *Review* Agent 對照 spec 檢查,唯讀不寫
  - 每步進度寫 `PROGRESS.md`,token 耗盡也能**無損續接**

- **`/test-webview`** — 前端 / 網頁專案的**互動驗收**。
  - Docker 整棧拉起(首次確認後記住,跑完 `down -v` 清理),瀏覽器 MCP 驅動真實瀏覽器
  - **每個用例派隔離串列 subagent**,幾百用例也不爆主上下文;全程串列(瀏覽器單一實例)
  - 用例自動從 spec / plan / PRD 歸納生成;跑前**覆蓋對齊**,缺口不靜默漏測;失敗轉 `/revise`
  - 需瀏覽器 MCP(playwright / chrome-devtools)

- **`/test-api`** — 後端**介面 e2e**。
  - `compose.e2e.yaml` 拉起整棧,md 用例**機械渲染為單檔 Bun TS runner**,`bun run` 一次跑完
  - **零 subagent、零並發**——HTTP 是確定性腳本,時鐘共享禁並發
  - **時間敏感規則**(token 過期、訂單逾時、點數過期)經 `/test/advance-time`、`/test/backdate`、`/test/trigger-job` 協定測試
  - 應用端**產雙 image**:test image 帶 `/test/*` 路由 + `ENV TESTAPI=1`;生產 image **物理排除** `/test/*` 原始碼;`/test/healthz` 探測失敗即中止、禁降級

- **`/review`** — Workflow 編排、**對抗驗證**的本地 PR review。
  - Phase 1 並發 **6 個 finder**:程式碼品質 / 安全 / 簡潔性 / 強健性 / 文件同步 / **Codex 跨模型獨立** review,schema 強制結構化
  - Phase 2 每條 🔴/🟡 由 **3 個獨立懷疑視角**重判(重要性 / 根源性 / 不修風險),多數決去留
  - 唯讀、絕不自動改程式碼;要求 Claude Code ≥ 2.1.154

- **`/revise`** — 隨時介入的例外處理。
  - 把偏差**歸因**為三類:*spec 缺陷*(→ `/spec`)、*實作偏離*(→ `/exec`)、*需求變更*
  - 所有需修復的 review 發現都匯入此處

- **`/git-push`** — 使用者觸發的推送 + PR 流程(單 / 多儲存庫)。
  - 存在 spec `INDEX.md` 時先跑**分支規範自查(pre-review)**:subagent 比對 spec vs 分支 diff,違規循環修復
  - 起草 **6 段 PR 描述**(背景 / 需求 / 方案 / 結果 / 測試 / 規範,< 50 行)直接用作 PR body

- **`/doc-update`** — 全儲存庫 spec / 文件 / 程式碼**一致性體檢**。
  - 六類漂移定位:spec-stale / doc-stale / code-violation / spec-conflict / orphan-index / uncovered-rule
  - **程式碼是事實、spec/文件追平程式碼**;程式碼明顯違背硬約束才停下問、掛回 `/revise` 走 TDD
  - 與 `/revise`(單點)、`/review` 的 `review-doc-sync`(PR diff)劃清邊界

**附帶產物**

- **11 個編排 subagent**(被上述環節驅動):`test-engineer` / `impl-engineer` / `spec-reviewer` / `webview-test-runner` / `review-code-quality` / `review-security` / `review-simplicity` / `review-robustness` / `review-doc-sync` / `review-codex` / `pre-reviewer`
- **4 個被動 hook**(自動生效):攔截 npm/yarn、攔截 main commit、相依版本自檢、Stop 四項自檢

---

## 🧩 配套約束 Skills

向流水線灌入規則——只裝你需要的層。

### bb-spec-product — 產品需求(流水線上游)

- **`prd`** — PM / 需求方與 AI 頭腦風暴:質疑前置(允許否決)→ 發散 → 收斂,產出自包含 PRD——目標 / 非目標、帶優先級的使用者故事(每條 P0 掛具體用例與驗收標準)、留給工程師的開放問題;不依賴 git 儲存庫與程式碼上下文,`/spec` 直接消費

> **PM 不用裝 Claude Code**:每次發版自動打包 [`bb-spec-prd-skill.zip`](https://github.com/0xBB2B/bb-spec/releases/latest/download/bb-spec-prd-skill.zip),下載後在 claude.ai 網頁版 / 桌面版的 **Settings → Customize → Skills** 上傳即可單獨使用(需付費方案並啟用程式碼執行),產出的 PRD 以可下載檔案交付給工程師。

### bb-spec-core — 通用紀律

- **`tdd-workflow`** — Red-Green-Refactor 紀律,涵蓋增 / 改 / 刪三場景標準流程
- **`version-policy`** — 官方函式庫 / 標準函式庫優先,新增第三方函式庫須經使用者明確同意(plan 核可的相依清單視為已同意);釘版本前先查相依套件官方最新版,禁憑訓練記憶
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

BB-Spec 拆成**五個可獨立安裝的子 plugin**——只裝你需要的約束層。

先加入一次 marketplace(在 Claude Code 裡執行):

```bash
/plugin marketplace add 0xBB2B/bb-spec
```

再按需安裝對應層:

| 子 plugin | 裝了得到什麼 | 安裝命令 |
|---|---|---|
| **bb-spec-core** _(推薦基座)_ | TDD / 版本策略 / Git 紀律 + 3 個被動 hook | `/plugin install bb-spec-core@0xbb2b` |
| **bb-spec-workflow** _(核心功能)_ | spec → plan → exec → review → revise → git-push(+ 可選 test-webview / test-api e2e)、git-clone 一次性初始化、init 反向 spec、doc-update 全儲存庫一致性維護 + 12 個 subagent | `/plugin install bb-spec-workflow@0xbb2b` |
| **bb-spec-product** | /prd 需求頭腦風暴 → 含具體用例的 PRD 文件(PM / 需求方使用) | `/plugin install bb-spec-product@0xbb2b` |
| **bb-spec-backend** | Go / REST API / 資料庫 / 認證 / 授權 / 可觀測性 / 服務治理 / 設定約束 | `/plugin install bb-spec-backend@0xbb2b` |
| **bb-spec-frontend** | Vue 3 + TS + Vite + Tailwind + bun 技術棧與工程約定(含 bun hook) | `/plugin install bb-spec-frontend@0xbb2b` |

按需取用——例如只要紀律與工作流、不要技術棧意見:裝 `bb-spec-core` + `bb-spec-workflow`;PM / 需求方的機器上只裝 `bb-spec-product`;想要全套:五個全裝。

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
    "bb-spec-product@0xbb2b": false,
    "bb-spec-backend@0xbb2b": false,
    "bb-spec-frontend@0xbb2b": false
  }
}
```

### 在 Claude Code 桌面版安裝(圖文版)

適用於 Claude Code 桌面版 app(Mac / Windows),全程 GUI 操作,無需手敲指令。

**1. 打開插件管理面板**

輸入框點 `+` → `Plugins` → `Manage plugins`:

<p align="center">
  <img src="./assets/desktop/01-manage-plugins.png" alt="打開插件管理面板" width="100%" />
</p>

**2. 加入 marketplace**

Plugins 面板右上角點 `Add` → `Add marketplace`:

<p align="center">
  <img src="./assets/desktop/02-add-marketplace.png" alt="加入 marketplace" width="100%" />
</p>

**3. 選擇從儲存庫加入**

彈窗中選 `Add from a repository`:

<p align="center">
  <img src="./assets/desktop/03-from-repository.png" alt="從儲存庫加入" width="100%" />
</p>

**4. 填入 bb-spec 儲存庫地址並同步**

URL 填 `https://github.com/0xBB2B/bb-spec`,點 `Sync`:

<p align="center">
  <img src="./assets/desktop/04-sync-url.png" alt="同步 marketplace" width="100%" />
</p>

**5. 啟用核心三件套**

Directory 中會看到 bb-spec 的 5 個子插件。點擊 `Bb spec core` / `Bb spec workflow` / `Bb spec product` 三張卡片右上角的齒輪按鈕分別啟用(後端 / 前端按需啟用):

<p align="center">
  <img src="./assets/desktop/05-enable-plugins.png" alt="啟用插件" width="100%" />
</p>

**6. 驗證安裝**

回到對話輸入框,輸入 `/prd` 看到指令補全提示即表示安裝成功:

<p align="center">
  <img src="./assets/desktop/06-verify-prd.png" alt="驗證安裝" width="100%" />
</p>

## 🔄 版本與更新 / Versioning

```bash
/plugin update                  # 檢查並更新所有已裝 plugin
/plugin update bb-spec-core     # 僅更新某個子 plugin
```

五個子 plugin 共用同一條同步版本線。

---

## 🪝 預設啟用的 Hooks

每個 hook 隨「負責該關注點的子 plugin」一起發布——裝了對應 plugin 才有。

| Hook | 所屬子 plugin | 觸發時機 | 作用 |
|---|---|---|---|
| `block-non-bun-pm` | bb-spec-frontend | PreToolUse(Bash) | 攔截 `npm` / `yarn` / `pnpm` 的套件管理動作,強制 `bun`;既有專案已存在匹配 lockfile(如 `package-lock.json`)時放行 |
| `git-workflow-guard` | bb-spec-core | PreToolUse(Bash) | 攔截 `main` / `master` 分支的 `git commit`;其餘 git 流程動作(開分支 / push / worktree / merge / PR)放行並注入 git-workflow 紀律與即時 git 狀態 |
| `dep-version-check` | bb-spec-core | PostToolUse(Write\|Edit) | 編輯相依檔案後注入「先查官方最新版」自檢提示 |
| `stop-self-check` | bb-spec-core | Stop | 任務結束前強制四項自檢:暫存檔 / 改動範圍 / 孤立殘留 / 歷史包袱 |

---

## 🧪 測試

```bash
bash tests/validate.sh
```

校驗多 plugin 結構:marketplace.json 有效性與 plugin 條目一致性(每個 `source` 都指向真實存在、且 name 匹配的 plugin 目錄)、各子 plugin 的 plugin.json 欄位、agent frontmatter 完整性(必填欄位、name 一致性、agent-type 合法值、安全基線段落)、skill SKILL.md 格式、hooks.json 有效性及腳本存在性、個人路徑洩漏偵測。

CI 在 PR 和 push 到 main 時自動執行(`.github/workflows/ci.yml`)。

---

## 🛠️ 推薦配套

### CLAUDE.md 範本

儲存庫根目錄的 [`CLAUDE.template.md`](./CLAUDE.template.md) 是配套的「鐵律索引」參考。**不會自動安裝**——按需複製到你的 `~/.claude/CLAUDE.md` 或專案根 `CLAUDE.md`,按需裁剪。

### .bb-spec.yaml 專案設定

`/prd`、`/spec` 和 `/plan` 預設輸出至 `.bb-spec/docs/` 下(`.bb-spec/docs/prd/`、`…/spec/`、`…/plan/`);執行時瞬態產物(如 webview 截圖)落在與之平級的 `.bb-spec/.cache/`(自動 gitignore)。在專案根建立 `.bb-spec.yaml` 可覆寫 bb-spec 根目錄:

```yaml
base_dir: my/bb  # → my/bb/docs/{prd,spec,plan,test}/ 與 my/bb/.cache/;填 ./ 則直接落專案根
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
| [**Superpowers**](https://github.com/obra/Superpowers)(obra)—— 一套完整的編碼代理方法論 | 端到端分階段工作流、子代理驅動開發 + 分階段審查、TDD 紅-綠-重構、git worktree 隔離、蘇格拉底式頭腦風暴、可組合技能庫 | 整條 `spec → ship` 流水線骨架、按角色拆分子 Agent 協作、強制 TDD、多階段 / 對抗式審查、對話先行的需求澄清 |
| [**ECC**](https://github.com/affaan-m/ECC)(affaan-m)—— 一個 agent harness「作業系統」 | agents / skills / hooks / rules 的大規模分層體系、被動 hook 自動強制、規則即基礎設施、跨會話記憶持久化 | 分層、可獨立安裝的子插件套件、用被動 hook 強制紀律、把工程規範沉澱為可載入的約束 skill |
| [**skills**](https://github.com/mattpocock/skills)(mattpocock)——「Skills For Real Engineers」 | 直擊真實失敗模式(需求不對齊 / 冗長 / 品質 / 架構)、深度提問對齊意圖、共享域語言、使用者呼叫 vs 模型呼叫雙形態 skill、垂直切片 | 質疑前置、動手前先對話鎖定需求、雙觸發 skill(slash 命令 + 模型自動觸發)、一檔一規則的極簡組織 |

**BB-Spec 自己的取捨**——三者都未同時具備的差異化:

- **三 Agent 隔離執行**——Impl Agent *物理上看不到 spec*,只看測試,無法「照著意圖矇混」;測試、實作、審查由互相看不見的三方分別完成。
- **磁碟檔案作為唯一交接物**——每階段交接的是檔案而非會話記憶,因此跨會話、`/clear` 乃至換一個模型接手都能無損續接。
- **spec ⇄ code 雙向閉環**——不止 spec → code:`/doc-update` 全儲存庫掃描漂移,持續把 spec 追平程式碼現態。

---

## 📜 License

MIT —— 詳見 [LICENSE](./LICENSE)。

<p align="center">
  <sub>Built with ❤️ for the Claude Code community.</sub>
</p>
