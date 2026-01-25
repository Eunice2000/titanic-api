# Builder stage: Install dependencies
FROM python:3.9-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Install build deps only (no runtime debug tools)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Create venv and install Python deps
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY app/requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Runtime stage: Minimal image
FROM python:3.9-slim

# Security: non-root user
RUN groupadd -r titanic && useradd -r -g titanic -s /bin/false titanic

# Minimal runtime deps (only what's truly needed, e.g. for psycopg2 if binary wheels fail)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Copy venv from builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /app

# Copy only app code (chown to non-root)
COPY --chown=titanic:titanic app/ .

# Ensure logs dir if needed (optional)
RUN mkdir -p /app/logs && chown -R titanic:titanic /app/logs

USER titanic

EXPOSE 5000

# Optional: Add HEALTHCHECK here too (complement to compose-level one)
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:5000/ || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers=3", "--timeout=120", "src.app:create_app('production')"]
