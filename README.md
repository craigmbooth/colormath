# colormath

Shared infrastructure for the PorticoFoundry app archetype (FastAPI + Poetry +
Tailwind/Alpine + Jinja + Postgres/Redis + GCP Cloud Run). One repo, one
version stream, four distribution channels — each artifact class rides the
mechanism with the smallest merge surface:

| Channel | What | How consumers use it |
|---|---|---|
| **A: CI gates** | 9-gate reusable workflow + composite actions + gate scripts | `uses: craigmbooth/colormath/.github/workflows/gates.yml@vX.Y.Z` |
| **B: in-repo files** | Dockerfile, Makefiles, compose, deploy.sh, … *(planned)* | Copier template; `copier update` 3-way-merges |
| **C: Terraform** | Cloud Run / database / redis / WIF modules *(planned)* | `source = "git::https://github.com/craigmbooth/colormath.git//terraform/modules/<name>?ref=vX.Y.Z"` |
| **D: agent harness** | Portable Claude Code skills/commands *(planned)* | Plugin marketplace |

colormath ships **no runtime application code** — that's the lesson of its
predecessor (portico, which ended up vendored and forked). Infra only.

## The 10-second rule

> Would a sibling repo copy this file unmodified except for names/ports/IDs?
> → colormath. Does it mention the *domain* (careers, factbase, intents, LLM
> vendor)? → project. Does it need more than ~3 template variables to serve
> every project? → it's a product decision wearing a costume; keep it in the
> project.

## Versioning

Single SemVer tag stream, **exact-tag pins only** (never a floating major
tag): upgrades must arrive as a reviewable PR, not as a surprise inside an
unrelated one. The rule for MAJOR: *if a consumer's CI, deploy, or `terraform
plan` can go from green to red without the consumer editing anything, it's
MAJOR.* Details in [LIFECYCLE.md](LIFECYCLE.md). While on `0.x`, breaking
changes may land in any release.

## The gates

Nine parallel CI gates (each maps to a local `make` target in consumers):

| Gate | Tool | Enforces |
|---|---|---|
| `ruff` | ruff | formatting + lint |
| `tests` | vitest + pytest | JS and Python suites green |
| `typecheck` | mypy | type checks pass |
| `styles` | stylelint | design tokens only — no hardcoded colors/font-sizes |
| `sast` | bandit | no Medium+ security findings in app source |
| `secrets` | gitleaks | no secrets anywhere in git history |
| `a11y` | html-validate | templates pass the a11y preset |
| `deps` | pip-audit | locked, shipped deps have no actionable CVEs |
| `diff-coverage` | diff-cover | changed lines ≥90% covered |

Every gate has an `enable-<gate>` input (default `true`) so a consumer can
adopt incrementally: disable, burn down findings, enable. Disabled gates show
as *skipped* — visible, never silently absent.

## Adopting the gates in a product

### 1. Replace your `gates.yml` (or `ci.yml`) with a caller

```yaml
name: Gates

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  gates:
    uses: craigmbooth/colormath/.github/workflows/gates.yml@v0.1.0
    with:
      python-version: "3.12"
      default-branch: main
      poetry-install-args: "--with webapp,worker"
```

Project-specific jobs (deploy-staging, seeding, previews) stay in your repo as
siblings that gate on the suite:

```yaml
  deploy-staging:
    needs: gates
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    # ... your deploy steps, unchanged
```

### 2. Satisfy the consumer-side contract

| File | Purpose |
|---|---|
| `.colormath/audit.conf` | pip-audit groups + CVE allowlist (see `example/.colormath/audit.conf`) |
| `.colormath/ci.env` | non-secret env sourced before pytest in CI (optional) |
| `.colormath/ci-extra-install.sh` | extra install steps after `poetry install` (optional, executable) |
| `.gitleaks.toml` | gitleaks allowlist (optional; used when present) |
| `pyproject.toml` | needs `[tool.bandit]` (and your mypy/ruff config as usual) |
| `package.json` | npm scripts `test`, `styles`, `a11y` (see `example/package.json`) |

The [example/](example/) app is the reference implementation of this contract
— colormath's own CI runs the full suite against it on every PR.

### 3. Per-product notes

- **talas** (canary — adopt first): `default-branch: main`. Delete
  `scripts/diff-coverage.sh` and `scripts/audit-deps.sh` after moving their
  poetry groups + CVE allowlist into `.colormath/audit.conf`; keep your
  Makefile targets pointing at the same contract. Move the inline
  `deploy-staging` job to a sibling `needs: gates` job.
- **intendent**: `default-branch: master`, `python-version: "3.13"`,
  `free-disk-space: true` (heavy ML tree), `ruff-select: "I"` (imports-only
  lint, until full lint is burned down), and port the pip hack from the tests
  job into `.colormath/ci-extra-install.sh`. Move the starlette/torch CVE
  allowlist (with justifications) into `.colormath/audit.conf`.
- **runwayz**: replace the older `ci.yml` wholesale. Expect red on gates it
  never ran — land the caller with `enable-a11y: false`, `enable-deps: false`,
  `enable-diff-coverage: false`, `enable-styles: false`, then burn down and
  enable gate by gate. Add the `styles`/`a11y` npm scripts (copy from
  `example/package.json`).

### 4. Update branch protection

Point required status checks at the new job names (`ruff`, `tests`,
`typecheck`, `styles`, `sast`, `secrets`, `a11y`, `deps`, `diff-coverage`).

## Repo layout

```
.github/workflows/gates.yml    # the reusable gate suite (workflow_call)
.github/workflows/ci.yml       # self-test: runs the suite against example/
.github/actions/               # setup-python-poetry, setup-node, gate-summary
scripts/                       # gate scripts fetched by the workflow at its own ref
example/                       # minimal compliant consumer + contract reference
```

Planned (see the migration plan): `template/` (Copier), `terraform/modules/`,
`plugin/` (Claude Code marketplace).

## Public-repo hygiene

This repo is public so private consumers under different GitHub owners can use
every channel without auth friction. Consequences: **never commit real project
IDs, tfvars values, or secrets** — the gitleaks gate runs on colormath itself,
and example values must stay obviously fake.
