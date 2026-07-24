# Changelog

All notable changes to colormath. Versioning per [LIFECYCLE.md](LIFECYCLE.md):
one SemVer stream, exact-tag pins, MAJOR = anything that can turn a consumer's
green CI red without the consumer editing anything. While on `0.x`, breaking
changes may land in any release.

## v2.1.0 — 2026-07-23

**MINOR — `/colormath:ship` gains test-plan execution and can now auto-merge;
no consumer CI changes.** Nothing a consumer runs turns red without them
editing anything (the `test-plan` job already ships in the review workflow
since v2.0.0). But note the **behavior change**: where `ship` previously stopped
at a merge *recommendation* and never merged, it now fixes findings itself
(blockers included) and, when the PR is genuinely clean, **merges it**. Repos
without the review workflow are unaffected — the skill detects its absence,
skips QA, and its final review holds rather than merging a PR it couldn't
verify.

### Changed

- **`/colormath:ship` now executes the PR's test plan** (`plugin/skills/ship/`).
  A new step 4 waits for the `review / test-plan` check, reads the `## Test
  Plan` comment and its machine-readable verdict (`qa_depth` / `requires_ui_qa`
  / `requires_api_qa`), runs the UI/API QA checklists against the **running**
  stack — reusing the `qa` skill's recon + verify discipline, scaling effort by
  `qa_depth`, driving a browser for UI items when one is reachable and marking
  them `⚠️` unverified when not — then posts a `## Test Plan · Results` comment
  checking off each item with the evidence it observed. A new step 6 restores
  any local state the run mutated. The skill's `allowed-tools` widen to broad
  `Bash` + `Write` + `Skill` + `AskUserQuestion` (step 4 drives the local stack,
  which no narrow `gh`/`git` allowlist covers); `model` is unchanged.

