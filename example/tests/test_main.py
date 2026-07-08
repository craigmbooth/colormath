from fastapi.testclient import TestClient

from main import app, greeting

client = TestClient(app)


def test_index_renders_greeting() -> None:
    response = client.get("/")
    assert response.status_code == 200
    assert "Hello, colormath!" in response.text


def test_greeting_strips_whitespace() -> None:
    assert greeting("  craig  ") == "Hello, craig!"


def test_greeting_defaults_to_world() -> None:
    assert greeting("   ") == "Hello, world!"
