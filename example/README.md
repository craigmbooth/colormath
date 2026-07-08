# colormath example app

A deliberately minimal app of the PorticoFoundry archetype (FastAPI + Poetry +
Jinja templates + vanilla-ish JS + token-driven CSS). It exists so colormath's
own CI can run the full gate suite (`.github/workflows/gates.yml`) against a
compliant consumer on every PR — a gates change that can't pass here can't be
tagged.

It also doubles as the reference for the consumer-side contract:

- `pyproject.toml` — `[tool.bandit]`, `[tool.mypy]`, `[tool.ruff]` sections the gates rely on
- `package.json` — the required npm scripts: `test`, `styles`, `a11y`
- `.stylelintrc.json` / `.htmlvalidate.json` — the design-token and a11y lint contracts
- `.colormath/audit.conf` — pip-audit groups + CVE allowlist read by the `deps` gate
- `.colormath/ci.env` — env sourced before pytest in CI

Keep it small. If a gate needs new surface to test, add the least code that
exercises it.
