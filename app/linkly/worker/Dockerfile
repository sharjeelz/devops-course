# syntax=docker/dockerfile:1
# Linkly worker. Same shape as the API image: deps → test → runtime.
FROM python:3.12-slim AS base
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1
WORKDIR /app

FROM base AS deps
COPY requirements.txt .
RUN pip install --prefix=/install -r requirements.txt

FROM base AS test
COPY --from=deps /install /usr/local
COPY requirements-dev.txt requirements.txt pytest.ini ./
RUN pip install -r requirements-dev.txt
COPY linkly_worker ./linkly_worker
COPY tests ./tests
CMD ["python", "-m", "pytest", "-q"]

FROM base AS runtime
COPY --from=deps /install /usr/local
COPY linkly_worker ./linkly_worker
RUN useradd --system --uid 10001 --no-create-home linkly
USER linkly
CMD ["python", "-m", "linkly_worker.main"]
