<p align="center">
  <img src="./assets/banner.jpg" alt="bb-spec — A light-weight protocol for building trust" width="100%" />
</p>

# BB-Spec

**English** | [中文](./README.zh.md)

> **A spec-driven Claude Code pipeline** that carries a fuzzy requirement all the way to reviewed, shipped code — every stage traceable, resumable, and adversarially verified, with companion stack-constraint suites (Go / Vue + bun / TDD / git discipline).

---

## 30-second start

```bash
/plugin marketplace add 0xBB2B/bb-spec
/plugin install bb-spec-core@0xbb2b
/plugin install bb-spec-workflow@0xbb2b
```

The 6 mainline commands:

| Command | What it does | When |
|---|---|---|
| `/spec` | Break a requirement into one-rule-per-file specs | New requirement |
| `/plan` | spec → function-level implementation plan | Spec is ready |
| `/exec` | Three-agent isolated Test→Impl→Review | Plan is ready |
| `/test-webview` / `/test-api` | Docker stack + acceptance (optional) | Frontend / backend e2e |
| `/review` | Parallel finders + adversarial verify | Before opening PR |
| `/git-push` | pre-review self-check + push + open PR | Ready to ship |

Four branches, callable anytime: `/git-clone` (pull a remote project locally + write `.bb-spec.yaml`, one-shot onboarding), `/init-spec` (reverse-spec an existing project), `/revise` (route any deviation back to the right stage by root cause), `/doc-update` (whole-repo spec / doc / code consistency sweep).

Optional upstream: `/prd` (PM / requester brainstorms a PRD; shipped separately as bb-spec-product).

---

## The `spec → ship` pipeline

```
 (opt) /git-clone ──► clone remote + write .bb-spec.yaml
                  │
 (opt) /prd ──► PRD doc
                  │
 /init-spec ──►  /spec ──► /plan ──► /exec ──► /test-* ──► /review ──► /git-push
 (existing repo)  what       how      Red→Green→Review   e2e        finders+adv   pre-review+open PR
                                                                                       │
        ┌──────────────────────────────────────────────────────────────────────────────┘
        │
        ▼ /revise (anytime, routed by root cause)
          spec-defect → /spec   ·   impl-drift → /exec   ·   review finding → targeted fix

 /doc-update (periodic / on-demand) — sweep whole repo → default updates spec/doc;
                                        obviously bad code stops to ask → routes to /revise
```

**Why this pipeline is reliable** — every handoff is a *file on disk*, not a memory in the chat. That's what makes it resumable, AI-swappable, and auditable end to end.

### Stages at a glance (one-line role + key differentiators)

- **`/git-clone`** — *One-shot onboarding*: pull a remote repo locally and write `.bb-spec.yaml`.
  - **Two AskUserQuestion prompts**: ① single-repo vs multi-repo workspace (decides directory layout) ② `base_dir` (decides where every later bb-spec artifact lands)
  - **Multi-repo workspace**: creates a shared parent dir and clones each member repo into it (restoring the relative layout the build tool expects); refuses to nest or overwrite
  - Tightly scoped: **only** pulls code + writes `base_dir` — does not read code, install deps, or trigger `/init-spec`

- **`/init-spec`** — *Reverse*-spec an existing project.
  - Reads code + docs and distills **already-enforced implicit conventions** into ≤100-line, one-rule-per-file specs, landing in the same structure `/spec` uses
  - Large projects fan out across partitioned subagents; runs once on first adoption

- **`/spec`** — Requirement breakdown through dialogue. Answers **"what to build."**
  - One rule per file, ≤100 lines, one thing + one example, non-overlapping
  - Lightweight `INDEX.md` up front — readers scan the index before loading specifics

