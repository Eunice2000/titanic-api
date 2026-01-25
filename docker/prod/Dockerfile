FROM python:3.9-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN useradd -m -u 1000 titanic

COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY --chown=titanic:titanic app/ .

USER titanic

EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:create_app('production')"]
