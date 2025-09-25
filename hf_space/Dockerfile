FROM python:3.10-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Writable cache directory for HF/torch
RUN mkdir -p /data/.cache && chmod -R 777 /data
ENV HF_HOME=/data/.cache \
    TRANSFORMERS_CACHE=/data/.cache \
    TORCH_HOME=/data/.cache

# System deps (optional but helps with torch wheels)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt /app/requirements.txt
RUN pip install -r /app/requirements.txt

COPY app.py /app/app.py

EXPOSE 7860
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "7860"]


