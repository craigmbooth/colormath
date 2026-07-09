# Changelog

All notable changes to colormath. Versioning per [LIFECYCLE.md](LIFECYCLE.md):
one SemVer stream, exact-tag pins, MAJOR = anything that can turn a consumer's
green CI red without the consumer editing anything. While on `0.x`, breaking
changes may land in any release.

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