- **`/colormath:ship` now fixes findings automatically and gates the merge, not
  the fix.** The old SMALL/LARGE triage is gone. Step 5 fixes every review and
  `❌` QA finding it can — **Blockers included, without asking** — in iterative
  rounds (re-verify each repro against the running system; re-trigger the review
  with `@claude` once when fixes are substantive), deferring only findings that
  genuinely need a human (a design decision, or a `CHANGES_REQUESTED` structural
  call). A new **step 7 "final review"** then decides: if no blockers stand
  *and* QA was performed and passed, it posts a comment and **auto-merges**
  (`gh pr merge`, honoring the repo's merge convention); if either is false —
  a standing blocker, a finding deferred to a human, or QA that failed or
  couldn't run (e.g. a required UI item with no browser) — it posts *why* it
  held off and stops, leaving the merge to a human. The former hard rule "never
  merge" is replaced by this gated auto-merge; "never push to the default
  branch" still holds (a `gh pr merge` is not a push to `main`).

  Contract surfaces it depends on — a rename of any must ship with a matching
  skill update: the review workflow's `review / test-plan` check name, the
  `## Test Plan` comment marker with its `<!-- colormath-test-plan -->` /
  `<!-- testplan … -->` hidden markers and the `qa_depth` / `requires_ui_qa` /
  `requires_api_qa` verdict fields, the sibling `qa` skill's `references/`
  (recon + probe catalogs), and — as before — the `gates / *` check names, the
  `review / review` check, and the `## Thermonuclear Review` marker.

- Plugin bumped to `2.1.0`; marketplace blurb notes `/colormath:ship` now
  executes the generated test plan and auto-merges when clean.

## v2.0.0 — 2026-07-23

**MAJOR — two formerly opt-in gates flip default-on.** `migrations` (shipped
opt-in in v1.1.0) and `import-linter` (added and promoted in this same
release) now default `enable-*: true`. A consumer that never set these flags
gets both gates on its next bump: `migrations` just works wherever
`migrations-path` (`alembic/versions`) exists; `import-linter` fails until the
repo has `[tool.importlinter]` contracts, so disable it and burn down on your
schedule. This is the promotion the v1.1.0 changelog and the new-gate rollout
rule pointed at.

### Added

- **`import-linter` gate** (import-linter): enforces the project's import
  architecture — layered dependency order, forbidden edges, module
  independence — via `lint-imports`. Pure static analysis (grimp builds the
  import graph without executing code), so no project deps are installed,
  mirroring `docstrings`/`templates`. The contracts are entirely
  project-specific and come from `[tool.importlinter]` in the consumer's
  pyproject (or a `.importlinter` file), which `lint-imports` auto-discovers.
  New inputs: `import-linter-spec` (`"import-linter>=2,<3"`) and
  `enable-import-linter` (**default `true`**). Flat-layout note: `root_packages`
  takes packages (dirs with `__init__.py`), so to forbid a top-level single-file
  module (e.g. a `shared.py`) set `include_external_packages = True` and name it
  in `forbidden_modules`.
- `Makefile.colormath`: `import-linter` target with a
  `COLORMATH_IMPORT_LINTER_SPEC` knob, now part of `preflight`.
- `example/`: an `example_pkg` (service + web layers) with a `[tool.importlinter]`
  `forbidden` contract (service must not import web) and a covering test;
  colormath's self-test runs the gate default-on.
- **`/colormath:qa` plugin skill** (`plugin/skills/qa/`): QAs a focus area
  against the running stack, then hands the fixes to `/colormath:ship`.
  Recon (bring the stack up without disturbing existing state; collect
  credentials at several privilege tiers) → probe → verify → ranked findings
  the user selects from → fix → restore → ship. Three probe catalogs live in
  `references/`: `security.md` (authorization matrix, confused-deputy,
  stored content served back, input validation, disclosure), `correctness.md`
  (cross-surface consistency, write round-trips, boundaries, contract drift),
  `accessibility.md` (keyboard, semantics, dynamic state, contrast).

  Contract surfaces it depends on — a rename of any must ship with a matching
  skill update: the `ship` skill (step 7 handoff), `make preflight` and the
  `gates / *` check names (step 4, telling a real finding from local
  tool-version drift), and the `a11y` gate as the documented floor that the
  accessibility catalog deliberately goes beyond. It also assumes the
  consumer documents run commands and ports in `AGENTS.md` / `CLAUDE.md`.

### Changed

- **`enable-migrations` and `enable-import-linter` now default `true`.** These
  were the last two opt-in gates; every gate is now default-on. Disable any
  that are red for your repo (`enable-<gate>: false`) and burn down on your
  own schedule.
- `Makefile.colormath`: `migrations` and `import-linter` join `preflight`, so
  the local mirror matches the default-on CI suite. Keep
  `COLORMATH_PREFLIGHT_SKIP` in lockstep with your caller's `enable-*: false`.
- **Plugin metadata aligned to the release.** `plugin/.claude-plugin/plugin.json`
  bumps `1.0.0` → `2.0.0` (it was last set at the v1.0.0 release and missed the
  `qa`-skill bump), and the marketplace blurb now names `/colormath:qa`. The
  plugin marketplace tracks the default branch, so this ships to installs on the
  next auto-update — no consumer action.

### Upgrade notes

Paste into Claude Code in each consumer repo:

> Bump colormath to v2.0.0: update the `gates.yml` `uses:` pin (and
> `review.yml`/`review.yaml` if present) to `@v2.0.0` and run
> `make colormath-update REF=v2.0.0` (refreshes Makefile.colormath AND
> eslint.config.colormath.mjs). Two gates flip default-on at v2.0.0:
> `migrations` and `import-linter`. If this repo uses alembic (has
> `alembic/versions`), leave `migrations` on — it needs no config; otherwise
> add `enable-migrations: false`. Unless this repo already has a
> `[tool.importlinter]` contract, add `enable-import-linter: false` and file
> yourself an issue to write import contracts later. Mirror every newly
> disabled gate in `COLORMATH_PREFLIGHT_SKIP` in the root Makefile (before the
> include) so `make preflight` matches CI. Verify locally: `make preflight`
> (or the individual `make migrations` / `make import-linter` targets),
> `poetry check --lock`, then open the bump PR.

## v1.1.0 — 2026-07-10

MINOR: new gate, shipped **opt-in** per the new-gate rollout rule — existing
consumers see a skipped `migrations` job until they set
`enable-migrations: true`; promotion to default-on comes with the next MAJOR.

### Added

- **`migrations` gate** (`scripts/migrations-sync.sh`, pure git — no project
  deps): fails when the base branch has alembic migration changes the PR
  branch predates, before they merge into multiple alembic heads. Diffs the
  base branch against its merge-base with the PR head (checked out at the
  real head SHA — the ephemeral merge commit would hide divergence), scoped
  to the migrations directory, and tells the author to
  `git pull --rebase origin <branch>`. The base branch is the
  `default-branch` input when set, else the repo's default branch (main and
  master both work); local runs discover it from `origin/HEAD`. New inputs:
  `migrations-path` (`"alembic/versions"`) and `enable-migrations`
  (**default `false`**).
