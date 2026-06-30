FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev gcc curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Persistent volume mount point for media uploads
RUN mkdir -p /app/uploads

EXPOSE 8000

HEALTHCHECK --interval=15s --timeout=5s --start-period=20s --retries=3 \
  CMD curl -f http://localhost:8000/api/v1/organizations/ \
      -H "X-Organization-ID: 00000000-0000-0000-0000-000000000000" \
      -o /dev/null -s || exit 1

# Single worker is REQUIRED on this single-machine deploy: the chess WebSocket
# GameSession manager keeps both players' sockets in per-process memory, so with
# >1 worker the two players of a game can land on different processes and never
# see each other's moves. One async worker also stops the APScheduler jobs from
# double-firing. (To scale beyond one worker/machine, move the WS manager and
# scheduler onto a shared backplane like Redis.)
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
