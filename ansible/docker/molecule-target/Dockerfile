FROM ubuntu:26.04@sha256:c098726dd9b9733f3e885f8de0ef375206a311b0a317eadc40d347b1115fb944

# Molecule test target: stands in for a VM while roles are applied to it.
# Ansible itself never runs here. The package set mirrors what the Ubuntu
# cloud image provides and roles rely on: python3 (modules run with it), sudo
# (become) and gpg (apt keys). systemd is PID 1 so roles can manage services.
# Run with: privileged, cgroupns=host, /sys/fs/cgroup mounted rw.

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        systemd \
        systemd-sysv \
        python3 \
        sudo \
        gpg \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    # Units that need a console, hardware or a seat make no sense in a
    # container; mask them so boot reaches multi-user.target cleanly.
    && systemctl mask \
        getty.target \
        console-getty.service \
        systemd-udevd.service \
        systemd-udev-trigger.service \
        systemd-logind.service \
        systemd-remount-fs.service

LABEL org.opencontainers.image.title="molecule-target" \
      org.opencontainers.image.description="Ubuntu 26.04 with systemd, the VM stand-in for Molecule scenarios" \
      org.opencontainers.image.licenses="GPL-3.0-only"

STOPSIGNAL SIGRTMIN+3
CMD ["/lib/systemd/systemd"]