- `Makefile.colormath`: `migrations` target (fetch-then-run of the shared
  script) with a `COLORMATH_MIGRATIONS_PATH` knob. Not in `preflight` while
  the CI gate is opt-in.
- `example/`: reference `alembic/versions/` directory (excluded from
  interrogate + coverage, mirroring real consumers); the self-test runs with
  `enable-migrations: true`.

## v1.0.0 — 2026-07-10

**MAJOR — pins are now contractual.** Two breaking changes: every gate now
defaults **on** (the five formerly-opt-in gates — `docstrings`, `jslint`,
`templates`, `js-deps`, `dockerfile` — flip to `enable-*: true`), and the
`jslint` contract now expects the vendored shared eslint base.

### Added

- **`eslint.config.colormath.mjs`**: the shared eslint base, vendored by
  consumers alongside `Makefile.colormath` (both refreshed by
  `make colormath-update`). Exposes a `colormathConfig()` factory —
  `files`, `testFiles`, `cdnGlobals`, `rules` — with appended flat-config
  blocks as the escape hatch (later entries win) and ejecting as sanctioned
  divergence. Consumer `eslint.config.js` becomes a thin caller; devDeps
  contract: `eslint`, `@eslint/js`, `globals`.
- `Makefile.colormath`: `COLORMATH_PREFLIGHT_SKIP` knob — `preflight` now
  runs the full fourteen-gate mirror minus the listed targets; keep it in
  lockstep with your caller's `enable-*: false` flags.

### Changed

- All `enable-<gate>` inputs default `true`. A consumer that never set the
  opt-in flags gets five new gates on its next bump — disable any that are
  red and burn down on your schedule.
- `colormath-update` refreshes both vendored files.

### Upgrade notes

Paste into Claude Code in each consumer repo:

> Bump colormath to v1.0.0: update the `gates.yml` `uses:` pin (and
> `review.yaml` if present) to `@v1.0.0` and run
> `make colormath-update REF=v1.0.0` (now refreshes Makefile.colormath AND
> eslint.config.colormath.mjs). All gates default on at v1.0.0: delete any
> now-redundant `enable-*: true` lines, and add an explicit
> `enable-<gate>: false` for every gate this repo isn't ready for (check the
> caller's comments for the current burn-down list — at minimum `templates`
> everywhere, plus `styles`/`a11y` in runwayz). Set
> `COLORMATH_PREFLIGHT_SKIP` in the root Makefile (before the include) to
> the same list so `make preflight` mirrors CI. Rewrite `eslint.config.js`
> as a thin caller of the vendored base per its header — move this repo's
> CDN globals into `cdnGlobals`, file globs into `files`, and keep any
> special-file blocks (e.g. worklet globals) as appended entries; ensure
> devDeps `eslint`, `@eslint/js`, `globals`. Verify locally:
> `npm run jslint`, `poetry check --lock`, `make audit`, then open the bump
> PR.

## v0.6.0 — 2026-07-10

MINOR: four new gates, all shipped **opt-in** per the new-gate rollout rule —
existing consumers see skipped jobs until they set the `enable-*` inputs;
promotion to default-on comes with the next MAJOR. One caveat below on the
`tests` gate (allowed while on `0.x`).

### Added

- **`jslint` gate** (eslint): lints hand-written JS via a consumer-defined
  `jslint` npm script — closes the asymmetry where Python gets ruff and CSS
  gets stylelint but JS only gets tests. New input: `enable-jslint`
  (**default `false`**). Consumer contract: npm script `jslint` +
  `eslint.config.js` (reference in `example/`).
- **`templates` gate** (djlint): lints the Jinja templates themselves —
  unbalanced tags, malformed syntax — complementing `a11y`, which validates
  the HTML but not the Jinja. Pure scan, no project deps; profile and rule
  ignores come from `[tool.djlint]` in the consumer's pyproject. New inputs:
  `djlint-spec` (`"djlint>=1.36,<2"`), `djlint-paths` (`"templates/"`), and
  `enable-templates` (**default `false`**).
