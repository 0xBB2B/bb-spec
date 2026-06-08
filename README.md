# BB-Spec

**English** | [中文](./README.zh.md)

> A language-agnostic Claude Code workflow constraint suite: **hard Go + Vue + bun stack constraints**, **TDD / anti-legacy-cruft iron rules**, and a **multi-agent local review kit**.

> Output follows your working language. The skills do **not** hardcode an output language — docs, comments, and commit messages come out in whatever language you work in (identifiers, API names, and error codes stay English). Every skill triggers on both English and Chinese phrases.

---

## Install

BB-Spec ships as **four independently installable sub-plugins** — install only the constraint layers you need.

First add the marketplace once, inside Claude Code:

```bash
/plugin marketplace add 0xBB2B/bb-spec
```

Then install whichever layers you want:

| Sub-plugin | What it gives you | Command |
|---|---|---|
| **bb-spec-core** _(recommended base)_ | TDD / version-policy / git-workflow discipline + 3 passive hooks | `/plugin install bb-spec-core@0xbb2b` |
| **bb-spec-workflow** | spec → plan → exec → review → revise → git-push-pr, init reverse-spec + 8 subagents | `/plugin install bb-spec-workflow@0xbb2b` |
| **bb-spec-backend** | Go / REST API / DB / authN / authZ / observability / service constraints | `/plugin install bb-spec-backend@0xbb2b` |
| **bb-spec-frontend** | Vue 3 + TS + Vite + Tailwind + bun stack & engineering conventions (+ bun hook) | `/plugin install bb-spec-frontend@0xbb2b` |

Pick by need — e.g. just the disciplines and workflow without any stack opinions: install `bb-spec-core` + `bb-spec-workflow`. Want everything: install all four.

Or add it manually to `~/.claude/settings.json` (enable only what you want):

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

> **Upgrading from the old single `bb-spec` plugin (≤ 4.x)?** It has been split into the four sub-plugins above. Remove the old one with `/plugin uninstall bb-spec`, then install the layers you need.

## Versioning

```bash
/plugin update                  # check and update every installed plugin
/plugin update bb-spec-core     # update only one sub-plugin
```

The four sub-plugins share a single synchronized version line.

---

## Hooks enabled by default (out of the box)

Each hook ships with the sub-plugin that owns its concern — install that plugin to get it.

| Hook | Sub-plugin | Trigger | Effect |
|---|---|---|---|
| `block-non-bun-pm` | bb-spec-frontend | PreToolUse(Bash) | Blocks `npm` / `yarn` / `pnpm` package-manager actions, enforcing `bun`; existing projects with a matching lockfile (e.g. `package-lock.json`) are allowed through |
| `block-main-commit` | bb-spec-core | PreToolUse(Bash) | Blocks `git commit` on the `main` / `master` branch |
| `dep-version-check` | bb-spec-core | PostToolUse(Write\|Edit) | After editing a dependency file, injects a "check the official latest version first" reminder |
| `stop-self-check` | bb-spec-core | Stop | Forces a four-point self-check before a task ends: temp files / change scope / orphaned leftovers / legacy cruft |

---

## Advanced: optional Hooks (off by default, opt-in)

**bb-spec-workflow** ships two **higher-impact** Stop hooks. They are registered with that plugin but gated at the top of each script, so they **do not run by default** — you must enable them explicitly:

| Hook | Effect | How to enable |
|---|---|---|
| `stop-auto-tests.sh` | On Stop, in a Go project (with `go.mod`) automatically runs `vet` / `golangci-lint` / `test -race` / `make test-integration` and feeds failures back to the AI | `export CLAUDE_ENABLE_AUTO_TESTS=1` or `touch .enable-auto-tests` in the project root |
| `stop-auto-commit.sh` | On Stop, when uncommitted tracked changes are detected, feeds back an instruction for the **AI to commit them itself with a semantic message** (defaults to `git add -u`, non-main/master, no push) | `export CLAUDE_ENABLE_AUTO_COMMIT=1` or `touch .enable-auto-commit` in the repo root |

The environment variable enables a hook at session / global scope (written into your shell rc); the marker file enables it at project scope — use either or both. To disable: `unset` the env var or `rm` the marker file.

