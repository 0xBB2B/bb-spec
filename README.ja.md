<p align="center">
  <img src="./assets/banner.jpg" alt="bb-spec — A light-weight protocol for building trust" width="100%" />
</p>

<h1 align="center">📐 BB-Spec</h1>

<p align="center">
  <strong>曖昧な要件を出荷可能なコードまで運ぶ、spec 駆動の Claude Code パイプライン。</strong>
</p>

<p align="center">
  各ステージはトレース可能・再開可能・敵対的に検証済み —— Go / Vue + bun / TDD / Git 規律のスタック制約スイート付き。
</p>

<p align="center">
  <a href="https://github.com/0xBB2B/bb-spec/actions/workflows/ci.yml?query=branch%3Amain"><img src="https://img.shields.io/github/actions/workflow/status/0xBB2B/bb-spec/ci.yml?branch=main&style=for-the-badge&logo=github&label=CI" alt="CI ステータス" /></a>
  <a href="https://github.com/0xBB2B/bb-spec/releases"><img src="https://img.shields.io/github/v/release/0xBB2B/bb-spec?include_prereleases&style=for-the-badge&logo=github&color=blue" alt="GitHub release" /></a>
  <a href="https://github.com/0xBB2B/bb-spec/stargazers"><img src="https://img.shields.io/github/stars/0xBB2B/bb-spec?style=for-the-badge&color=yellow&logo=github" alt="GitHub Stars" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge" alt="MIT License" /></a>
  <a href="https://docs.anthropic.com/en/docs/claude-code/overview"><img src="https://img.shields.io/badge/Claude%20Code-Plugin-D97757?style=for-the-badge&logo=anthropic&logoColor=white" alt="Claude Code Plugin" /></a>
</p>

<p align="center">
  <a href="./README.md">English</a> · <a href="./README.zh.md">简体中文</a> · <a href="./README.zh-TW.md">繁體中文</a> · <strong>日本語</strong> · <a href="./README.ko.md">한국어</a>
</p>

<p align="center">
  <a href="#-30-秒で開始">クイックスタート</a> ·
  <a href="#-コアパイプライン-spec--ship">パイプライン</a> ·
  <a href="#-ステージ一覧">ステージ</a> ·
  <a href="#-付属の制約-skills">制約 Skills</a> ·
  <a href="#-claude-code-インストール--install">インストール</a> ·
  <a href="#-デフォルトで有効な-hooks">Hooks</a> ·
  <a href="#-設計の系譜先行事例と比較">設計の系譜</a>
</p>

---

## 🚀 30 秒で開始

```bash
/plugin marketplace add 0xBB2B/bb-spec
/plugin install bb-spec-core@0xbb2b
/plugin install bb-spec-workflow@0xbb2b
```

メインパイプラインの 6 コマンド:

| コマンド | 何をするか | いつ使うか |
|---|---|---|
| `/spec` | 要件を 1 ルール 1 ファイルの spec に分解 | 新規要件の着手時 |
| `/plan` | spec → 関数レベルの実装計画 | spec 完成後 |
| `/exec` | 3 エージェント隔離で Test→Impl→Review を実行 | plan 完成後 |
| `/test-webview` / `/test-api` | Docker フルスタック起動 + 受け入れ(オプション) | フロント / バックエンド e2e |
| `/review` | 並列 finder + 敵対的検証 | PR 提出前 |
| `/git-push` | pre-review セルフチェック + push + PR 作成 | リリース準備時 |

いつでも介入可能な 4 つの支線:`/git-clone`(リモートプロジェクトをローカルに取得 + `.bb-spec.yaml` を生成するワンショット onboarding)、`/init-spec`(既存プロジェクトの逆 spec 化)、`/revise`(あらゆる逸脱を根本原因に基づき正しいステージに戻す)、`/doc-update`(リポジトリ全体の spec / ドキュメント / コード一貫性チェック)。

オプションの上流:`/prd`(PM / 依頼者が PRD をブレストする、bb-spec-product として単独提供)。

---

