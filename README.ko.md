<p align="center">
  <img src="./assets/banner.jpg" alt="bb-spec — A light-weight protocol for building trust" width="100%" />
</p>

<h1 align="center">📐 BB-Spec</h1>

<p align="center">
  <strong>모호한 요구사항을 출시 가능한 코드까지 운반하는 PRD 기반 Claude Code 파이프라인.</strong>
</p>

<p align="center">
  모든 단계가 추적 가능 · 재개 가능 · 적대적으로 검증됨 —— Go / Vue + bun / TDD / Git 규율 스택 제약 스위트 동반.
</p>

<p align="center">
  <a href="https://github.com/0xBB2B/bb-spec/actions/workflows/ci.yml?query=branch%3Amain"><img src="https://img.shields.io/github/actions/workflow/status/0xBB2B/bb-spec/ci.yml?branch=main&style=for-the-badge&logo=github&label=CI" alt="CI 상태" /></a>
  <a href="https://github.com/0xBB2B/bb-spec/releases"><img src="https://img.shields.io/github/v/release/0xBB2B/bb-spec?include_prereleases&style=for-the-badge&logo=github&color=blue" alt="GitHub release" /></a>
  <a href="https://github.com/0xBB2B/bb-spec/stargazers"><img src="https://img.shields.io/github/stars/0xBB2B/bb-spec?style=for-the-badge&color=yellow&logo=github" alt="GitHub Stars" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge" alt="MIT License" /></a>
  <a href="https://docs.anthropic.com/en/docs/claude-code/overview"><img src="https://img.shields.io/badge/Claude%20Code-Plugin-D97757?style=for-the-badge&logo=anthropic&logoColor=white" alt="Claude Code Plugin" /></a>
</p>

<p align="center">
  <a href="./README.md">简体中文</a> · <a href="./README.en.md">English</a> · <a href="./README.zh-TW.md">繁體中文</a> · <a href="./README.ja.md">日本語</a> · <strong>한국어</strong>
</p>

<p align="center">
  <a href="#-30초-만에-시작">빠른 시작</a> ·
  <a href="#-핵심-파이프라인-prd--ship">파이프라인</a> ·
  <a href="#-단계-개요">단계</a> ·
  <a href="#-동반-제약-skills">제약 Skills</a> ·
  <a href="#-claude-code-설치--install">설치</a> ·
  <a href="#-기본-활성화-hooks">Hooks</a> ·
  <a href="#-설계-유래-선행-사례와-비교">설계 유래</a>
</p>

---

## 🚀 30초 만에 시작

```bash
/plugin marketplace add 0xBB2B/bb-spec
/plugin install bb-spec-core@0xbb2b
/plugin install bb-spec-workflow@0xbb2b
```

일상적으로 직접 입력하는 5개 명령:

| 명령 | 무엇을 하는가 | 언제 사용 |
|---|---|---|
| `/prd` | 질의→명확화→분해, PRD + AGENTS.md를 작성한 뒤 읽고 한 번 승인하면 plan → exec → doc-update를 자동 실행 | 새 요구사항 착수 시, 머지된 기능의 동작을 바꿀 때 |
| `/revise` | 근본 원인 진단→표적 수정→회귀 검증, 완료 후 doc-update 자동 실행 | 버그나 기대와 다른 결과가 나왔을 때 |
| `/git-push` | pre-review 자가 점검 + push + PR 생성 | PR을 올릴 때 |
| `/exec` | 중단된 지점부터 plan 실행 재개 | 중단이나 `/clear` 이후 |
| `/doc-update` | 저장소 전체의 문서와 코드 일관성 점검 | 저장소 전체를 점검하고 싶을 때(`/exec`·`/revise` 마무리 시 이번 브랜치 범위는 자동 점검) |

최초 설정은 `/git-clone`(원격 프로젝트를 로컬로 가져오기 + `.bb-spec.yaml` 생성); 선택 명령: `/test-webview` / `/test-api`(프론트 / 백엔드 e2e).