- **`/plan`** — spec → self-contained, **function-level** plan. Answers **"how to build it."**
  - One independent problem per file, down to function names and responsibilities; declarative artifacts (DDL / API contracts / config) are **inlined in final form** for exec to write verbatim
  - Invocation enters **plan mode for read-only alignment** — nothing lands until you approve; **new third-party dependencies are listed as a dedicated section**, and approval counts as the explicit user consent version-policy requires
  - Auto-scales: single-domain small scopes go single-topic; multi-domain / bootstrap / large spec drops switch to a **batched ROADMAP** with dependency arrows + verification gates, expanding only the current batch

- **`/exec`** — **Three-agent isolated execution**, the core anti-cheat design.
  - *Test* agent reads spec rules only, writes failing tests (Red)
  - *Impl* agent **never sees the spec**, only the tests + function list, so it can't quietly "teach to intent"; new third-party libs capped by the plan's approved list
  - *Review* agent checks against the spec, read-only
  - Progress written to `PROGRESS.md` after every step — **token-exhausted runs resume losslessly**

- **`/test-webview`** — **Web-interaction acceptance** for frontend / web projects.
  - Brings the app up via the project's Docker stack (confirmed once, then remembered; `down -v` cleans up afterward), drives a real browser via the browser MCP
  - **Each case runs in an isolated serial subagent** — hundreds of cases never blow the main context; fully serial (shared single browser)
  - Cases auto-generated from spec / plan / PRD; **coverage alignment** before a full run, gaps never silently dropped; failures route to `/revise`
  - Requires a browser MCP (playwright / chrome-devtools)

- **`/test-api`** — **API e2e** for any backend.
  - `compose.e2e.yaml` brings the stack up; md cases **mechanically render to a single-file Bun TS runner** that runs in one shot via `bun run`
  - **Zero subagents, zero concurrency** — HTTP is deterministic, clock state is shared
  - **Time-sensitive rules** (token expiry, order timeout, points expiry) tested through `/test/advance-time`, `/test/backdate`, `/test/trigger-job`
  - App side ships **two images**: test image carries `/test/*` routes + `ENV TESTAPI=1`; production image **physically excludes** `/test/*` source; `/test/healthz` probe gates the run, no fallback

- **`/review`** — Workflow-orchestrated, **adversarially verified** local PR review.
  - Phase 1 fans out **5 finders in parallel**: code quality / security / simplicity / doc-sync / **Codex cross-model independent** review, schema-enforced
  - Phase 2 every 🔴/🟡 re-judged by **3 independent skeptic lenses** (importance / root-cause / risk-if-unfixed), majority vote
  - Read-only — never auto-edits; requires Claude Code ≥ 2.1.154

- **`/revise`** — The exception handler, callable anytime.
  - Classifies a deviation's **root cause** into one of three: *spec-defect* (→ `/spec`), *impl-drift* (→ `/exec`), *requirement-change*
  - Every review finding that needs fixing funnels through here

- **`/git-push`** — User-triggered push + PR flow (single or multi-repo).
  - When a spec `INDEX.md` exists, first runs a **branch-spec self-check (pre-review)**: a subagent diffs the branch vs main against the spec, fixes violations in a loop
  - Drafts a **6-section PR description** (background / requirement / approach / result / tests / spec, < 50 lines) used directly as the PR body

- **`/doc-update`** — Whole-repo spec / doc / code **consistency sweep**.
  - Six drift classes: spec-stale / doc-stale / code-violation / spec-conflict / orphan-index / uncovered-rule
  - **Code is the truth; spec / docs are mirrored to it**; only obvious hard-constraint violations stop and ask, then route to `/revise` for TDD
  - Clear boundaries against `/init-spec` (zero → existence), `/revise` (single point), and the `/review` `review-doc-sync` finder (PR-diff scope)

**Ships with**

- **11 orchestration subagents** driven by the stages above: `test-engineer` / `impl-engineer` / `spec-reviewer` / `webview-test-runner` / `review-code-quality` / `review-security` / `review-simplicity` / `review-doc-sync` / `review-codex` / `pre-reviewer` / `rule-extractor`
- **4 passive hooks** (automatic): block npm/yarn, block main commit, dependency version self-check, Stop four-point self-check

