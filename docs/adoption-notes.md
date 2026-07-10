# Adoption notes for the portfolio products

Working notes for migrating the maintainer's own products onto the gates
channel. Adoption order is always talas (canary) → intendent → runwayz
(see [LIFECYCLE.md](../LIFECYCLE.md)).

## talas — done (talas-app/talas#63, @v0.5.0 as of #67; plugin enabled via .claude/settings.json, no review workflow yet)

`default-branch: main`, `poetry-install-args: "--with webapp,worker"`,
`ruff-spec` matching pyproject's `^0.14.8` pin. `scripts/diff-coverage.sh` and
`scripts/audit-deps.sh` deleted; their poetry groups + CVE allowlist moved to
`.colormath/audit.conf`, the inline pytest env to `.colormath/ci.env`, and the
fake-`VERTEX_PROJECT_ID`-into-`.env` hack to `.colormath/ci-extra-install.sh`
(it must stay a `.env`-file write, not an env var — the config unit tests
construct `Settings` with `_env_file=None` and must not see it). The inline
`deploy-staging` job became a sibling `needs: gates` job. The local gate
mirrors come from a vendored `Makefile.colormath` (repo Makefile just
`include`s it and defines `test`). No branch protection to update (private
repo, free plan).

## intendent — done (craigmbooth/intendent#71, @v0.5.0 as of #72)

- Vendor `Makefile.colormath`; set `COLORMATH_RUFF_CHECK_ARGS = --select I` and
  `COLORMATH_DIFF_COVER_BASE = origin/master` before the include

- `default-branch: master`, `python-version: "3.13"`
- `free-disk-space: true` (heavy ML tree)
- `ruff-select: "I"` (imports-only lint, until full lint is burned down)
- Port the pip hack from the tests job into `.colormath/ci-extra-install.sh`
- Move the starlette/torch CVE allowlist (with justifications) into
  `.colormath/audit.conf`
- **Ruleset gotcha (fixed 2026-07-09):** the "Master" ruleset still required
  the pre-colormath check names (no `gates / ` prefix), which never report
  under the suite — every PR showed the old names stuck "Expected" and was
  unmergeable without bypass. Required contexts now match the suite's
  `gates / <job name>` output. When adopting, always re-register the ruleset
  contexts, not just the workflow.
- Comment triggers (`issue_comment`/`pull_request_review_comment`) removed
  from the review caller (#73): every PR comment — including the review's own
  two bot comments — spawned a run that instantly skipped (ghost runs).
  Re-run reviews from the Actions UI or draft→ready instead of `@claude`.

## runwayz — done (PorticoFoundry/runwayz#283, @v0.5.0)

- Replaced the older `ci.yml` wholesale. Landed with `enable-styles: false`
  and `enable-a11y: false` (no stylelint/html-validate tooling yet) — burn
  down and enable gate by gate; add the `styles`/`a11y` npm scripts from
  [example/package.json](../example/package.json) when doing so.
- The old docstring-coverage sibling job folded into the suite's
  `docstrings` gate: `enable-docstrings: true` +
  `interrogate-paths: "core/ models/ routes/ services/ adapters/ schemas/ scripts/ jobs/"`
  (mirrored locally via `COLORMATH_INTERROGATE_PATHS`). The `build-css`
  sibling job stays project-side — colormath has no gate for it.