---

## Workflow

```
/init  Reverse-spec an existing project (run once on first adoption; parallel partitioned extraction)
  │
  ▼
/spec  Requirement breakdown → one rule per document
  │
  ▼
/plan  spec → function-level implementation plan
  │
  ▼
/exec  Three-agent isolated execution
  │  Test Agent (Red)   — reads spec rules only → writes tests
  │  Impl Agent (Green) — sees tests + function list only → writes implementation
  │  Review Agent       — checks against spec → read-only
  │  PROGRESS.md persistence (resume from checkpoint)
  │
  ▼
/review  Workflow-orchestrated: parallel finders + adversarial verify
  │  quality / security / anti-cruft / over-engineering / Codex
  │  every 🔴/🟡 majority-voted by 3 independent skeptic lenses
  │
  ▼
/git-push-pr  pre-review → push → open PR

  ┌────────────────────────────────────────┐
  │  /revise  exception handling (anytime) │
  │  diagnose root cause → targeted fix →  │
  │  regression                            │
  └──┬──────────────┬──────────────┬───────┘
     ↓              ↓              ↓
   /spec          /exec          /review
  (spec-defect → spec, impl-defect → exec, review findings → fix)
```

Passive constraints (hooks, automatic): block npm/yarn, block main commit, dependency version self-check, Stop four-point self-check.

---

## Skills overview (20, grouped by sub-plugin)

### bb-spec-core — universal discipline

- **`tdd-workflow`** — Universal TDD discipline: Red-Green-Refactor, standard flows for the add/modify/delete scenarios
- **`version-policy`** — Before adding/upgrading a dependency you must check the official latest version; no relying on training memory
- **`git-workflow`** — Branch decisions, incremental commits, the PR three-section description, post-merge cleanup

### bb-spec-workflow — the spec→ship pipeline

- **`spec`** — Requirement breakdown and documentation: one rule per file, ≤100 lines, output to `.bb-spec/docs/spec/`
- **`plan`** — Read specs and produce a step-by-step implementation plan: one unit per file, function-level detail, output to `.bb-spec/docs/plan/`
- **`exec`** — Three-agent isolated plan execution (Test→Impl→Review), PROGRESS.md checkpoint recovery
- **`revise`** — Output revision (bug fix / optimization / requirement change): three root-cause classes (spec-defect / impl-defect / requirement-change) → targeted fix → regression
- **`review`** — Current branch vs base: Workflow-orchestrated, 5 finders in parallel (quality / security / anti-cruft / over-engineering / Codex cross-model), every BLOCKER/IMPORTANT finding adversarially verified by 3 independent skeptic lenses (importance / root-cause / risk-if-unfixed) with majority vote. Requires Claude Code ≥ 2.1.154 (Workflow tool)
- **`init`** — Reverse-spec an existing project: read existing code and docs to infer rules, extract in parallel by partition, landing fully aligned with `/spec` (first adoption only)
- **`git-push-pr`** — User-triggered multi-repo batch / selective push-and-PR flow

Ships 8 orchestration subagents: `test-engineer` / `impl-engineer` / `spec-reviewer` / `review-code-quality` / `review-security` / `review-simplicity` / `review-doc-sync` / `review-codex`.

### bb-spec-backend — backend stack constraints