---

## 🔁 핵심 파이프라인 `prd → ship`

```
 (선택) /git-clone ──► 원격 가져오기 + .bb-spec.yaml 생성
   │
 /prd ══► /plan ══► /exec ══► /doc-update ──► /git-push
 무엇을   어떻게    Red→Green 문서 동기화     pre-review+PR 생성
 (유일한 승인)      →Review

 ══► 자동 연결(신규 제3자 의존성이나 설계 판단이 필요할 때만 멈춤)
 ──► 사용자가 수동으로 실행

 (선택) /test-webview · /test-api — PR 전 추가 점검:
        프론트 e2e / 백엔드 e2e, /doc-update 와 /git-push 사이에 삽입

 /revise (언제든 개입, 근본 원인으로 라우팅, 완료 후 /doc-update 자동 실행)
   PRD 결함 → 이 브랜치의 PRD 수정   ·   구현 드리프트 → TDD 수정   ·   큰 요구사항 변경 → /prd

 /doc-update (수동) — 저장소 전체의 문서와 코드 드리프트 스캔 → 기본은 문서 갱신,
                      프로젝트 제약을 위반한 코드는 멈추고 확인 → /revise로 라우팅
```

**이 파이프라인이 신뢰할 만한 이유** —— 모든 인계물은 **디스크 상의 파일**이며 채팅 내 일시 기억이 아니다. 이것이 재개 가능, AI 교체 가능, 종단 간 추적 가능의 근본이다.

### 🎯 단계 개요

- **`/git-clone`** — *일회성 onboarding*: 원격 저장소를 로컬로 가져오고 `.bb-spec.yaml`을 작성한다.
  - **AskUserQuestion 2연발**: ① 단일 리포 / 멀티 리포 워크스페이스(디렉터리 구조 결정) ② `base_dir`(이후 모든 bb-spec 산출물의 배치 결정)
  - **멀티 리포 워크스페이스**는 공통 부모 디렉터리를 만들고 각 멤버 저장소를 개별 clone(빌드 도구가 기대하는 상대 배치 복원), 중첩 금지·덮어쓰기 금지
  - 책임을 엄격히 좁힘: **코드만 가져오고 `base_dir`만 작성**, 코드를 읽지 않고·의존성을 설치하지 않음

- **`/prd`** — 새 요구사항의 유일한 입구, **"무엇을, 왜 만들 것인가"**에 답한다. 머지된 기능이나 도입 전 옛 코드의 동작을 바꿀 때도 아무리 작아도 여기서 시작한다(예: 타임아웃을 120초에서 600초로 변경, 버튼 문구를 "제출"에서 "저장"으로 변경). 새 PRD에 이번 트레이드오프를 남긴다.
  - 질의 전치("만들 가치가 없다"도 유효한 결론) → 점진적 명확화 → 분해, 정렬 단계는 **읽기 전용**이며, 요구사항이 화면에 영향을 주면 먼저 HTML 미리보기 페이지로 확인을 받음; PRD 작성 후 대화상자로 읽었는지와 승인 여부를 확인하며, 사용자는 **이 한 번만 승인**하고, 승인 후 `/plan` → `/exec` → `/doc-update`까지 자동 실행
  - **PRD**(`docs/prd/<날짜>.<주제>/`: 배경, 목표, 비목표, 사용자 스토리, 테스트 가능한 제약과 인수 조건, 결정 기록)와 **AGENTS.md**(프로젝트 전체에 적용되는 제약, 예: "제네릭 금지")를 작성
  - PRD는 이 브랜치 안에서는 수정 가능(구현 중 설계 문제를 발견하면 바로 수정), 머지 후에는 동결; **코드가 "지금 무엇을 하는가"의 유일한 출처**이며 PRD는 "왜"에만 답함
  - 이후 모든 commit에 `Requirement: <PRD 디렉터리명>` 태그를 붙임: `git log -L :함수:파일`로 그 함수를 바꾼 요구사항을 나열하고, 해당 PRD의 결정 기록을 읽으면 당시 왜 그렇게 설계했는지 알 수 있음
  - 멀티 저장소 워크스페이스 지원(예: `docs/`와 각 서비스가 독립 저장소): PRD와 AGENTS.md는 문서 저장소에 두고, 모든 저장소의 commit에 태그를 붙임

