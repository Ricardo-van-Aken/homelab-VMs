# python:3.13-alpine3.22 -- digest pushed 2026-04-19 11:07 UTC
ARG PYTHON_IMAGE=python@sha256:e81548ac35b07a3bd4805f275107592ef458b1e893c0e04d45aedaa19416cca5

# Build from the repo root.

# ---------------------------------------------------------------------------
# builder: resolve the tools and Galaxy dependencies into a self-contained
# virtualenv
# ---------------------------------------------------------------------------
FROM ${PYTHON_IMAGE} AS builder

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_ROOT_USER_ACTION=ignore \
    PYTHONDONTWRITEBYTECODE=1

COPY docker/analysis/requirements.txt /tmp/requirements.txt

# Venv without pip, filled by the image's own pip: no installer or bytecode
# cache ends up in the shipped image.
RUN python -m venv --without-pip /opt/venv \
    && pip --python /opt/venv/bin/python install --only-binary=:all: --no-compile -r /tmp/requirements.txt

# Galaxy roles and collections.
COPY requirements.yml /tmp/requirements.yml
RUN /opt/venv/bin/ansible-galaxy role install -r /tmp/requirements.yml -p /opt/venv/share/ansible/roles \
    && /opt/venv/bin/ansible-galaxy collection install -r /tmp/requirements.yml -p /opt/venv/share/ansible/collections

# ---------------------------------------------------------------------------
# runtime: only copies tools needed at runtime. No buildtime dependencies
# ---------------------------------------------------------------------------
FROM ${PYTHON_IMAGE} AS runtime

RUN apk add --no-cache \
    # ansible-lint discovers files with `git ls-files`
    git \
    && adduser -D -u 1000 -h /home/analyst analyst

COPY --from=builder --chown=root:root /opt/venv /opt/venv

ENV PATH="/opt/venv/bin:${PATH}" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HOME=/home/analyst \
    ANSIBLE_HOME=/home/analyst/.ansible \
    FORCE_COLOR=1

LABEL org.opencontainers.image.title="ansible-analysis" \
      org.opencontainers.image.description="Static analysis for Ansible: ansible-lint, yamllint, syntax check" \
      org.opencontainers.image.licenses="GPL-3.0-only"

USER analyst
WORKDIR /work

CMD ["sh"]
