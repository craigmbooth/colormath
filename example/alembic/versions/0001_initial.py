"""Initial schema.

Reference migration so the migrations gate has a real directory to watch in
the example consumer. Deliberately alembic-free (no `op` import) — the gate
only diffs the directory; it never executes migrations.
"""

revision = "0001_initial"
down_revision = None


def upgrade() -> None:
    """Apply the (empty) initial schema."""


def downgrade() -> None:
    """Revert the (empty) initial schema."""