- **`/plan`** — PRD → 자기 완결형, **함수 수준** 구현 계획, **"어떻게 만들 것인가"**에 답한다.
  - 한 파일 한 독립 문제, 함수명과 책임까지 상세화; 선언형 산출물(DDL / API 계약 / 설정)은 **최종 산출물 형태로 직접 인라인**, exec이 그대로 작성
  - `/prd`가 자동 호출하며 산출 후 바로 `/exec`를 실행; **신규 제3자 의존성**이 필요할 때만 멈추고 사용자 동의를 구하며, 동의는 version-policy가 요구하는 승인으로 간주
  - plan은 실행 중에만 존재하며, 전부 완료되면 `/exec`가 삭제해 PRD와의 중복을 피함

- **`/exec`** — **3 에이전트 격리 실행**, 부정행위 방지 핵심 설계.
  - *Test* 에이전트는 PRD 제약만 읽고 실패 테스트를 작성(Red)
  - *Impl* 에이전트는 **PRD를 보지 않음**, 테스트 + 함수 목록만 보고 구현 작성(Green), "의도에 맞춰 부정"할 수 없음; 신규 제3자 라이브러리는 plan에서 승인된 의존 목록에 제한
  - *Review* 에이전트는 PRD 인수 조건과 AGENTS.md에 대조하고 견고성/보안 관점으로도 점검, 읽기 전용
  - 각 단계의 진행을 `PROGRESS.md`에 기록, token 소진 시에도 **무손실 재개** 가능
  - 구현 중 설계 문제를 발견하면 멈추고 선택을 요청: 코드 수정 / 이번 PRD 수정 / 일시 중지; 작은 수정은 그 자리에서, 큰 수정은 `/prd`로 돌아가 재승인
  - 전부 완료되면 `/doc-update` 마무리 모드를 자동 실행해 이번 PRD와 README 등 문서를 실제 결과물에 맞춤

- **`/doc-update`** — 문서와 코드의 **일관성 점검**.
  - 4종 발견 분류: doc-stale(루트 문서 만료) / prd-stale(이 브랜치 PRD와 결과물 불일치) / code-violation(코드가 AGENTS.md 위반) / agents-conflict(프로젝트 제약 간 모순)
  - **코드가 진실, 문서는 코드에 맞춤**; 코드 수정은 항상 먼저 확인하고 `/revise`를 통해 TDD로 진행; 머지된 PRD는 어떤 모드에서도 건드리지 않음
  - 프로젝트 루트의 **ARCHITECTURE.md** 개요(어떤 모듈이 있고, 어디에 있으며, 어떻게 협력하는지; 테이블과 API는 개요만) 유지: 전체 모드에서는 없으면 코드를 읽어 초안을 쓰고 승인 후 저장; 마무리 모드에서는 이번 브랜치의 모듈 추가·삭제·이동, 테이블·API 그룹 변경에 맞춰 자동으로 갱신. AI는 현황을 파악할 때 먼저 이 문서로 모듈을 찾은 뒤 코드를 읽음
  - **마무리 모드**(`--tail`): `/exec`, `/revise` 종료 시 자동 호출, 이번 브랜치 변경과 관련된 범위만 처리

