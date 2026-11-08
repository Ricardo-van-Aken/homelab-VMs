# Build from the repo root.

# ---------------------------------------------------------------------------
# builder: resolve the tools and Galaxy dependencies into a self-contained
# virtualenv
# ---------------------------------------------------------------------------
FROM python:3.13-alpine3.24@sha256:1e1f6334529d1fb26a2ef619d7cffb30a7c7d7cc1cc7338ebee283a58d1aeaca AS builder

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
# git: roles are pinned to commits and fetched from their repositories
RUN apk add --no-cache git \
    && /opt/venv/bin/ansible-galaxy role install -r /tmp/requirements.yml -p /opt/venv/share/ansible/roles \
    && /opt/venv/bin/ansible-galaxy collection install -r /tmp/requirements.yml -p /opt/venv/share/ansible/collections

# ---------------------------------------------------------------------------
# runtime: only copies tools needed at runtime. No buildtime dependencies
# ---------------------------------------------------------------------------
FROM python:3.13-alpine3.24@sha256:1e1f6334529d1fb26a2ef619d7cffb30a7c7d7cc1cc7338ebee283a58d1aeaca AS runtime

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
