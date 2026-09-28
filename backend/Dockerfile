FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

# Baked into the image, not left to the orchestrator, so it runs the same way
# under docker-compose (local dev) and on Magic Containers (production) -
# docker-compose.yml previously supplied this via its own `command:` override,
# which a platform that just deploys the image would never see.
CMD ["sh", "-c", "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8000"]