## 🔁 コアパイプライン `spec → ship`

```
 (任意) /git-clone ──► リモート取得 + .bb-spec.yaml 生成
                  │
 (任意) /prd ──► PRD ドキュメント
                  │
 /init-spec ──►  /spec ──► /plan ──► /exec ──► /test-* ──► /review ──► /git-push
 (既存リポ)      何を作るか  どう作るか  Red→Green→Review  e2e        並列+敵対     pre-review+PR 作成
                                                                                       │
        ┌──────────────────────────────────────────────────────────────────────────────┘
        │
        ▼ /revise(いつでも介入、根本原因でルーティング)
          spec 欠陥 → /spec   ·   実装ドリフト → /exec   ·   review 指摘 → ピンポイント修正

 /doc-update(定期 / 必要時) — リポ全体のドリフト走査 → デフォルトは spec/ドキュメントを更新、
                                  明らかに不適切なコードは止まって確認 → /revise へルーティング
```

**このパイプラインが信頼できる理由** —— すべての受け渡しが**ディスク上のファイル**であり、チャット内の一時記憶ではない。これが再開可能・AI 交代可能・端から端までトレース可能な根本である。

### 🎯 ステージ一覧

- **`/git-clone`** — *ワンショット onboarding*:リモートリポジトリをローカルに取得し `.bb-spec.yaml` を書き出す。
  - **AskUserQuestion 2 連発**:① 単一リポ / マルチリポワークスペース(ディレクトリ構造を決定) ② `base_dir`(以降すべての bb-spec 成果物の配置を決定)
  - **マルチリポワークスペース**は共通の親ディレクトリを作り各メンバーリポジトリを個別に clone(ビルドツールが期待する相対配置を復元)、ネスト禁止・上書き禁止
  - 責務を厳格に絞る:**コード取得 + `base_dir` 書き込みのみ**、コードは読まず・依存もインストールせず・`/init-spec` も発火させない

- **`/init-spec`** — 既存プロジェクトを*逆* spec 化。
  - 既存のコード + ドキュメントを読み、**すでに実行されている暗黙の規範**を ≤100 行・1 ファイル 1 ルールの spec に蒸留、`/spec` と同じ構造で配置
  - 大規模プロジェクトはパーティション分割でサブエージェントを並列実行;初回導入時に一度だけ実行

- **`/spec`** — 対話で要件分解、**「何を作るか」**に答える。
  - 1 ファイル 1 ルール、≤100 行、1 件 + 1 例のみ、互いに重複なし
  - 軽量な `INDEX.md` が統率、読み手はインデックスをスキャンしてから必要に応じて読み込む

- **`/plan`** — spec → 自己完結型・**関数レベル**の実装計画、**「どう作るか」**に答える。
  - 1 ファイル 1 独立問題、関数名と責務まで詳細化;宣言型成果物(DDL / API 契約 / 設定)は**最終成果物の形で直接インライン**、exec はそのまま書き出す
  - 呼び出し時に **plan モードの読み取り専用整合**に入り、承認後にのみ書き出し;**新規追加の第三者依存は独立セクション**、承認は version-policy が要求するユーザー同意とみなす
  - 規模を自動判別:小規模要件は単一 topic;マルチドメイン / 大量 spec 流入時は**バッチ ROADMAP** に切替——依存関係 + 検証ゲートを含み、現在のバッチのみ展開、通過後に次のバッチを自動展開

- **`/exec`** — **3 エージェント隔離実行**、不正対策のコア設計。
  - *Test* エージェントは spec ルールのみ読んで失敗テストを書く(Red)
  - *Impl* エージェントは **spec を見ない**、テスト + 関数リストのみ見て実装を書く(Green)、「意図に合わせて不正」できない;新規追加の第三者ライブラリは plan で承認された依存リストに制限
  - *Review* エージェントは spec と照合してチェック、読み取り専用
  - 各ステップの進捗を `PROGRESS.md` に記録、token 枯渇でも**ロスレス再開**可能

