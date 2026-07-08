#!/usr/bin/env bash
#
# Dependency CVE audit (pip-audit) over the locked, DEPLOYED dependencies
# (dev tooling never ships). Single source of truth for `make audit` and the
# CI `deps` gate.
#
# Reproducible: exports the exact pinned versions from poetry.lock and audits
# them with --no-deps, so local and CI audit exactly what ships.
#
# Per-project configuration is sourced from .colormath/audit.conf in the
# consumer repo (path overridable via COLORMATH_AUDIT_CONF):
#
#   # Poetry groups that ship to production, passed to `poetry export --with`.
#   # Empty = main group only.
#   POETRY_EXPORT_GROUPS="webapp,worker"
#
#   # Space-separated CVE/PYSEC ids to ignore. Keep this list as small as
#   # possible; every entry needs a justification comment + revisit trigger.
#   IGNORE_VULNS="CVE-2025-0000 PYSEC-2026-000"
set -euo pipefail

command -v pip-audit >/dev/null 2>&1 || {
  echo "pip-audit not installed — run: pip install pip-audit" >&2
  exit 1
}

CONF="${COLORMATH_AUDIT_CONF:-.colormath/audit.conf}"
POETRY_EXPORT_GROUPS=""
IGNORE_VULNS=""
if [ -f "$CONF" ]; then
  # shellcheck source=/dev/null
  . "$CONF"
fi

REQ="$(mktemp)"
trap 'rm -f "$REQ"' EXIT

if [ -n "$POETRY_EXPORT_GROUPS" ]; then
  poetry export --format requirements.txt --output "$REQ" --with "$POETRY_EXPORT_GROUPS" >/dev/null
else
  poetry export --format requirements.txt --output "$REQ" >/dev/null
fi

IGNORES=()
for vuln in $IGNORE_VULNS; do
  IGNORES+=(--ignore-vuln "$vuln")
done

pip-audit -r "$REQ" --no-deps ${IGNORES[@]+"${IGNORES[@]}"}
