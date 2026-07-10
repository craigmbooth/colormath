# Minimal Cloud Run-shaped image for the example app. The gate suite never
# builds it — it exists so the dockerfile gate (hadolint) has something real
# to lint, and as the contract reference for a hadolint-clean Dockerfile.
FROM python:3.12-slim

WORKDIR /app

COPY pyproject.toml poetry.lock ./
RUN pip install --no-cache-dir poetry==2.1.4 \
    && poetry config virtualenvs.create false \
    && poetry install --no-interaction --no-root --only main

COPY . .

EXPOSE 8080
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