- **`/git-push`** — 사용자 트리거 push + PR 흐름(단일 / 다중 저장소).
  - `ocr`([open-code-review](https://github.com/alibaba/open-code-review))이 설치되어 있으면 rebase 직후 `ocr review`를 한 번 실행: Claude가 지적 사항을 코드로 하나씩 검증하고 수정 권장 항목을 🔴/🔶/🔷 우선순위로 나열, 선택한 항목을 `/revise`로 수정
  - AGENTS.md 또는 이 브랜치의 PRD가 있거나 이 브랜치의 commit이 병합된 PRD를 가리킬 때 먼저 **브랜치 규범 자가 점검(pre-review)** 실행: subagent가 프로젝트 제약, PRD, commit 본문의 변경 설명 vs 브랜치 diff를 비교, 위반을 반복 수정
  - PR 제목은 저장소의 commit 스타일을 따르고 설명에 `Requirement:` 태그 포함; 저장소는 squash 머지만 허용해야 함(GitHub는 "Allow squash merging"만 + 기본 메시지를 "Default to pull request title and description"로, 메인 브랜치 룰셋의 "Allowed merge methods"도 Squash만, GitLab은 "Fast-forward merge" + squash "Require" + squash 메시지 템플릿을 `%{title}`, 빈 줄, `%{description}`로), 각 PR은 메인 브랜치에 commit 하나로 들어가고 메시지는 PR 제목과 설명이며, 개발 중에 뒤집은 commit은 메인 브랜치에 들어가지 않음
  - **6개 섹션 PR 설명**(배경 / 요구사항 / 접근법 / 결과 / 테스트 / 규범, < 50줄)을 기초하여 그대로 PR body로 사용

- **`/revise`** — 언제든 개입 가능한 예외 처리.
  - 먼저 코드를 읽어 현황을 확인하고 `git log -L`로 관련 PRD를 찾은 뒤, 편차를 **근본 원인으로 3분류**: *PRD 결함*, *구현 드리프트*, *요구사항 변경*
  - 요구사항이 바뀐 경우(*PRD 결함*, *요구사항 변경*): 이 브랜치의 PRD만 수정하고 결정 기록에 추가; PRD가 머지됐거나 없으면 멈추고 `/prd`로 새 PRD를 작성
  - 버그·보안·견고성 문제(*구현 드리프트*): PRD가 머지됐어도 여기서 수정하고, 수정 이유와 트레이드오프(무엇을 골랐고 무엇을 버렸으며 왜인지)를 commit 본문에 기록
  - 수정이 필요한 모든 review 지적은 여기로 집결
  - 수정 후 `/doc-update` 마무리 모드를 자동 실행

- **`/test-webview`** — (선택) 프론트엔드 / 웹 프로젝트의 **상호작용 인수**.
  - Docker 전체 스택 기동(최초 확인 후 기억, 완료 시 `down -v`로 정리), 브라우저 MCP로 실제 브라우저 구동
  - **각 케이스마다 격리된 직렬 subagent 할당**, 수백 케이스에도 메인 컨텍스트를 폭발시키지 않음; 전 과정 직렬(브라우저 단일 인스턴스)
  - 케이스는 이 브랜치 PRD의 인수 조건과 검증 경로에서 자동 생성(머지된 과거 PRD는 읽지 않음); 실행 전 **커버리지 정렬**, 갭을 침묵으로 누락시키지 않음; 실패는 `/revise`로 전환
  - 브라우저 MCP(playwright / chrome-devtools) 필요

- **`/test-api`** — (선택) 백엔드 **API e2e**.
  - `compose.e2e.yaml`로 전체 스택 기동, md 케이스를 **기계적으로 단일 파일 Bun TS runner로 렌더링**, `bun run`으로 한 번에 실행
  - **subagent 제로, 동시성 제로** —— HTTP는 결정적 스크립트, 시계 상태가 공유되므로 동시성 금지
  - **시간 민감 규칙**(token 만료, 주문 타임아웃, 포인트 만료)은 `/test/advance-time`, `/test/backdate`, `/test/trigger-job` 프로토콜로 테스트
  - 앱 측은 **두 개의 이미지 산출**: test 이미지는 `/test/*` 라우트 + `ENV TESTAPI=1` 탑재; 운영 이미지는 `/test/*` 소스를 **물리적으로 제외**; `/test/healthz` 프로브 실패 시 즉시 중단, 폴백 금지

**동봉되는 것**

- **5개 오케스트레이션 subagent**(위 단계에 의해 구동): `test-engineer` / `impl-engineer` / `prd-reviewer` / `webview-test-runner` / `pre-reviewer`
- **4개 수동 hook**(자동 발동): npm/yarn 차단, main 커밋 차단, 의존성 버전 자가 점검, Stop 시 4항목 자가 점검

---

## 🧩 동반 제약 Skills

위 파이프라인에 규칙을 공급 —— 필요한 레이어만 설치.

### bb-spec-core — 범용 규율

- **`tdd-workflow`** — Red-Green-Refactor 규율, 추가 / 수정 / 삭제 3 시나리오 표준 흐름 커버
- **`version-policy`** — 표준 / 공식 라이브러리 우선, 신규 제3자 라이브러리 도입은 사용자의 명시적 동의 필요(`/plan` 단계에서 사용자가 동의한 의존 목록은 동의로 간주); 버전 고정 전 의존성의 공식 최신 버전 확인, 훈련 기억에 의존 금지
- **`git-workflow`** — 브랜치 결정, 단계적 commit, 6개 섹션 PR 설명, 머지 후 정리

### bb-spec-backend — 백엔드 스택 제약

- **`golang-constraints`** — Go 전체 라이프사이클: 3계층 아키텍처, 과잉 추상화 금지, 테스트는 운영 설계에 종속
- **`golang-testing`** — Go 테스트 구성: table-driven, subtests, benchmark, fuzz
- **`api-design`** — REST 설계: 리소스 명명, 상태 코드, 페이지네이션, `A-BBB-CCCC` 구조화 에러 코드
- **`database-constraints`** — 앱 계층 UUIDv7 기본 키, 소프트 삭제 + 복합 UNIQUE, DB 관리 타임스탬프, 종단 간 UTC
- **`auth-constraints`** — 인증(authN): 듀얼 token(JWT + 불투명 refresh) 로테이션 + 재생 탐지, 슬라이딩 만료, argon2id
- **`authz-constraints`** — 인가(authZ): 기본 거부, 판정 집중, 거시 역할 + 미시 리소스 ownership 2단계 체크로 IDOR 방지
- **`observability-constraints`** — 로그 / 트레이스 / 메트릭을 OTel 기반: 일회 조립, 구조화 JSON + 안정된 trace_id, 라벨 카디널리티 제한
- **`service-constraints`** — 런타임 거버넌스: env 주입 시크릿의 fail-fast, 우아한 라이프사이클, 쓰기 멱등성, 타임아웃 + 안전한 재시도
- **`config-constraints`** — 설정 캐리어 3분류: env/secret은 시작 필수이며 핫 업데이트 불가, yaml/configmap은 핫 업데이트 가능한 기본값, DB는 동적 비즈니스 설정; 핵심 자격증명은 secret/KMS만, DB로 내릴 경우 envelope encryption 필수

### bb-spec-frontend — 프론트엔드 스택 제약

- **`vue-constraints`** — Vue 3 + TypeScript + Vite + Tailwind + bun 스택 강제 제약
- **`frontend-constraints`** — 엔지니어링 규약: 통일된 요청 client, 에러 코드→UI 매핑 집중, UX 전용 라우트 가드, 계약에서 유래한 타입

---

## 📦 Claude Code 설치 / Install

BB-Spec은 **4개의 독립 설치 가능한 서브 plugin**으로 분할 —— 필요한 제약 레이어만 설치.

먼저 marketplace를 한 번 추가(Claude Code 내에서 실행):

```bash
/plugin marketplace add 0xBB2B/bb-spec
```

다음으로 필요한 레이어를 설치:

| 서브 plugin | 무엇을 얻는가 | 설치 명령 |
|---|---|---|
| **bb-spec-core** _(권장 베이스)_ | TDD / 버전 정책 / Git 규율 + 3개 수동 hook | `/plugin install bb-spec-core@0xbb2b` |
| **bb-spec-workflow** _(핵심 기능)_ | prd → plan → exec → doc-update → revise → git-push(+ 선택 test-webview / test-api e2e), git-clone 일회성 초기화 + 5개 subagent | `/plugin install bb-spec-workflow@0xbb2b` |
| **bb-spec-backend** | Go / REST API / DB / 인증 / 인가 / 가관측성 / 서비스 거버넌스 / 설정 제약 | `/plugin install bb-spec-backend@0xbb2b` |
| **bb-spec-frontend** | Vue 3 + TS + Vite + Tailwind + bun 스택 & 엔지니어링 규약(bun hook 포함) | `/plugin install bb-spec-frontend@0xbb2b` |

필요에 따라 선택 —— 예를 들어 규율과 워크플로만 필요하고 스택 의견은 불필요: `bb-spec-core` + `bb-spec-workflow` 설치; 풀 세트: 4개 모두 설치.

또는 `~/.claude/settings.json`에 수동 추가(원하는 것만 enable):

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

## 🔄 버전 관리 / Versioning

```bash
claude plugin update bb-spec-workflow@0xbb2b   # 터미널에서 특정 서브 plugin 업데이트
```

한 번에 모두 업데이트하려면: 세션에서 `/plugin`을 실행하고 **Marketplaces** 탭에서 `0xbb2b`를 고른 뒤 **Update marketplace**를 선택.

4개의 서브 plugin은 단일 동기화된 버전 라인을 공유.

### 13 이하 버전에서 업그레이드

마이그레이션은 필요 없습니다. 프로젝트의 기존 `.bb-spec/` 디렉터리는 지워도 되고 남겨 둬도 됩니다. 업그레이드 후 바로 `/prd`로 다음 요구사항을 시작하면 됩니다.

기존 디렉터리를 남겨 두는 경우(아래 `.bb-spec/docs/`는 기본 위치이며, `.bb-spec.yaml`에서 `base_dir`를 바꿨다면 그 설정을 따릅니다):

- 기존 `.bb-spec/docs/spec/`, `.bb-spec/docs/prd/.archive/`, `.bb-spec/docs/plan/INDEX.md`는 읽지도 수정하지도 않습니다.
- `.bb-spec/docs/prd/GLOSSARY.md`가 아직 없으면 `/prd`가 `.bb-spec/docs/spec/GLOSSARY.md`의 용어를 그대로 씁니다. 처음 용어를 등록할 때 표 전체를 새 위치로 복사하고, 기존 표는 그대로 둡니다.
- 13에서 끝내지 못한 plan은 이어서 실행할 수 없으니 `/prd`로 다시 시작하세요. 더 필요 없으면 `plan/INDEX.md`와 거기에 등록된 주제 디렉터리를 `git rm -r`로 지울 수 있습니다.

도입 전에 작성된 기존 코드는 commit에 `Requirement:` 표시가 없어 대응하는 PRD가 없습니다. 버그는 `/revise`로 고치며 사용자가 설명한 기대 동작을 기준으로 합니다. 설계나 동작을 바꿀 때는 `/prd`로 새 PRD를 작성합니다.

`.bb-spec/` 밖에서 직접 처리해야 할 것이 두 가지 있습니다:

1. `bb-spec-product`를 설치했다면 `/plugin uninstall bb-spec-product@0xbb2b`로 제거하세요. `/prd`는 `bb-spec-workflow`로 옮겨졌습니다.
2. 예전 `CLAUDE.template.md`를 CLAUDE.md(전역 `~/.claude/CLAUDE.md` 또는 프로젝트 루트)에 복사했다면, 「任务分流」(작업 분류) 4번 항목의 `/spec → /plan → /exec`를 `/prd`로, 3번 항목의 「有现成 spec/plan/代码可对照」를 「有现成 PRD 或代码可对照」로 바꾸세요.

---

## 🪝 기본 활성화 Hooks

각 hook은 「해당 관심사를 담당하는 서브 plugin」과 함께 배포 —— 대응하는 plugin을 설치해야 사용 가능.

| Hook | 소속 서브 plugin | 트리거 시점 | 효과 |
|---|---|---|---|
| `block-non-bun-pm` | bb-spec-frontend | PreToolUse(Bash) | `npm` / `yarn` / `pnpm`의 패키지 관리 동작을 차단하고 `bun` 강제; 기존 프로젝트에 매칭되는 lockfile(예: `package-lock.json`)이 존재할 경우 통과 |
| `git-workflow-guard` | bb-spec-core | PreToolUse(Bash) | `main` / `master` 브랜치의 `git commit` 차단; 다른 git 흐름 동작(브랜치 생성 / push / worktree / merge / PR)은 통과시키고 git-workflow 규율과 실시간 git 상태 주입 |
| `dep-version-check` | bb-spec-core | PostToolUse(Write\|Edit) | 의존성 파일 편집 후 "공식 최신 버전 먼저 확인" 자가 점검 리마인더 주입 |
---

## 🧪 테스트

```bash
bash tests/validate.sh
```

다중 plugin 구조 검증: marketplace.json 유효성과 plugin 엔트리 일관성(각 `source`가 실재하며 이름이 일치하는 plugin 디렉터리를 가리킴), 각 서브 plugin의 plugin.json 필드, agent frontmatter 완전성(필수 필드, 이름 일관성, 유효한 agent-type 값, 보안 베이스라인 섹션), skill SKILL.md 포맷, hooks.json 유효성 및 스크립트 존재, 개인 경로 누출 탐지.

CI는 PR과 main 푸시 시 자동 실행(`.github/workflows/ci.yml`).

---

## 🛠️ 권장 동반 자료

### AGENTS.md: 프로젝트 제약과 조회 규칙

`/prd`는 프로젝트 전체에 적용되는 제약(예: "제네릭 금지", "SQL join은 3개 테이블 이하")을 프로젝트 루트의 `AGENTS.md`에, 특정 기능에만 속하는 제약은 PRD에 작성하므로 같은 제약이 두 곳에 기록되지 않음. `AGENTS.md`에는 "기능·문제 조회 규칙" 섹션도 있음: "시스템이 지금 어떻게 동작하는가"에 답하려면 먼저 코드를 읽고 `파일:줄 번호`를 제시해야 하며, "왜"를 찾을 때는 `git log -L`로 그 함수를 바꾼 요구사항을 찾아 PRD를 읽고, PRD와 코드가 다르면 코드를 기준으로 함. Claude Code는 `CLAUDE.md`만 읽고 `AGENTS.md`를 직접 읽지 않으므로, `/prd`는 프로젝트 루트 `CLAUDE.md`에 `@AGENTS.md` 한 줄을 넣어 가져오도록 보장함.

### .bb-spec.yaml 프로젝트 설정

`/prd`, `/plan`은 기본적으로 `.bb-spec/docs/` 아래로 출력(`.bb-spec/docs/prd/`, `…/plan/`); 런타임 일시 산출물(예: webview 스크린샷)은 인접한 `.bb-spec/.cache/`로(자동 gitignore). 프로젝트 루트에 `.bb-spec.yaml`을 생성하여 bb-spec 루트 디렉터리를 재정의 가능:

```yaml
base_dir: my/bb  # → my/bb/docs/{prd,plan,test}/ 와 my/bb/.cache/ ; ./을 지정하면 프로젝트 루트에 직접 배치
```

참고 템플릿: [`.bb-spec.template.yaml`](./.bb-spec.template.yaml).

---

## ⚙️ Hook 스위치 치트시트

| 시나리오 | 스위치 |
|---|---|
| 일시적으로 npm / yarn / pnpm 허용 | `bb-spec-frontend`를 일시적으로 비활성화 |
| 일시적으로 main commit 허용 | `bb-spec-core`를 일시적으로 비활성화 |
| Stop 자가 점검 건너뛰기 | 스위치 없음 —— 이것은 핵심 철칙, 건너뛰기 권장하지 않음 |

---

## 💡 설계 유래: 선행 사례와 비교

BB-Spec은 세 개의 우수한 프로젝트의 어깨 위에 서 있다. 각각이 BB-Spec 설계의 다른 부분을 형성했다 —— 아래 표에서 그 공로를 기리고, BB-Spec이 무엇을 차용했으며 그 아이디어를 어디까지 발전시켰는지 설명한다.

| 프로젝트 | 무엇이 가장 뛰어난가 | BB-Spec이 차용하고 강화한 점 |
|---|---|---|
| [**Superpowers**](https://github.com/obra/Superpowers)(obra) —— 완전한 코딩 에이전트 방법론 | 종단 간 단계화된 워크플로, 서브에이전트 기반 개발 + 단계별 리뷰, TDD 레드-그린-리팩터, git worktree 격리, 소크라테스식 브레인스토밍, 조합 가능한 스킬 라이브러리 | 전체 `prd → ship` 파이프라인 골격, 역할별 서브 Agent 협력, 강제 TDD, 다단계 / 적대적 리뷰, 대화 우선 요구사항 명확화 |
| [**ECC**](https://github.com/affaan-m/ECC)(affaan-m) —— 에이전트 하네스 「운영 체제」 | agents / skills / hooks / rules의 대규모 계층 체계, 수동 hook의 자동 강제, 인프라로서의 규칙, 세션 간 메모리 지속화 | 계층화된 독립 설치 가능 서브 플러그인 스위트, 수동 hook으로 규율 강제, 엔지니어링 규약을 로드 가능한 제약 skill로 침전 |
| [**skills**](https://github.com/mattpocock/skills)(mattpocock) —— 「Skills For Real Engineers」 | 실제 실패 모드(요구사항 불일치 / 장황함 / 품질 / 아키텍처)에 초점, 의도를 정렬하는 심층 질문, 공유 도메인 언어, 사용자 호출 vs 모델 호출 이중 형태 skill, 수직 슬라이싱 | 질의 전치, 코딩 전 대화로 요구사항 확정, 듀얼 트리거 skill(slash 명령 + 모델 자동 트리거), 사실의 출처를 하나만 두는 미니멀리즘 |

**BB-Spec 고유의 선택** —— 셋 모두가 동시에 갖추지 못한 차별화 요소:

- **3 에이전트 격리 실행** —— Impl 에이전트는 *물리적으로 PRD를 보지 못함*, 테스트만 보므로 "의도에 맞춰 속임"이 불가능; 테스트, 구현, 리뷰는 서로 보지 못하는 3자가 각각 완성.
- **유일한 인계물로서의 디스크 문서** —— 각 단계의 인계는 채팅 기억이 아닌 파일, 따라서 세션 횡단, `/clear`, 심지어 다른 모델의 인수에서도 무손실 재개 가능.
- **코드 ⇄ PRD를 git으로 양방향 조회** —— 코드가 유일한 사실의 출처이고 PRD는 왜만 기록; 모든 commit에 요구사항 태그가 있어 기능에서 코드를 찾고, 함수에서 당시의 요구사항과 선택을 역조회할 수 있으며, 그 사이에 사람이 동기화해야 하고 낡아 버리는 규칙 문서가 없음.

---

## 📜 License

MIT —— 자세한 내용은 [LICENSE](./LICENSE) 참조.

<p align="center">
  <sub>Built with ❤️ for the Claude Code community.</sub>
</p>
