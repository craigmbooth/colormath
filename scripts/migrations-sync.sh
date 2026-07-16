#!/usr/bin/env bash
# Gate: fail when the base branch has migration changes this branch predates.
#
# All PorticoFoundry apps use alembic. A PR that branched before newer
# migrations landed on the default branch merges into multiple alembic heads —
# catch that here and tell the author to pull, instead of letting
# `alembic upgrade` discover it in a deploy.
#
# The check: diff the base branch against its merge-base with HEAD, scoped to
# the migrations directory. Anything in that diff is a migration the base has
# and this branch predates. (On the base branch itself the merge-base is HEAD,
# the diff is empty, and the gate passes trivially.)
#
# Env:
#   MIGRATIONS_PATH  migrations directory to watch (default: alembic/versions)
#   MIGRATIONS_BASE  base ref, e.g. origin/main. Empty = discover the default
#                    branch from origin/HEAD, falling back to origin/main,
#                    then origin/master.
set -euo pipefail

MIGRATIONS_PATH="${MIGRATIONS_PATH:-alembic/versions}"
BASE="${MIGRATIONS_BASE:-}"

if [ -z "$BASE" ]; then
  head_ref=$(git symbolic-ref -q refs/remotes/origin/HEAD || true)
  if [ -n "$head_ref" ]; then
    BASE="origin/${head_ref#refs/remotes/origin/}"
  elif git show-ref -q --verify refs/remotes/origin/main; then
    BASE="origin/main"
  elif git show-ref -q --verify refs/remotes/origin/master; then
    BASE="origin/master"
  else
    echo "migrations-sync: cannot discover the default branch (no origin/HEAD, origin/main, or origin/master); set MIGRATIONS_BASE" >&2
    exit 2
  fi
fi
BRANCH="${BASE#origin/}"

if ! merge_base=$(git merge-base HEAD "$BASE"); then
  echo "migrations-sync: no merge base between HEAD and $BASE — shallow clone? fetch full history" >&2
  exit 2
fi

changed=$(git diff --name-only "$merge_base" "$BASE" -- "$MIGRATIONS_PATH")
if [ -n "$changed" ]; then
  echo "✖ $BRANCH has migration changes under $MIGRATIONS_PATH that this branch predates:"
  printf '%s\n' "$changed" | sed 's/^/    /'
  echo
  echo "Divergent alembic migrations merge into multiple heads. Pull in the latest $BRANCH, then re-check your migration chain:"
  echo "    git pull --rebase origin $BRANCH"
  exit 1
fi

echo "✓ $MIGRATIONS_PATH is in sync with $BRANCH (merge-base $(git rev-parse --short "$merge_base"))"
