FROM python:3.13-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && useradd --uid 10001 --create-home app && mkdir /data && chown app:app /data
COPY app.py manage.py humanizer-patterns.json .
USER app
EXPOSE 8080
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--threads", "2", "--timeout", "90", "--access-logfile", "/dev/null", "--limit-request-line", "2048", "--limit-request-field_size", "2048", "app:create_app()"]
