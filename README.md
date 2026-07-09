# colormath

[![CI](https://github.com/ColorMath/ci/actions/workflows/ci.yml/badge.svg)](https://github.com/ColorMath/ci/actions/workflows/ci.yml)

**Nine CI quality gates for Python web apps, in one `uses:` line.**

colormath is a reusable GitHub Actions workflow (plus the scripts and composite
actions behind it) that gives a Poetry-managed Python project a complete,
parallel CI gate suite: formatting, lint, types, tests, security, secrets,
accessibility, dependency CVEs, and per-change test coverage.

It grew out of a family of FastAPI + Poetry + Jinja/Tailwind apps deployed on
Cloud Run, but the gates apply to most Poetry projects — the JS-based gates
(frontend tests, CSS lint, template accessibility) are driven by npm scripts
you define, and any gate can be switched off.

## Quick start

Create `.github/workflows/gates.yml` in your repo:

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
    uses: ColorMath/ci/.github/workflows/gates.yml@v0.3.0
    with:
      python-version: "3.12"
      default-branch: main
```

Open a pull request and you'll get nine parallel checks, each posting a
compact stats block to the run summary. Project-specific jobs (deploys,
previews, seeding) stay in your repo as siblings that gate on the suite:

```yaml
  deploy-staging:
    needs: gates
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    # ... your deploy steps, unchanged
```

The [example/](example/) directory is a minimal compliant consumer — start
there to see every contract file in place. colormath's own CI runs the full
suite against it on every PR.

## The gates

| Gate | Tool | Enforces |
|---|---|---|
| `ruff` | [ruff](https://docs.astral.sh/ruff/) | formatting + lint |
| `tests` | vitest + pytest | JS and Python suites green |
| `typecheck` | [mypy](https://mypy-lang.org/) | type checks pass |
| `styles` | [stylelint](https://stylelint.io/) | design tokens only — no hardcoded colors/font-sizes |
| `sast` | [bandit](https://bandit.readthedocs.io/) | no Medium+ security findings in app source |
| `secrets` | [gitleaks](https://github.com/gitleaks/gitleaks) | no secrets anywhere in git history |
| `a11y` | [html-validate](https://html-validate.org/) | templates pass the a11y preset |
| `deps` | [pip-audit](https://pypi.org/project/pip-audit/) | locked, shipped deps have no actionable CVEs |
| `diff-coverage` | [diff-cover](https://github.com/Bachmann1234/diff_cover) | changed lines ≥90% covered |

Two design choices worth calling out:

- **`diff-coverage`, not total coverage.** The gate requires the lines you
  *changed* to be covered. It never fails on pre-existing untested code, so
  you can adopt it on day one of a legacy codebase and ratchet quality up one
  PR at a time.
- **`deps` audits what ships.** Locked versions are exported from
  `poetry.lock` for the production dependency groups only — dev tooling never
  triggers a CVE failure, and local runs audit exactly what CI audits.

## Adopting incrementally

Every gate has an `enable-<gate>` input (default `true`). On a codebase with
existing findings, land the caller with the failing gates disabled, burn the
findings down, and enable them one by one:

```yaml
    uses: ColorMath/ci/.github/workflows/gates.yml@v0.3.0
    with:
      python-version: "3.12"
      default-branch: main
      enable-a11y: false           # TODO: burn down template findings
      enable-diff-coverage: false  # TODO: enable once the suite measures coverage
```

Disabled gates show as *skipped* in the run — visible, never silently absent.

## Configuration

### Workflow inputs

All inputs are optional.

| Input | Default | Purpose |
|---|---|---|
| `python-version` | `"3.12"` | Python for all Python gates |
| `node-version` | `"22"` | Node for all JS gates (html-validate 11.x needs ≥22) |
| `default-branch` | repo default | Base branch for diff-coverage |
| `workdir` | `"."` | Directory containing the app, for monorepos |
| `poetry-install-args` | `""` | Extra `poetry install` args, e.g. `"--with webapp,worker"` |
| `ruff-spec` | `"ruff>=0.14,<0.15"` | pip spec for ruff — match your pyproject pin |
| `ruff-select` | `""` (full lint) | Restrict `ruff check` to specific rules, e.g. `"I"` |
| `bandit-spec` | `"bandit>=1.9,<2"` | pip spec for bandit — match your pyproject pin |
| `gitleaks-version` | `"8.30.1"` | gitleaks release to install |
| `diff-cover-fail-under` | `"90"` | Minimum % coverage on changed lines |
| `free-disk-space` | `false` | Reclaim runner disk first (heavy ML dependency trees) |
| `enable-<gate>` | `true` | Per-gate opt-out (see above) |

### Files in your repo

| File | Needed for | Purpose |
|---|---|---|
| `pyproject.toml` with `[tool.bandit]` | `sast` | scan scope/excludes (plus your mypy/ruff config as usual) |
| `.colormath/audit.conf` | `deps` | poetry groups that ship + CVE allowlist ([reference](example/.colormath/audit.conf)) |
| npm scripts `test`, `styles`, `a11y` | the JS gates | see [example/package.json](example/package.json) |
| `.colormath/ci.env` | optional | non-secret env sourced before pytest in CI |
| `.colormath/ci-extra-install.sh` | optional | extra install steps after `poetry install` (must be executable) |
| `.gitleaks.toml` | optional | gitleaks false-positive allowlist, used when present |

Once the checks are green, register each gate's job name as a required status
check in your branch protection (they appear as `gates / Ruff (format + lint)`
and so on).

## Optional: AI review + test plan

[review.yml](.github/workflows/review.yml) is a second reusable workflow —
entirely opt-in, adopted per project by adding a caller (skip the caller and
nothing changes). It runs two Claude agents in parallel on every non-draft PR
(re-runnable by commenting `@claude`):

- **review** — the "Thermonuclear Review": a deliberately adversarial audit of
  the diff across correctness, security, maintainability, and DevEx, posted as
  a tracking comment (marker line `## Thermonuclear Review`) with inline
  comments on the relevant lines.
- **test-plan** — classifies the diff (UI vs API surface) and posts a
  `## Test Plan` comment with concrete QA checklists, exposing a
  machine-readable verdict (`qa_depth`, `requires_ui_qa`, `requires_api_qa`)
  as workflow outputs for downstream QA jobs to gate on.

```yaml
name: claude-review

on:
  pull_request:
    types: [opened, reopened, ready_for_review]
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]

jobs:
  review:
    uses: ColorMath/ci/.github/workflows/review.yml@v0.3.0
    permissions:
      contents: read
      pull-requests: write
      issues: write
      id-token: write
    secrets:
      anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
    with:
      review-focus: "Pay attention to <project-specific hot spots>."
```

Inputs: `model` (default `claude-sonnet-4-6`), `review-focus` (extra
project-specific emphasis for the reviewer), and `enable-review` /
`enable-test-plan` toggles. Requires an `ANTHROPIC_API_KEY` repo secret.

## Running the gates locally

[Makefile.colormath](Makefile.colormath) defines a local mirror of every gate,
so all consumers share the same `make` endpoints. Vendor it once:

```sh
curl -fsSLO https://raw.githubusercontent.com/ColorMath/ci/v0.3.0/Makefile.colormath
```

then include it from your Makefile, providing the one target it expects from
you (`test`) and overriding knobs before the include if your project differs:

```make
# COLORMATH_DIFF_COVER_BASE = origin/master   # example override
include Makefile.colormath

test: ## your mirror of the tests gate
	poetry run pytest tests/ && npm test
```

Now `make format-check lint typecheck styles sast secrets a11y audit
coverage-diff` mirror the CI gates one-for-one, and `make preflight` runs the
whole suite. The `audit` and `coverage-diff` targets fetch their gate scripts
from this repo at the file's own stamped tag, so local runs and CI share one
implementation. On upgrades, `make colormath-update REF=vX.Y.Z` refreshes the
vendored file — keep it in lockstep with your `gates.yml` pin, and review the
diff like any other dependency bump.

## Versioning and upgrades

One SemVer tag stream, and consumers pin **exact tags only** (`@v0.3.0`, never
a floating major tag): an upgrade should arrive as a reviewable PR whose diff
and changelog explain themselves — not as a surprise inside an unrelated one.

The rule for MAJOR: *if a consumer's CI can go from green to red without the
consumer editing anything, it's MAJOR.* New gates ship disabled-by-default in
a MINOR and are promoted to default-on in the next MAJOR. Details in
[LIFECYCLE.md](LIFECYCLE.md); release history in [CHANGELOG.md](CHANGELOG.md).
While on `0.x`, breaking changes may land in any release.

## What's in this repo

```
.github/workflows/gates.yml    # the reusable gate suite (workflow_call)
.github/workflows/review.yml   # optional reusable AI review + test-plan suite
.github/workflows/ci.yml       # self-test: runs the suite against example/
.github/actions/               # setup-python-poetry, setup-node, gate-summary
Makefile.colormath             # shared local gate targets — vendored by consumers
scripts/                       # gate scripts, fetched by the workflow at its own ref
example/                       # minimal compliant consumer + contract reference
docs/                          # adoption notes for the maintainer's own products
```

Planned next, on the same tag stream and exact-pin rule: a Copier template for
the in-repo files this stack shares (Dockerfile, Makefile, compose), Terraform
modules for the Cloud Run deployment shape, and a Claude Code plugin.

## Design principle

colormath ships **no runtime application code** — infrastructure only. The
10-second rule for what belongs here: would a sibling project copy this file
unmodified except for names, ports, and IDs? Then it belongs in colormath.
Does it mention a specific domain, or need more than ~3 template variables to
fit every project? Then it's a product decision wearing a costume; keep it in
your repo.

This repo is public so consumers under any GitHub owner can use every channel
without auth friction. Never commit real project IDs or secrets — the gitleaks
gate runs on colormath itself, and example values must stay obviously fake.

## License

[MIT](LICENSE)
