#!/usr/bin/env bash
#
# Diff coverage gate: run the Python test suite with coverage, then require the
# lines CHANGED vs the base branch to be covered. This is the per-change
# upgrade of a repo-wide --cov-fail-under — it never fails on pre-existing
# untested code, only on new/changed lines that lack tests.
#
# Single source of truth for `make coverage-diff` and the CI `diff-coverage`
# gate. Configuration via env:
#   DIFF_COVER_BASE        base branch ref (default origin/main)
#   DIFF_COVER_FAIL_UNDER  minimum percent for changed lines (default 90)
set -euo pipefail

command -v diff-cover >/dev/null 2>&1 || {
  echo "diff-cover not installed — run: pip install diff-cover" >&2
  exit 1
}

BASE="${DIFF_COVER_BASE:-origin/main}"
FAIL_UNDER="${DIFF_COVER_FAIL_UNDER:-90}"

poetry run pytest tests/ --cov=. --cov-report=xml -q
diff-cover coverage.xml --compare-branch="$BASE" --fail-under="$FAIL_UNDER"
