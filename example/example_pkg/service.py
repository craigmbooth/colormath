"""Domain/service layer — must not depend on the web layer above it."""


def compute() -> int:
    """Return a value the web layer will render."""
    return 42
