# BB-Spec

**English** | [中文](./README.zh.md)

> A language-agnostic, **spec-driven Claude Code workflow** — `spec → plan → exec → review → revise → git-push-pr` is the core pipeline — backed by **companion stack-constraint suites** (Go / Vue + bun / TDD / git discipline) and a **multi-agent adversarial review kit**.

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
| **bb-spec-workflow** _(core)_ | spec → plan → exec → review → revise → git-push-pr, init reverse-spec + 8 subagents | `/plugin install bb-spec-workflow@0xbb2b` |
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

## Core — the Workflow pipeline (`spec → ship`)

> **This is the heart of BB-Spec.** A closed-loop, spec-driven pipeline that carries a fuzzy requirement all the way to reviewed, shipped code — every stage traceable, resumable, and adversarially verified. The three constraint suites further down (core / backend / frontend) are **companions** that feed rules into this loop; the loop is the product.

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

**How the stages connect.** The pipeline is a relay, and every handoff is a *file on disk* — not a memory in the chat — which is exactly what makes it resumable, AI-swappable, and auditable end to end: `/spec` turns a fuzzy ask into spec docs under `.bb-spec/docs/spec/` (**what to build**) → `/plan` reads those and emits a function-level plan under `.bb-spec/docs/plan/` (**how to build it**) → `/exec` drives the plan through Test→Impl→Review into tests + code, checkpointing to `PROGRESS.md` → `/review` judges the resulting diff → `/git-push-pr` self-checks against the spec and opens the PR.

Two branches close the loop: **`/init`** is the *on-ramp* for existing projects — it reverse-derives the spec first, then merges into the mainline; **`/revise`** is the *return path* — on any deviation it routes you back to the **right** stage by root cause (spec-defect → `/spec`, impl-drift → `/exec`), not a blind redo.

Each stage, and what sets it apart:

- **`/init`** — *Reverse*-spec an existing project: read the current code + docs and distill the **already-enforced implicit conventions** into ≤100-line, one-rule-per-file specs, landing in the exact structure `/spec` uses so the rest of the pipeline can pick up. Large projects are partitioned across parallel subagents. Run once, on first adoption.
- **`/spec`** — Requirement breakdown through dialogue: clarify a fuzzy ask, then split it into many small, non-overlapping rules — one rule per file, ≤100 lines, *one thing + one example* each — fronted by a lightweight `INDEX.md` readers scan before loading specifics. Answers **"what to build."**
- **`/plan`** — spec → a self-contained, **function-level** implementation plan: each file solves one independent problem, detailed down to function names and responsibilities (but not concrete code), so any AI can implement it from that file alone after a context reset. Answers **"how to build it."**
- **`/exec`** — **Three-agent isolated execution.** A *Test* agent reads only the spec rules and writes failing tests (Red); an *Impl* agent sees only those tests + the function list and writes code (Green) — it never sees the spec, so it can't quietly "teach to intent"; a *Review* agent checks the result against the spec, read-only. Progress is written to `PROGRESS.md` after every step, so a token-exhausted run **resumes losslessly** from the last checkpoint.
- **`/review`** — **Workflow-orchestrated, adversarially-verified** local PR review (current branch vs base). Phase 1 fans out **5 finders in parallel** — code quality, security, simplicity / anti-cruft, doc sync, and a **Codex cross-model independent** pass — with schema-enforced structured findings; after plain-code dedup, **every BLOCKER / IMPORTANT finding is re-judged by 3 independent skeptic lenses** (importance / root-cause / risk-if-unfixed) and kept or dropped by majority vote. Read-only — never auto-edits. Requires Claude Code ≥ 2.1.154 (Workflow tool).
- **`/revise`** — The exception handler, callable anytime: diagnose a deviation's **root cause** into one of three classes — *spec-defect* (→ back to `/spec`), *impl-drift* (→ back to `/exec`), or *requirement-change* — then apply a targeted fix + regression check. Every review finding that needs fixing funnels through here.
- **`/git-push-pr`** — User-triggered push-and-PR flow (single or multi-repo, batch or selective). When a spec `INDEX.md` exists it first runs a **branch-spec self-check (pre-review)**: a subagent diffs the branch vs main against the spec, violations are fixed and re-reviewed in a loop, then a concise **6-section PR description** is drafted (background / requirement / approach / result / tests / spec, < 50 lines) and used directly as the PR body.

Ships **8 orchestration subagents** the stages above drive: `test-engineer` / `impl-engineer` / `spec-reviewer` / `review-code-quality` / `review-security` / `review-simplicity` / `review-doc-sync` / `review-codex`.

Passive constraints (hooks, automatic): block npm/yarn, block main commit, dependency version self-check, Stop four-point self-check.

---

## Companion constraint skills

These feed rules into the pipeline above — install only the layers you need; each skill in one line.

### bb-spec-core — universal discipline

- **`tdd-workflow`** — Red-Green-Refactor discipline with standard flows for the add / modify / delete scenarios
- **`version-policy`** — Check a dependency's official latest version before pinning it; never trust training memory
- **`git-workflow`** — Branch decisions, incremental commits, the six-section PR description, post-merge cleanup

### bb-spec-backend — backend stack constraints

- **`golang-constraints`** — Whole-lifecycle Go: three-layer architecture, no over-abstraction, tests subordinate to production design
- **`golang-testing`** — Go test organization: table-driven, subtests, benchmark, fuzz
- **`api-design`** — REST design: resource naming, status codes, pagination, and structured `A-BBB-CCCC` error codes
- **`database-constraints`** — App-generated UUIDv7 PKs, soft delete + composite UNIQUE, DB-managed timestamps, UTC end to end
- **`auth-constraints`** — Authentication (authN): dual-token JWT + opaque refresh with rotation & replay detection, sliding expiry, argon2id
- **`authz-constraints`** — Authorization (authZ): deny-by-default, centralized decision, two-tier role + resource-ownership checks to stop IDOR
- **`observability-constraints`** — Logs / traces / metrics on OTel: one-time assembly, structured JSON with stable trace_id, bounded label cardinality
- **`service-constraints`** — Runtime governance: env-injected secrets with fail-fast, graceful lifecycle, write idempotency, timeouts + safe retries

### bb-spec-frontend — frontend stack constraints

- **`vue-constraints`** — Vue 3 + TypeScript + Vite + Tailwind + bun hard stack constraints
- **`frontend-constraints`** — Conventions: one unified request client, centralized error-code → UI mapping, UX-only route guards, types from the contract

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
