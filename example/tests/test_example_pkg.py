from example_pkg.service import compute
from example_pkg.web import handler


def test_compute_returns_value() -> None:
    assert compute() == 42


def test_handler_renders_service_result() -> None:
    assert handler() == "result: 42"
