# python:3.13-alpine3.22 -- digest pushed 2026-04-19 11:07 UTC
ARG PYTHON_IMAGE=python@sha256:e81548ac35b07a3bd4805f275107592ef458b1e893c0e04d45aedaa19416cca5

# Targets:
#   runtime  -- ansible-core over ssh, for applying playbooks
#   molecule -- runtime + molecule, for testing roles against the host's
#               Docker daemon (mount /var/run/docker.sock and add its group)

# ---------------------------------------------------------------------------
# builder: resolve ansible-core into a self-contained virtualenv
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

COPY requirements.txt /tmp/requirements.txt

# The venv is created without pip and populated by the image's own pip via
# --python, so no installer ever lands in a shipped image. --no-compile
# keeps bytecode caches out of it too (as a flag: pip ignores the env form
# when re-executing under --python).
RUN python -m venv --without-pip /opt/venv \
    && pip --python /opt/venv/bin/python install --no-compile -r /tmp/requirements.txt

# ---------------------------------------------------------------------------
# builder-molecule: the same virtualenv plus the molecule layer
# ---------------------------------------------------------------------------
FROM builder AS builder-molecule

COPY requirements-molecule.txt /tmp/requirements-molecule.txt

RUN pip --python /opt/venv/bin/python install --no-compile -r /tmp/requirements-molecule.txt

# The docker driver's create/destroy playbooks are Ansible tasks and need
# these collections present. Pinned like everything else; installed into the
# venv so the molecule stage picks them up with the same single COPY.
RUN /opt/venv/bin/ansible-galaxy collection install -p /opt/venv/share/ansible/collections \
    # docker_container / docker_network modules used by the driver
    community.docker:==5.3.0 \
    # pulled in by community.docker
    community.library_inventory_filtering_v1:==1.1.5 \
    # synchronize/mount helpers the driver's playbooks reference
    ansible.posix:==2.2.2

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
# runtime: base + ansible-core
# ---------------------------------------------------------------------------
FROM base AS runtime

COPY --from=builder --chown=root:root /opt/venv /opt/venv

LABEL org.opencontainers.image.title="ansible-runtime" \
      org.opencontainers.image.description="Execution environment for Ansible: ansible-core over ssh"

# ---------------------------------------------------------------------------
# molecule: base + ansible-core + molecule
# ---------------------------------------------------------------------------
FROM base AS molecule

COPY --from=builder-molecule --chown=root:root /opt/venv /opt/venv

ENV ANSIBLE_COLLECTIONS_PATH=/opt/venv/share/ansible/collections:/home/operator/.ansible/collections

LABEL org.opencontainers.image.title="ansible-molecule" \
      org.opencontainers.image.description="Role testing for Ansible: molecule with the docker driver"
