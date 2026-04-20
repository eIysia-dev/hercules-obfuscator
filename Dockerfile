FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    lua5.1 \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY . .

RUN pip3 install --no-cache-dir -r api/requirements.txt

ENV HERCULES_DIR=/app
ENV PORT=5000

EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--timeout", "90", "api.app:app"]
