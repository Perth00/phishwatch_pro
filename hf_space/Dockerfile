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
COPY autocalib_phishy.csv /app/autocalib_phishy.csv
COPY autocalib_legit.csv /app/autocalib_legit.csv
COPY known_hosts.csv /app/known_hosts.csv

# Default CSV envs to follow CSVs in image (can be overridden in Space settings)
ENV AUTOCALIB_PHISHY_CSV=/app/autocalib_phishy.csv \
    AUTOCALIB_LEGIT_CSV=/app/autocalib_legit.csv \
    KNOWN_HOSTS_CSV=/app/known_hosts.csv

EXPOSE 7860
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "7860"]