---

## Companion constraint skills

These feed rules into the pipeline above — install only the layers you need.

### bb-spec-product — product requirements (pipeline upstream)

- **`prd`** — PM / requester brainstorms with AI: challenge first (rejection is a valid outcome) → diverge → converge, producing a self-contained PRD — goals / non-goals, prioritized user stories (every P0 carries concrete use cases and acceptance criteria), and open questions left for engineers; needs no git repo or code context, consumed directly by `/spec`

> **PMs don't need Claude Code**: every release auto-packages [`bb-spec-prd-skill.zip`](https://github.com/0xBB2B/bb-spec/releases/latest/download/bb-spec-prd-skill.zip) — download it and upload via **Settings → Customize → Skills** on claude.ai web / desktop to use the skill standalone (paid plan with code execution required); the resulting PRD is delivered to engineers as a downloadable file.

### bb-spec-core — universal discipline

- **`tdd-workflow`** — Red-Green-Refactor discipline with standard flows for the add / modify / delete scenarios
- **`version-policy`** — Standard/official libraries first — importing a new third-party library requires explicit user consent (a plan-approved dependency list counts); check a dependency's official latest version before pinning it; never trust training memory
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
- **`config-constraints`** — Config carrier tiers: env/secret for startup-critical non-hot-reload, yaml/configmap for hot-reloadable defaults, DB for dynamic business config; core credentials in secret/KMS only, envelope encryption when pushed down to DB

### bb-spec-frontend — frontend stack constraints

- **`vue-constraints`** — Vue 3 + TypeScript + Vite + Tailwind + bun hard stack constraints
- **`frontend-constraints`** — Conventions: one unified request client, centralized error-code → UI mapping, UX-only route guards, types from the contract

---

## Install

BB-Spec ships as **five independently installable sub-plugins** — install only the constraint layers you need.

First add the marketplace once, inside Claude Code:

```bash
/plugin marketplace add 0xBB2B/bb-spec
```

Then install whichever layers you want:

| Sub-plugin | What it gives you | Command |
|---|---|---|
| **bb-spec-core** _(recommended base)_ | TDD / version-policy / git-workflow discipline + 3 passive hooks | `/plugin install bb-spec-core@0xbb2b` |
| **bb-spec-workflow** _(core)_ | spec → plan → exec → test-webview / test-api → review → revise → git-push, git-clone one-shot init, init reverse-spec, doc-update whole-repo consistency sweep + 11 subagents | `/plugin install bb-spec-workflow@0xbb2b` |
| **bb-spec-product** | /prd requirement brainstorm → PRD doc with concrete use cases (for PMs / requesters) | `/plugin install bb-spec-product@0xbb2b` |
| **bb-spec-backend** | Go / REST API / DB / authN / authZ / observability / service / config constraints | `/plugin install bb-spec-backend@0xbb2b` |
| **bb-spec-frontend** | Vue 3 + TS + Vite + Tailwind + bun stack & engineering conventions (+ bun hook) | `/plugin install bb-spec-frontend@0xbb2b` |

