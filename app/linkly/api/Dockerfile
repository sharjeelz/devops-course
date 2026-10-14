# syntax=docker/dockerfile:1
# Linkly API. Stages: deps (install packages) → test (run the tests) → runtime (what ships).
#   docker build -t linkly-api .                 # the runtime image
#   docker build --target test -t linkly-api:test . && docker run --rm linkly-api:test
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
COPY linkly_api ./linkly_api
COPY tests ./tests
CMD ["python", "-m", "pytest", "-q"]

FROM base AS runtime
COPY --from=deps /install /usr/local
COPY linkly_api ./linkly_api
RUN useradd --system --uid 10001 --no-create-home linkly
# The version this image was built from (CI passes the release tag); /healthz reports it.
ARG VERSION=dev
ENV LINKLY_VERSION=$VERSION
USER linkly
EXPOSE 8000
HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=5 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/healthz', timeout=2)"]
CMD ["uvicorn", "linkly_api.main:app_from_env", "--factory", "--host", "0.0.0.0", "--port", "8000"]
