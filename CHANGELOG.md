# Changelog

All notable changes to colormath. Versioning per [LIFECYCLE.md](LIFECYCLE.md):
one SemVer stream, exact-tag pins, MAJOR = anything that can turn a consumer's
green CI red without the consumer editing anything. While on `0.x`, breaking
changes may land in any release.

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
