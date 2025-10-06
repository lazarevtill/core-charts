FROM python:3.11-slim

WORKDIR /app

RUN pip install --no-cache-dir \
    kubernetes==28.1.0 \
    requests==2.31.0

COPY deployment-tracker.py /app/

RUN chmod +x /app/deployment-tracker.py

CMD ["python3", "-u", "/app/deployment-tracker.py"]
