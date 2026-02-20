FROM ubuntu:24.04

# Install core packages + dev essentials
RUN apt update && \
    apt install -y \
        openssh-server \
        sudo \
        docker.io \
        locales \
        build-essential \
        docker-compose-plugin \
        git \
        curl \
        wget \
        nano \
        vim \
        htop \
        iputils-ping \
        net-tools \
        ca-certificates \
        bash-completion && \
    locale-gen C.UTF-8 && \
    mkdir /var/run/sshd && \
    apt clean

# Build-time configuration
ARG DEVBOX_USER=loglux
ARG DEVBOX_PASS=changeme
ARG DOCKER_GID=1000

# Create non-root user
RUN useradd -m -s /bin/bash "${DEVBOX_USER}" && \
    echo "${DEVBOX_USER}:${DEVBOX_PASS}" | chpasswd && \
    usermod -aG sudo "${DEVBOX_USER}" && \
    if ! getent group "${DOCKER_GID}" >/dev/null 2>&1; then groupadd -g "${DOCKER_GID}" dockerhost; fi && \
    DOCKER_GROUP="$(getent group "${DOCKER_GID}" | cut -d: -f1)" && \
    usermod -aG "${DOCKER_GROUP}" "${DEVBOX_USER}"

# SSH configuration
RUN sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

ENV LANG=C.UTF-8

# Start in projects directory on login
RUN echo "cd /workspace" >> "/home/${DEVBOX_USER}/.bashrc"

WORKDIR /workspace

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