- **`golang-constraints`** — Whole-lifecycle Go constraints: three-layer architecture, no over-abstraction, tests subordinate to production design
- **`golang-testing`** — Go test organization: table-driven, subtests, benchmark, fuzz
- **`api-design`** — REST API design: resource naming, status codes, pagination, error responses with structured `A-BBB-CCCC` error codes, versioning
- **`database-constraints`** — Relational DB conventions: app-generated UUIDv7 primary keys, soft delete with composite UNIQUE, DB-managed timestamps, UTC everywhere; dialect-agnostic principles + MySQL / PostgreSQL implementation tables
- **`auth-constraints`** — Authentication & session (authN only): dual-token (short-lived JWT access + opaque server-side refresh), mandatory refresh rotation with replay detection, sliding expiry capped by an absolute lifetime, client-held device_id not required to be UUID (UA for display only), argon2id; mechanism skeleton pinned, multi-device policy left to the project
- **`authz-constraints`** — Authorization (authZ, companion to auth-constraints): deny by default / fail-close, backend always enforces while frontend gating is UX only, centralized policy decision (no scattered `if role==`), two-tier checks (coarse role/permission + fine-grained resource ownership to stop IDOR), data-layer tenant isolation when multi-tenant, 401/403 semantics with an enumeration guard, denial auditing; mechanism skeleton pinned, permission model (RBAC/ABAC/ReBAC) / policy engine / roles / tenancy left to the project
- **`observability-constraints`** — Backend observability (logs / traces / metrics): three signals assembled once + globally registered, OTel as the standard with per-signal exporter toggles (local providers stay resident so trace_id is stable), structured JSON logs carrying trace_id / span_id, log-level semantics (WARN = business / ERROR = system), distributed-trace propagation, metric naming + bounded label cardinality, body truncation + credential redaction; mechanism skeleton pinned, sampling / backend / metrics / alert thresholds left to the project
- **`service-constraints`** — Backend service runtime governance (distinct from golang-constraints): config & secrets via env with fail-fast startup validation (no hardcoded secrets), graceful lifecycle (readiness vs liveness, SIGTERM drain + LIFO release), write idempotency via idempotency keys, mandatory cross-process timeouts + context cancel propagation + safe retries (backoff / jitter / cap, idempotent only), error propagation preserving the chain (%w) and converting to api-design codes only at the boundary; mechanism skeleton pinned, concrete timeout / retry / health-check / config-center choices left to the project

### bb-spec-frontend — frontend stack constraints

- **`vue-constraints`** — Vue 3 + TypeScript + Vite + Tailwind + bun hard constraints
- **`frontend-constraints`** — Frontend engineering conventions (convention layer vs vue-constraints' stack layer): build-injected env vars are public (no secrets), one unified request client (no raw fetch in components), centralized error-code → UI mapping, route guards are UX only (backend still enforces), state-management boundary (Pinia for shared client / session state only), two-tier form validation (client instant / server authoritative), API types from the contract (no any); convention skeleton pinned, UI-lib / directory / i18n / query-cache choices left to the project

---

## Tests

```bash
bash tests/validate.sh
```

Validates the multi-plugin structure: marketplace.json validity and plugin-entry consistency (every `source` resolves to a real plugin dir whose name matches), each sub-plugin's plugin.json fields, agent frontmatter integrity (required fields, name consistency, valid agent-type values, security-baseline section), skill SKILL.md format, hooks.json validity and script existence, and personal-path leak detection.

CI runs automatically on PRs and pushes to main (`.github/workflows/ci.yml`).

---

## Recommended companions

### CLAUDE.md template

The repo-root [`CLAUDE.template.md`](./CLAUDE.template.md) is a companion "iron-rule index" reference. It is **not installed automatically** — copy it to your `~/.claude/CLAUDE.md` or a project-root `CLAUDE.md` as needed and trim to taste.

### .bb-spec.yaml project config

`/spec` and `/plan` output to `.bb-spec/docs/spec/` and `.bb-spec/docs/plan/` by default. Create a `.bb-spec.yaml` in the project root to override the base path:

```yaml
docs_dir: my/custom/docs  # → my/custom/docs/spec/, my/custom/docs/plan/
```

Reference template: [`.bb-spec.template.yaml`](./.bb-spec.template.yaml).

---

## Hook switch cheat sheet

| Scenario | Switch |
|---|---|
| Temporarily allow npm / yarn / pnpm | Not provided yet; disable `bb-spec-frontend` temporarily |
| Temporarily allow main commit | Not provided yet; disable `bb-spec-core` temporarily |
| Skip the Stop self-check | No switch — this is a core iron rule, skipping is discouraged |
| Enable stop-auto-tests | `CLAUDE_ENABLE_AUTO_TESTS=1` or `.enable-auto-tests` in the project root |
| Enable stop-auto-commit | `CLAUDE_ENABLE_AUTO_COMMIT=1` or `.enable-auto-commit` in the repo root |

---

## License

MIT