- **`/test-webview`** — フロントエンド / ウェブプロジェクトの**インタラクション受け入れ**。
  - Docker フルスタック起動(初回確認後に記憶、終了後 `down -v` でクリーンアップ)、ブラウザ MCP で実ブラウザを駆動
  - **各ケースに隔離されたシリアルサブエージェントを割り当て**、数百ケースでもメインコンテキストを溢れさせない;全工程シリアル(ブラウザ単一インスタンス)
  - ケースは spec / plan / PRD から自動生成;実行前に**カバレッジ整合**、ギャップを暗黙に見逃さない;失敗は `/revise` へ
  - ブラウザ MCP(playwright / chrome-devtools)が必要

- **`/test-api`** — バックエンド**API e2e**。
  - `compose.e2e.yaml` でフルスタック起動、md ケースを**機械的に単一ファイルの Bun TS runner にレンダリング**、`bun run` で一発実行
  - **サブエージェントゼロ、並列ゼロ** —— HTTP は決定的スクリプト、時計状態は共有のため並列禁止
  - **時間依存ルール**(token 期限切れ、注文タイムアウト、ポイント期限)は `/test/advance-time`、`/test/backdate`、`/test/trigger-job` プロトコルでテスト
  - アプリ側は**2 つのイメージを出力**:test イメージは `/test/*` ルート + `ENV TESTAPI=1` 搭載;本番イメージは `/test/*` ソースを**物理的に除外**;`/test/healthz` プローブが失敗したら中断、フォールバック禁止

- **`/review`** — Workflow オーケストレーション、**敵対的検証**付きのローカル PR review。
  - フェーズ 1 で **5 つの finder** を並列実行:コード品質 / セキュリティ / 簡潔性 / ドキュメント同期 / **Codex クロスモデル独立** review、schema 強制で構造化
  - フェーズ 2 で各 🔴/🟡 を **3 つの独立懐疑視点**で再判定(重要性 / 根本原因性 / 未修正リスク)、多数決で残否を決定
  - 読み取り専用、絶対に自動編集しない;Claude Code ≥ 2.1.154 が必要

- **`/revise`** — いつでも介入可能な例外処理。
  - 逸脱を**根本原因で 3 分類**:*spec 欠陥*(→ `/spec`)、*実装ドリフト*(→ `/exec`)、*要件変更*
  - 修正が必要なすべての review 指摘はここに集約

- **`/git-push`** — ユーザートリガーの push + PR フロー(単一 / マルチリポジトリ)。
  - spec `INDEX.md` がある場合、まず**ブランチ規範セルフチェック(pre-review)**を実行:サブエージェントが spec vs ブランチ diff を比較、違反を反復修正
  - **6 セクションの PR 説明**(背景 / 要件 / アプローチ / 結果 / テスト / 規範、< 50 行)を起草、そのまま PR body として使用

- **`/doc-update`** — リポジトリ全体の spec / ドキュメント / コード**一貫性チェック**。
  - 6 種類のドリフト分類:spec-stale / doc-stale / code-violation / spec-conflict / orphan-index / uncovered-rule
  - **コードが真実、spec / ドキュメントはコードに合わせる**;コードが明らかに硬制約に違反する場合のみ止まって確認、`/revise` 経由で TDD へ
  - `/init-spec`(ゼロ → 存在)、`/revise`(単点)、`/review` の `review-doc-sync`(PR diff スコープ)との境界を明確化

**同梱されるもの**

- **11 個のオーケストレーションサブエージェント**(上記ステージに駆動される):`test-engineer` / `impl-engineer` / `spec-reviewer` / `webview-test-runner` / `review-code-quality` / `review-security` / `review-simplicity` / `review-doc-sync` / `review-codex` / `pre-reviewer` / `rule-extractor`
- **4 つの受動 hook**(自動発動):npm/yarn ブロック、main コミットブロック、依存バージョンセルフチェック、Stop 時の 4 項目セルフチェック

---

## 🧩 付属の制約 Skills

上記のパイプラインにルールを供給する —— 必要なレイヤーのみインストール。

