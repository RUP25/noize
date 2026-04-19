FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt ./
RUN apt-get update && apt-get install -y build-essential libpq-dev gcc && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir -r requirements.txt
COPY app ./app
COPY scripts ./scripts
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1
# Cloud Run sets PORT (often 8080); Render/Railway/Fly also set PORT. Default 8000 for local docker run.
ENV PORT=8000
EXPOSE 8000
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
