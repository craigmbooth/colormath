# Adoption notes for the portfolio products

Working notes for migrating the maintainer's own products onto the gates
channel. Adoption order is always talas (canary) → intendent → runwayz
(see [LIFECYCLE.md](../LIFECYCLE.md)).

## talas — done (talas-app/talas#63, @v0.2.1; no review workflow or plugin yet — both opt-in)

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

## intendent — done (craigmbooth/intendent#71, @v0.4.0)

- Vendor `Makefile.colormath`; set `COLORMATH_RUFF_CHECK_ARGS = --select I` and
  `COLORMATH_DIFF_COVER_BASE = origin/master` before the include

- `default-branch: master`, `python-version: "3.13"`
- `free-disk-space: true` (heavy ML tree)
- `ruff-select: "I"` (imports-only lint, until full lint is burned down)
- Port the pip hack from the tests job into `.colormath/ci-extra-install.sh`
- Move the starlette/torch CVE allowlist (with justifications) into
  `.colormath/audit.conf`

## runwayz — next (and last)

- Replace the older `ci.yml` wholesale. Expect red on gates it never ran —
  land the caller with `enable-a11y: false`, `enable-deps: false`,
  `enable-diff-coverage: false`, `enable-styles: false`, then burn down and
  enable gate by gate.
- Add the `styles`/`a11y` npm scripts (copy from
  [example/package.json](../example/package.json)).