### bb-spec-product — プロダクト要件(パイプライン上流)

- **`prd`** — PM / 依頼者が AI とブレスト:質疑前置(却下も有効な結末)→ 発散 → 収束、自己完結型 PRD を生成 —— 目標 / 非目標、優先度付きユーザーストーリー(各 P0 に具体的ユースケースと受け入れ基準を付与)、エンジニアに残す未解決の質問;git リポやコード文脈は不要、`/spec` が直接消費

> **PM は Claude Code 不要**:リリースごとに [`bb-spec-prd-skill.zip`](https://github.com/0xBB2B/bb-spec/releases/latest/download/bb-spec-prd-skill.zip) を自動パッケージング、ダウンロード後 claude.ai ウェブ版 / デスクトップ版の **Settings → Customize → Skills** からアップロードすれば skill 単独で利用可能(有料プランかつコード実行有効化が必要)、生成された PRD はダウンロード可能なファイルとしてエンジニアに引き渡し。

### bb-spec-core — 汎用規律

- **`tdd-workflow`** — Red-Green-Refactor 規律、追加 / 修正 / 削除 3 シナリオの標準フローをカバー
- **`version-policy`** — 標準 / 公式ライブラリ優先、新規第三者ライブラリ導入はユーザーの明示的同意が必要(plan で承認された依存リストは同意とみなす);バージョン固定前に依存の公式最新版を確認、訓練記憶に頼ることを禁止
- **`git-workflow`** — ブランチ決定、段階的 commit、6 セクション PR 説明、マージ後クリーンアップ

### bb-spec-backend — バックエンドスタック制約

- **`golang-constraints`** — Go のフルライフサイクル:3 層アーキテクチャ、過剰抽象禁止、テストは本番設計に従属
- **`golang-testing`** — Go テスト構成:table-driven、subtests、benchmark、fuzz
- **`api-design`** — REST 設計:リソース命名、ステータスコード、ページネーション、`A-BBB-CCCC` 構造化エラーコード
- **`database-constraints`** — アプリ層 UUIDv7 主キー、ソフトデリート + 複合 UNIQUE、DB 管理タイムスタンプ、エンドツーエンド UTC
- **`auth-constraints`** — 認証(authN):デュアル token(JWT + 不透明 refresh)ローテーション + リプレイ検出、スライディング有効期限、argon2id
- **`authz-constraints`** — 認可(authZ):デフォルト拒否、判定集中、粗粒度ロール + 細粒度リソース ownership の 2 段階チェックで IDOR 防止
- **`observability-constraints`** — ログ / トレース / メトリクスを OTel ベースで:一度組み立て、構造化 JSON + 安定 trace_id、ラベル基数制限
- **`service-constraints`** — ランタイムガバナンス:env 注入シークレットの fail-fast、グレースフルライフサイクル、書き込み冪等性、タイムアウト + 安全なリトライ
- **`config-constraints`** — 設定キャリアの 3 分類:env/secret は起動必須かつホット更新不可、yaml/configmap はホット更新可能なデフォルト値、DB は動的ビジネス設定;コア認証情報は secret/KMS のみ、DB に降ろす場合は envelope encryption 必須

### bb-spec-frontend — フロントエンドスタック制約

- **`vue-constraints`** — Vue 3 + TypeScript + Vite + Tailwind + bun スタック強制制約
- **`frontend-constraints`** — エンジニアリング規約:統一リクエスト client、エラーコード→UI マッピング集中、UX のみのルートガード、契約由来の型

---

## 📦 Claude Code インストール / Install

BB-Spec は**5 つの独立インストール可能なサブ plugin** に分割 —— 必要な制約レイヤーのみインストール。

まず一度 marketplace を追加(Claude Code 内で実行):

```bash
/plugin marketplace add 0xBB2B/bb-spec
```

次に必要なレイヤーをインストール:

| サブ plugin | 何が手に入るか | インストールコマンド |
|---|---|---|
| **bb-spec-core** _(推奨ベース)_ | TDD / バージョンポリシー / Git 規律 + 3 つの受動 hook | `/plugin install bb-spec-core@0xbb2b` |
| **bb-spec-workflow** _(コア機能)_ | spec → plan → exec → test-webview / test-api → review → revise → git-push、git-clone ワンショット初期化、init 逆 spec、doc-update リポ全体一貫性メンテ + 11 サブエージェント | `/plugin install bb-spec-workflow@0xbb2b` |
| **bb-spec-product** | /prd 要件ブレスト → 具体的ユースケース付き PRD ドキュメント(PM / 依頼者向け) | `/plugin install bb-spec-product@0xbb2b` |
| **bb-spec-backend** | Go / REST API / DB / 認証 / 認可 / 可観測性 / サービスガバナンス / 設定制約 | `/plugin install bb-spec-backend@0xbb2b` |
| **bb-spec-frontend** | Vue 3 + TS + Vite + Tailwind + bun スタック & エンジニアリング規約(bun hook 付き) | `/plugin install bb-spec-frontend@0xbb2b` |

必要に応じて選択 —— 例えば規律とワークフローのみでスタック意見なし:`bb-spec-core` + `bb-spec-workflow`;PM / 依頼者のマシン:`bb-spec-product` のみ;フルセット:5 つすべて。

または `~/.claude/settings.json` に手動追加(必要なものだけ enable):

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

## 🔄 バージョンと更新 / Versioning

```bash
/plugin update                  # インストール済みすべての plugin をチェックし更新
/plugin update bb-spec-core     # 特定のサブ plugin のみ更新
```

5 つのサブ plugin は単一の同期されたバージョンラインを共有。

---

## 🪝 デフォルトで有効な Hooks

各 hook は「その関心事を担当するサブ plugin」と一緒に配布 —— 対応する plugin をインストールして初めて利用可能。

| Hook | 所属サブ plugin | トリガータイミング | 効果 |
|---|---|---|---|
| `block-non-bun-pm` | bb-spec-frontend | PreToolUse(Bash) | `npm` / `yarn` / `pnpm` のパッケージ管理動作をブロックし `bun` を強制;既存プロジェクトで対応する lockfile(例 `package-lock.json`)がある場合は通過 |
| `git-workflow-guard` | bb-spec-core | PreToolUse(Bash) | `main` / `master` ブランチでの `git commit` をブロック;他の git フロー動作(ブランチ作成 / push / worktree / merge / PR)は通過させ git-workflow 規律とリアルタイム git ステータスを注入 |
| `dep-version-check` | bb-spec-core | PostToolUse(Write\|Edit) | 依存ファイル編集後に「公式最新版を先に確認」セルフチェックリマインダを注入 |
| `stop-self-check` | bb-spec-core | Stop | タスク終了前に 4 項目のセルフチェックを強制:一時ファイル / 変更範囲 / 孤立した残滓 / レガシー残骸 |

---

## 🧪 テスト

```bash
bash tests/validate.sh
```

マルチ plugin 構造を検証:marketplace.json の妥当性と plugin エントリ一貫性(各 `source` は実在し、かつ名前が一致する plugin ディレクトリを指す)、各サブ plugin の plugin.json フィールド、agent frontmatter の完全性(必須フィールド、名前一貫性、有効な agent-type 値、セキュリティベースラインセクション)、skill SKILL.md フォーマット、hooks.json の妥当性とスクリプト存在、個人パス漏洩検出。

CI は PR と main への push で自動実行(`.github/workflows/ci.yml`)。

---

## 🛠️ 推奨コンパニオン

### CLAUDE.md テンプレート

リポジトリルートの [`CLAUDE.template.md`](./CLAUDE.template.md) は付属の「鉄則インデックス」リファレンス。**自動インストールされない** —— 必要に応じて `~/.claude/CLAUDE.md` またはプロジェクトルートの `CLAUDE.md` にコピーし、好みに合わせて削減。

### .bb-spec.yaml プロジェクト設定

`/prd`、`/spec`、`/plan` はデフォルトで `.bb-spec/docs/` 配下に出力(`.bb-spec/docs/prd/`、`…/spec/`、`…/plan/`);ランタイムの一過性成果物(webview スクリーンショット等)は隣接する `.bb-spec/.cache/` へ(自動 gitignore)。プロジェクトルートに `.bb-spec.yaml` を作成して bb-spec ルートディレクトリを上書き可能:

```yaml
base_dir: my/bb  # → my/bb/docs/{prd,spec,plan,test}/ と my/bb/.cache/ ; ./ を指定するとプロジェクトルートに直接配置
```

参考テンプレート:[`.bb-spec.template.yaml`](./.bb-spec.template.yaml)。

---

## ⚙️ Hook スイッチ早見表

| シナリオ | スイッチ |
|---|---|
| 一時的に npm / yarn / pnpm を許可 | `bb-spec-frontend` を一時的に無効化 |
| 一時的に main commit を許可 | `bb-spec-core` を一時的に無効化 |
| Stop セルフチェックをスキップ | スイッチなし —— これはコアの鉄則、スキップは推奨されない |

---

## 💡 設計の系譜:先行事例と比較

BB-Spec は 3 つの優れたプロジェクトの肩の上に立つ。それぞれが BB-Spec 設計の異なる部分を形作った —— 以下の表でその功績を称え、BB-Spec が何を借用し、そのアイデアをどこまで推し進めたかを示す。

| プロジェクト | 何が最も得意か | BB-Spec が借用し強化した点 |
|---|---|---|
| [**Superpowers**](https://github.com/obra/Superpowers)(obra)—— 完全なコーディングエージェント方法論 | エンドツーエンドのステージ化ワークフロー、サブエージェント駆動開発 + 段階的レビュー、TDD レッド-グリーン-リファクタ、git worktree 隔離、ソクラテス式ブレスト、構成可能なスキルライブラリ | `spec → ship` パイプライン全体の骨格、ロール別サブ Agent 協調、強制 TDD、多段階 / 敵対的レビュー、対話先行の要件明確化 |
| [**ECC**](https://github.com/affaan-m/ECC)(affaan-m)—— エージェントハーネスの「オペレーティングシステム」 | agents / skills / hooks / rules の大規模階層体系、受動 hook の自動強制、インフラとしてのルール、セッション横断記憶持続化 | 階層化された独立インストール可能なサブプラグインスイート、受動 hook による規律強制、エンジニアリング規約をロード可能な制約 skill として沈殿 |
| [**skills**](https://github.com/mattpocock/skills)(mattpocock)——「Skills For Real Engineers」 | 真の失敗モード(要件不整合 / 冗長性 / 品質 / アーキテクチャ)に焦点、意図を整合させる深掘り質問、共有ドメイン言語、ユーザー呼び出し vs モデル呼び出し双形態 skill、垂直スライス | 質疑前置、コーディング前の対話で要件確定、デュアルトリガー skill(slash コマンド + モデル自動トリガー)、1 ファイル 1 ルールのミニマリズム |

**BB-Spec 独自の選択** —— 3 つのいずれも同時に備えない差別化要素:

- **3 エージェント隔離実行** —— Impl エージェントは*物理的に spec を見ない*、テストのみ見るため「意図に合わせてごまかす」ことが不可能;テスト、実装、レビューは互いに見えない 3 者がそれぞれ完成。
- **唯一の受け渡しとしてのディスクドキュメント** —— 各ステージの受け渡しはチャット記憶ではなくファイル、そのためセッション横断、`/clear`、さらには別モデルへの引き継ぎでもロスレス再開可能。
- **spec ⇄ code 双方向ループ** —— spec → code だけでなく、`/init-spec` で既存コードから逆方向に spec を沈殿させ、`/doc-update` でコードドリフトに対して継続的に追従。

---

## 📜 License

MIT —— 詳細は [LICENSE](./LICENSE) を参照。

<p align="center">
  <sub>Built with ❤️ for the Claude Code community.</sub>
</p>