Pick by need — e.g. just the disciplines and workflow without any stack opinions: install `bb-spec-core` + `bb-spec-workflow`. On a PM's / requester's machine: just `bb-spec-product`. Want everything: install all five.

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
    "bb-spec-product@0xbb2b": false,
    "bb-spec-backend@0xbb2b": false,
    "bb-spec-frontend@0xbb2b": false
  }
}
```

## Versioning

```bash
/plugin update                  # check and update every installed plugin
/plugin update bb-spec-core     # update only one sub-plugin
```

The five sub-plugins share a single synchronized version line.

---

## Hooks enabled by default (out of the box)

Each hook ships with the sub-plugin that owns its concern — install that plugin to get it.

| Hook | Sub-plugin | Trigger | Effect |
|---|---|---|---|
| `block-non-bun-pm` | bb-spec-frontend | PreToolUse(Bash) | Blocks `npm` / `yarn` / `pnpm` package-manager actions, enforcing `bun`; existing projects with a matching lockfile (e.g. `package-lock.json`) are allowed through |
| `git-workflow-guard` | bb-spec-core | PreToolUse(Bash) | Blocks `git commit` on `main` / `master`; for other git flow actions (branch / push / worktree / merge / PR) allows them through and injects the git-workflow discipline plus live git status |
| `dep-version-check` | bb-spec-core | PostToolUse(Write\|Edit) | After editing a dependency file, injects a "check the official latest version first" reminder |
| `stop-self-check` | bb-spec-core | Stop | Forces a four-point self-check before a task ends: temp files / change scope / orphaned leftovers / legacy cruft |

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

`/prd`, `/spec` and `/plan` output under `.bb-spec/docs/` by default (`.bb-spec/docs/prd/`, `…/spec/`, `…/plan/`); runtime transient artifacts (e.g. webview screenshots) go to the sibling `.bb-spec/.cache/` (auto-gitignored). Create a `.bb-spec.yaml` in the project root to override the bb-spec root directory:

```yaml
base_dir: my/bb  # → my/bb/docs/{prd,spec,plan,test}/ and my/bb/.cache/ ; use ./ to place them at the project root
```

Reference template: [`.bb-spec.template.yaml`](./.bb-spec.template.yaml).

---

## Hook switch cheat sheet

| Scenario | Switch |
|---|---|
| Temporarily allow npm / yarn / pnpm | Disable `bb-spec-frontend` temporarily |
| Temporarily allow main commit | Disable `bb-spec-core` temporarily |
| Skip the Stop self-check | No switch — this is a core iron rule, skipping is discouraged |

---

## Prior art & acknowledgements

BB-Spec stands on three excellent projects. Each shaped a different part of its design — credited below, alongside what BB-Spec borrowed and how it pushed the idea further.

| Project | What it does best | What BB-Spec borrowed & hardened |
|---|---|---|
| [**Superpowers**](https://github.com/obra/Superpowers) (obra) — a complete coding-agent methodology | End-to-end staged workflow, subagent-driven development with phased review, TDD Red-Green-Refactor, git-worktree isolation, Socratic brainstorming, a composable skill library | The whole `spec → ship` pipeline backbone, splitting work across role-specialized subagents, mandatory TDD, multi-stage / adversarial review, and dialogue-first requirement clarification |
| [**ECC**](https://github.com/affaan-m/ECC) (affaan-m) — an agent-harness "operating system" | A large layered system of agents / skills / hooks / rules, passive hooks that auto-enforce, rules-as-infrastructure, memory persistence across sessions | The layered, independently-installable sub-plugin suite, passive hooks that enforce discipline, and distilling engineering conventions into loadable constraint skills |
| [**skills**](https://github.com/mattpocock/skills) (mattpocock) — "Skills For Real Engineers" | Targets real failure modes (misalignment / verbosity / quality / architecture), deep questioning to align on intent, shared domain language, user- vs model-invoked skills, vertical slicing | Challenge-first dialogue to pin down requirements before any code, dual-trigger skills (slash command + model auto-trigger), and the one-rule-per-file minimalism |

**Where BB-Spec goes its own way** — differentiators none of the three combine:

- **Three-agent isolated execution** — the Impl agent *physically never sees the spec*, only the tests, so it cannot quietly "teach to intent"; tests, implementation, and review are written by mutually-blind agents.
- **Disk documents as the only handoff** — every stage hands off a file, not chat memory, so a run resumes losslessly across sessions, `/clear`, or even a different model picking up the work.
- **Bidirectional spec ⇄ code loop** — not just spec → code, but `/init-spec` to distill specs out of an existing codebase and `/doc-update` to keep them in sync as the code drifts.

---

## License

MIT