- **`js-deps` gate** (npm audit): the JS half of "audit what ships" — audits
  `package-lock.json` with `--omit=dev`, so dev tooling never fails the gate.
  Skips quietly when the workdir has no lockfile. New inputs:
  `npm-audit-level` (`"high"`) and `enable-js-deps` (**default `false`**).
- **`dockerfile` gate** (hadolint): static Dockerfile lint, pinned binary
  (same install pattern as gitleaks). New inputs: `hadolint-version`
  (`"2.14.0"`), `hadolint-dockerfiles` (`"Dockerfile"`), and
  `enable-dockerfile` (**default `false`**).
- `Makefile.colormath`: mirror targets `jslint`, `templates`, `js-audit`,
  `dockerfile` (out of `preflight` while their gates are opt-in) and
  `lock-check` (in `preflight`), with `COLORMATH_DJLINT_SPEC` /
  `COLORMATH_DJLINT_PATHS` / `COLORMATH_NPM_AUDIT_LEVEL` /
  `COLORMATH_HADOLINT_DOCKERFILES` knobs.
- `example/`: `eslint.config.js` + `jslint` npm script, `[tool.djlint]`
  (jinja profile, H030/H031 ignored), and a hadolint-clean `Dockerfile`;
  colormath's self-test enables all four new gates.

### Changed

- **`tests` gate now runs `poetry check --lock` first**, so pyproject/lock
  drift fails up front with a legible message instead of deep inside a
  `poetry install`. Strictly this can turn a drifted consumer red without a
  consumer edit (MAJOR territory) — landed on `0.x` where breaking changes
  are allowed; the fix is `poetry lock` in the consumer repo.

## v0.5.0 — 2026-07-09

MINOR: new gate, shipped **opt-in** per the new-gate rollout rule — existing
consumers see a skipped `docstrings` job until they set
`enable-docstrings: true`; promotion to default-on comes with the next MAJOR.

### Added

- **`docstrings` gate** (interrogate): docstring-coverage check, promoted
  from runwayz's project-specific sibling job. Pure AST scan, no project
  deps; threshold and scope come from `[tool.interrogate]` in the consumer's
  pyproject. New inputs: `interrogate-spec` (`"interrogate>=1.7,<2"`),
  `interrogate-paths` (`"."`, scoped by the pyproject excludes), and
  `enable-docstrings` (**default `false`**).
- `Makefile.colormath`: `docstrings` target with
  `COLORMATH_INTERROGATE_SPEC` / `COLORMATH_INTERROGATE_PATHS` knobs. Not in
  `preflight` while the CI gate is opt-in.
- `example/`: `[tool.interrogate]` (fail-under 100) and full docstring
  coverage; colormath's self-test runs with `enable-docstrings: true`.

## v0.4.0 — 2026-07-09

MINOR: new opt-in artifact — the plugin channel (channel D) opens.

### Added

- **Claude Code plugin marketplace** (`.claude-plugin/marketplace.json`) and
  the **`colormath` plugin** (`plugin/`), extracted from intendent's local
  `.claude/skills/`. First skill: **`/colormath:ship`** — take the current
  branch through the PR pipeline (open PR, watch the `gates / *` checks,
  wait for the Thermonuclear Review / formal reviews, triage SMALL vs LARGE,
  apply small fixes with an Addressed/Not-changed response comment) and stop
  at a merge recommendation, never merging. Generalized from the intendent
  version: default-branch-agnostic, detects whether the repo runs the
  colormath review workflow (skips the review wait when absent), and drops
  `--required` from the gate watch (repos without branch protection get
  "no required checks" + exit 1 from gh).
  - Install: `/plugin marketplace add ColorMath/ci` then
    `/plugin install colormath@colormath`, or per-repo via
    `extraKnownMarketplaces`/`enabledPlugins` in `.claude/settings.json`
    (example in the README).

## v0.3.0 — 2026-07-09

MINOR: new opt-in artifact; existing consumers are unaffected until they add
a caller for it.

### Added

