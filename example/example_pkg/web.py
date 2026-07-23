"""Web/delivery layer — may depend on the service layer below it."""

from example_pkg.service import compute


def handler() -> str:
    """Render the service result."""
    return f"result: {compute()}"
