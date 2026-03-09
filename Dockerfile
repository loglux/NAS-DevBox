FROM ubuntu:24.04

# Install core packages + dev essentials
RUN apt update && \
    apt install -y \
        openssh-server \
        openssh-client \
        sudo \
        locales \
        build-essential \
        git \
        curl \
        wget \
        rsync \
        shellcheck \
        nano \
        vim \
        htop \
        iputils-ping \
        net-tools \
        ca-certificates \
        bash-completion \
        tmux \
        gnupg && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list && \
    apt update && \
    apt install -y docker-ce-cli docker-compose-plugin && \
    locale-gen C.UTF-8 && \
    mkdir /var/run/sshd && \
    apt clean

# Build-time configuration
ARG DEVBOX_USER=dev
ARG DEVBOX_PASS=changeme
ARG DEVBOX_UID=1000
ARG DEVBOX_GID=1000
ARG DOCKER_GID=1000

# Create non-root user with host-matching UID/GID.
# ubuntu:24.04 already has UID/GID 1000 ("ubuntu"), so reuse/rename when needed.
RUN set -eux; \
    if ! getent group "${DEVBOX_GID}" >/dev/null 2>&1; then \
      groupadd -g "${DEVBOX_GID}" "${DEVBOX_USER}"; \
    fi; \
    PRIMARY_GROUP="$(getent group "${DEVBOX_GID}" | cut -d: -f1)"; \
    EXISTING_UID_USER="$(getent passwd "${DEVBOX_UID}" | cut -d: -f1 || true)"; \
    if id -u "${DEVBOX_USER}" >/dev/null 2>&1; then \
      if [ -n "${EXISTING_UID_USER}" ] && [ "${EXISTING_UID_USER}" != "${DEVBOX_USER}" ]; then \
        echo "UID ${DEVBOX_UID} is already owned by ${EXISTING_UID_USER}; cannot remap existing ${DEVBOX_USER}" >&2; \
        exit 1; \
      fi; \
      usermod -u "${DEVBOX_UID}" -g "${PRIMARY_GROUP}" "${DEVBOX_USER}"; \
    else \
      if [ -n "${EXISTING_UID_USER}" ]; then \
        EXISTING_HOME="$(getent passwd "${EXISTING_UID_USER}" | cut -d: -f6)"; \
        usermod -l "${DEVBOX_USER}" "${EXISTING_UID_USER}"; \
        if [ "${EXISTING_HOME}" != "/home/${DEVBOX_USER}" ]; then \
          usermod -d "/home/${DEVBOX_USER}" -m "${DEVBOX_USER}"; \
        fi; \
        usermod -g "${PRIMARY_GROUP}" "${DEVBOX_USER}"; \
      else \
        useradd -m -s /bin/bash -u "${DEVBOX_UID}" -g "${PRIMARY_GROUP}" "${DEVBOX_USER}"; \
      fi; \
    fi; \
    echo "${DEVBOX_USER}:${DEVBOX_PASS}" | chpasswd; \
    usermod -aG sudo "${DEVBOX_USER}"; \
    if ! getent group "${DOCKER_GID}" >/dev/null 2>&1; then groupadd -g "${DOCKER_GID}" dockerhost; fi; \
    DOCKER_GROUP="$(getent group "${DOCKER_GID}" | cut -d: -f1)"; \
    usermod -aG "${DOCKER_GROUP}" "${DEVBOX_USER}"

# SSH configuration
RUN sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

ENV LANG=C.UTF-8

# Playwright CDP helper — start Chrome + port forwarder inside devbox-playwright
COPY scripts/start-cdp.sh /usr/local/bin/start-cdp.sh
RUN chmod +x /usr/local/bin/start-cdp.sh

# Start in projects directory on login
RUN echo "cd /workspace" >> "/home/${DEVBOX_USER}/.bashrc"

WORKDIR /workspace

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