- **Reusable AI review suite** (`.github/workflows/review.yml`,
  `workflow_call`), extracted from intendent's `claude-review` workflow. Two
  parallel agents on every non-draft PR (re-runnable via `@claude` comment):
  the adversarial "Thermonuclear Review" (tracking comment led by the
  `## Thermonuclear Review` marker + inline comments) and the QA test-plan
  agent (`## Test Plan` comment; machine-readable
  `qa_depth`/`requires_ui_qa`/`requires_api_qa` exposed as workflow outputs,
  with placeholder `api-qa`/`ui-qa` jobs gating on them).
  - Inputs: `model`, `review-focus` (project-specific reviewer emphasis —
    replaces intendent's hardcoded Google Drive note), `enable-review`,
    `enable-test-plan`. Secret: `anthropic_api_key` (required).
  - The hidden test-plan marker is now `<!-- colormath-test-plan -->`
    (was `<!-- intendent-test-plan -->`); the human-visible markers are
    unchanged, so automation keyed on `## Thermonuclear Review` /
    `## Test Plan` keeps working.

## v0.2.1 — 2026-07-09

PATCH: `Makefile.colormath` robustness fixes, from intendent's adoption
review. Refresh vendored copies with `make colormath-update REF=v0.2.1`.

### Fixed

- `sast` target: `pip install`/`bandit` now run via `poetry run`, so bandit
  lands in the project venv instead of whatever pip is on PATH.
- `secrets` target: restored the actionable "gitleaks not installed" guard.
- `audit`/`coverage-diff` targets: fetch-then-run with `curl --retry 3` and a
  distinct error message when the script fetch fails, so a network failure is
  no longer indistinguishable from a gate failure.

## v0.2.0 — 2026-07-09

MINOR: new opt-in artifact; existing consumers are unaffected until they
vendor it.

### Added

- **`Makefile.colormath`**: shared local mirrors of every gate, so all
  consumers expose the same `make` endpoints (`format-check`, `lint`,
  `typecheck`, `styles`, `sast`, `secrets`, `a11y`, `audit`,
  `coverage-diff`, `preflight`). Consumers vendor it at a pinned tag and
  `include` it from their Makefile, providing a `test` target and optional
  `COLORMATH_*` overrides (`BANDIT_SPEC`, `RUFF_CHECK_ARGS`,
  `DIFF_COVER_BASE`, `DIFF_COVER_FAIL_UNDER`). `make colormath-update
  REF=vX.Y.Z` refreshes the vendored copy; the file's `COLORMATH_REF` is
  stamped per release like the workflow's `colormath-ref`.

## v0.1.1 — 2026-07-09

PATCH: keeps green things green.

### Changed

- Repo transferred from `craigmbooth/colormath` to `ColorMath/ci`. All
  internal checkout refs, docs, and the stamped `colormath-ref` now use the
  new path. GitHub redirects the old path, so `v0.1.0` pins keep working —
  but pin `ColorMath/ci/...@v0.1.1` going forward.

## v0.1.0 — 2026-07-08

Initial release: the CI gates channel.

### Added

- **Reusable gate suite** (`.github/workflows/gates.yml`, `workflow_call`):
  nine parallel gates — ruff, tests (JS + Python), typecheck (mypy), styles
  (stylelint), sast (bandit), secrets (gitleaks), a11y (html-validate), deps
  (pip-audit), diff-coverage (diff-cover). Reconciled from the
  intendent/talas lineage (newest action pins, talas's full ruff lint +
  pipx-pinned Poetry, intendent's job summaries).
  - Inputs: `python-version`, `node-version`, `default-branch` (falls back to
    the repo default), `workdir`, `poetry-install-args`, `ruff-spec`,
    `ruff-select`, `bandit-spec`, `gitleaks-version`,
    `diff-cover-fail-under`, `free-disk-space`, and per-gate `enable-*`
    booleans for incremental adoption.
  - Consumer contract: `.colormath/audit.conf`, optional `.colormath/ci.env`
    and `.colormath/ci-extra-install.sh`, optional `.gitleaks.toml`,
    `[tool.bandit]` in pyproject, npm scripts `test`/`styles`/`a11y`.
- **Composite actions**: `setup-python-poetry` (pipx-pinned Poetry, cached
  in-project venv), `setup-node` (npm cache, skips gracefully without
  package.json), `gate-summary` (the per-gate `$GITHUB_STEP_SUMMARY` block).
- **Gate scripts**: `scripts/diff-coverage.sh` (base branch + threshold via
  env) and `scripts/audit-deps.sh` (poetry groups + CVE allowlist from the
  consumer's `.colormath/audit.conf`). Fetched by the workflow at its own
  matching ref — consumers never copy them.
- **example/**: minimal compliant consumer; colormath's own CI runs the full
  suite against it on every PR.
- Docs: README (adoption guide per product), LIFECYCLE (versioning, release
  checklist, propagation).
