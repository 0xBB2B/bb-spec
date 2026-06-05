# BB-Spec

**English** | [中文](./README.zh.md)

> A language-agnostic Claude Code workflow constraint suite: **hard Go + Vue + bun stack constraints**, **TDD / anti-legacy-cruft iron rules**, and a **multi-agent local review kit**.

> Output follows your working language. The skills do **not** hardcode an output language — docs, comments, and commit messages come out in whatever language you work in (identifiers, API names, and error codes stay English). Every skill triggers on both English and Chinese phrases.

---

## Install

Run inside Claude Code:

```bash
/plugin marketplace add 0xBB2B/bb-spec
/plugin install bb-spec@0xbb2b
```

Or add it manually to `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "0xbb2b": {
      "source": { "source": "github", "repo": "0xBB2B/bb-spec" }
    }
  },
  "enabledPlugins": {
    "bb-spec@0xbb2b": true
  }
}
```

## Versioning

Update an installed plugin:

```bash
/plugin update              # check and update every installed plugin
/plugin update bb-spec   # update only this plugin
```

---

## Hooks enabled by default (out of the box)

| Hook | Trigger | Effect |
|---|---|---|
| `block-non-bun-pm` | PreToolUse(Bash) | Blocks `npm` / `yarn` / `pnpm` package-manager actions, enforcing `bun`; existing projects with a matching lockfile (e.g. `package-lock.json`) are allowed through |
| `block-main-commit` | PreToolUse(Bash) | Blocks `git commit` on the `main` / `master` branch |
| `dep-version-check` | PostToolUse(Write\|Edit) | After editing a dependency file, injects a "check the official latest version first" reminder |
| `stop-self-check` | Stop | Forces a four-point self-check before a task ends: temp files / change scope / orphaned leftovers / legacy cruft |

---

## Advanced: optional Hooks (off by default, opt-in)

The repo ships two **higher-impact** Stop hooks. They are registered with the plugin but gated at the top of each script, so they **do not run by default** — you must enable them explicitly:

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
/review  5-agent parallel PR-level review
  │  quality / security / anti-cruft / over-engineering / Codex
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

## Skills overview (14)

### Universal discipline

- **`tdd-workflow`** — Universal TDD discipline: Red-Green-Refactor, standard flows for the add/modify/delete scenarios
- **`version-policy`** — Before adding/upgrading a dependency you must check the official latest version; no relying on training memory
- **`git-workflow`** — Branch decisions, incremental commits, the PR three-section description, post-merge cleanup
- **`git-push-pr`** — User-triggered multi-repo batch / selective push-and-PR flow
- **`init`** — Reverse-spec an existing project: read existing code and docs to infer rules, extract in parallel by partition, landing fully aligned with `/spec` (first adoption only)
- **`spec`** — Requirement breakdown and documentation: one rule per file, ≤100 lines, output to `.bb-spec/docs/spec/`
- **`plan`** — Read specs and produce a step-by-step implementation plan: one unit per file, function-level detail, output to `.bb-spec/docs/plan/`
- **`exec`** — Three-agent isolated plan execution (Test→Impl→Review), PROGRESS.md checkpoint recovery
- **`revise`** — Output revision (bug fix / optimization / requirement change): three root-cause classes (spec-defect / impl-defect / requirement-change) → targeted fix → regression
- **`api-design`** — REST API design: resource naming, status codes, pagination, error responses, versioning

### Go backend

- **`golang-constraints`** — Whole-lifecycle Go constraints: three-layer architecture, no over-abstraction, tests subordinate to production design
- **`golang-testing`** — Go test organization: table-driven, subtests, benchmark, fuzz

### Frontend

- **`vue-constraints`** — Vue 3 + TypeScript + Vite + Tailwind + bun hard constraints

### Local review

- **`review`** — Current branch vs base: 5 agents in parallel (quality / security / anti-cruft / over-engineering / Codex cross-model)

---

## Tests

```bash
bash tests/validate.sh
```

Validates 105 structural rules: agent frontmatter integrity (required fields, name consistency, valid agent-type values, security-baseline section), skill SKILL.md format, hooks.json validity and script existence, plugin.json fields, and personal-path leak detection.

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
| Temporarily allow npm / yarn / pnpm | Not provided yet; disable the plugin temporarily |
| Temporarily allow main commit | Same as above |
| Skip the Stop self-check | No switch — this is a core iron rule, skipping is discouraged |
| Enable stop-auto-tests | `CLAUDE_ENABLE_AUTO_TESTS=1` or `.enable-auto-tests` in the project root |
| Enable stop-auto-commit | `CLAUDE_ENABLE_AUTO_COMMIT=1` or `.enable-auto-commit` in the repo root |

---

## License

MIT
