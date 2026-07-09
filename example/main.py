"""Minimal FastAPI app of the PorticoFoundry archetype.

Exists so colormath's own CI can run the full gate suite against a compliant
consumer. Every gate must have something real to chew on: a route and a pure
function (tests + diff-coverage), type annotations (mypy), a Jinja template
(a11y), and source CSS (stylelint).
"""

from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

BASE_DIR = Path(__file__).resolve().parent

app = FastAPI(title="colormath-example")
templates = Jinja2Templates(directory=str(BASE_DIR / "templates"))


def greeting(name: str) -> str:
    """Return the greeting shown on the index page."""
    cleaned = name.strip() or "world"
    return f"Hello, {cleaned}!"


@app.get("/", response_class=HTMLResponse)
async def index(request: Request) -> HTMLResponse:
    """Render the index page."""
    return templates.TemplateResponse(
        request=request,
        name="index.html",
        context={"message": greeting("colormath")},
    )
