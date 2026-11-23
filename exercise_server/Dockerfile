FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 MPLCONFIGDIR=/tmp/matplotlib
WORKDIR /srv
RUN apt-get update && apt-get install -y --no-install-recommends \
    libegl1 libgles2 libgl1 libglib2.0-0 libgomp1 \
    && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip pip install -r requirements.txt
COPY exercise_server ./exercise_server

RUN useradd --system --uid 10001 appuser
USER appuser
EXPOSE 8000
CMD ["uvicorn", "exercise_server.main:app", "--host", "0.0.0.0", "--port", "8000", "--ws-max-size", "750000"]
