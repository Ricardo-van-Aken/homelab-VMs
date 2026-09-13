# python:3.13-alpine3.22 -- digest pushed 2026-04-19 11:07 UTC
ARG PYTHON_IMAGE=python@sha256:e81548ac35b07a3bd4805f275107592ef458b1e893c0e04d45aedaa19416cca5

# Build from the repo root.
# Targets:
#   runtime  -- ansible-core plus the Galaxy dependencies from requirements.yml,
#               for applying playbooks over ssh with the project mounted at /work
#   molecule -- runtime + molecule, for testing roles against the host's
#               Docker daemon (mount /var/run/docker.sock and add its group)

# ---------------------------------------------------------------------------
# builder: resolve ansible-core and the Galaxy dependencies into a
# self-contained virtualenv
# ---------------------------------------------------------------------------
FROM ${PYTHON_IMAGE} AS builder

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_ROOT_USER_ACTION=ignore \
    # ansible-galaxy runs in the builder too; keep its bytecode out of the venv.
    PYTHONDONTWRITEBYTECODE=1 \
    # Fail loudly if a dependency has no wheel for the target platform
    # instead of silently pulling in a compiler at build time.
    PIP_ONLY_BINARY=:all:

COPY docker/runtime/requirements.txt /tmp/requirements.txt

# The venv is created without pip and populated by the image's own pip via
# --python, so no installer ever lands in a shipped image. --no-compile
# keeps bytecode caches out of it too (as a flag: pip ignores the env form
# when re-executing under --python).
RUN python -m venv --without-pip /opt/venv \
    && pip --python /opt/venv/bin/python install --no-compile -r /tmp/requirements.txt

# Galaxy roles and collections.
COPY requirements.yml /tmp/requirements.yml
# git: roles are pinned to commits and fetched from their repositories
RUN apk add --no-cache git \
    && /opt/venv/bin/ansible-galaxy role install -r /tmp/requirements.yml -p /opt/venv/share/ansible/roles \
    && /opt/venv/bin/ansible-galaxy collection install -r /tmp/requirements.yml -p /opt/venv/share/ansible/collections

# ---------------------------------------------------------------------------
# builder-molecule: the same virtualenv plus the molecule layer
# ---------------------------------------------------------------------------
FROM builder AS builder-molecule

COPY docker/runtime/requirements-molecule.txt /tmp/requirements-molecule.txt

RUN pip --python /opt/venv/bin/python install --no-compile -r /tmp/requirements-molecule.txt

# ---------------------------------------------------------------------------
# base: everything the shipped images share except the virtualenv
# ---------------------------------------------------------------------------
FROM ${PYTHON_IMAGE} AS base

RUN apk add --no-cache \
    # the transport behind the default ssh connection plugin
    openssh-client \
    # password-based ssh and become auth (--ask-pass/--ask-become-pass)
    sshpass \
    # scm-sourced ansible-galaxy requirements
    git \
    && adduser -D -u 1000 -h /home/operator operator

ENV PATH="/opt/venv/bin:${PATH}" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HOME=/home/operator \
    ANSIBLE_HOME=/home/operator/.ansible \
    FORCE_COLOR=1

LABEL org.opencontainers.image.licenses="GPL-3.0-only"

USER operator
WORKDIR /work

CMD ["sh"]

# ---------------------------------------------------------------------------
# runtime: base + ansible-core + Galaxy dependencies
# ---------------------------------------------------------------------------
FROM base AS runtime

COPY --from=builder --chown=root:root /opt/venv /opt/venv

LABEL org.opencontainers.image.title="ansible-runtime" \
      org.opencontainers.image.description="Execution environment for Ansible: ansible-core over ssh"

# ---------------------------------------------------------------------------
# molecule: base + ansible-core + Galaxy dependencies + molecule
# ---------------------------------------------------------------------------
FROM base AS molecule

USER root
RUN apk add --no-cache docker-cli
USER operator

COPY --from=builder-molecule --chown=root:root /opt/venv /opt/venv

# Molecule runs with its own generated ansible.cfg, so the baked-in paths have
# to come from the environment here.
ENV ANSIBLE_COLLECTIONS_PATH=/opt/venv/share/ansible/collections:/home/operator/.ansible/collections \
    ANSIBLE_ROLES_PATH=/opt/venv/share/ansible/roles:/home/operator/.ansible/roles

LABEL org.opencontainers.image.title="ansible-molecule" \
      org.opencontainers.image.description="Role testing for Ansible: molecule with the docker driver"
