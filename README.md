# NAS DevBox

Run a full Linux development environment on your NAS without modifying the
NAS OS. You work in a container, while Docker and storage stay on the host.
This repo provides the container setup and a helper script.

SSH into an Ubuntu dev container on a NAS and manage host Docker from inside
the container.

## Architecture

```
Your PC ── SSH ──► Dev Container (Ubuntu)
                       │
                       ▼
                 Docker Engine (NAS)
                       │
                       ▼
                 Project Containers
```

The NAS runs Docker. The dev container provides the full Linux toolchain.
Projects live on the NAS and are mounted into the container at `/workspace`,
while the Docker socket lets you manage host containers as if you were logged
in directly.

## Requirements

- NAS with Docker installed
- SSH access to the NAS
- Projects directory on the NAS (choose any path; example: `/volume1/projects`)

## Quick Start

1. Choose or create a projects directory on the NAS host. This is where your
   code will live. Example:

```sh
mkdir -p /volume1/projects
```

2. Clone this repo anywhere on the NAS (it only stores the container files),
   then start the container. Use an SSH port that is not `22` (the host SSH
   service usually uses `22`). Pick the container username you want, and pass
   the projects directory path so it gets mounted into `/workspace`.

```sh
mkdir -p /volume1/home/devbox
cd /volume1/home/devbox
git clone https://github.com/loglux/NAS-DevBox.git .
./devbox.sh --user dev --ssh-port 2222 --projects-dir /volume1/projects
```

Connect:

```sh
ssh dev@NAS_IP -p 2222
```

Default password is `changeme` unless you set `--pass`. Change it on first
login:

```sh
passwd
```

You can also change it from the NAS host without SSH:

```sh
docker exec -it devbox passwd dev
```

Work in `/workspace` inside the container. It maps to the projects directory
on the NAS host that you pass via `--projects-dir` (or `DEVBOX_PROJECTS_DIR`).

## Configuration

Defaults live in `devbox.sh`, or pass flags on the command line:

- `DEVBOX_USER`
- `DEVBOX_PASS`
- `DEVBOX_SSH_PORT`
- `DOCKER_GID`
- `DEVBOX_PROJECTS_DIR`
- `DEVBOX_CONTAINER_NAME`

Recreate:

```sh
./devbox.sh --recreate --user dev --pass 'StrongPass'
```

## Check Docker Access

```sh
docker ps
```

## Compose Version

This setup uses Docker Compose v2 (`docker compose`) via the
`docker-compose-plugin` package.

## Optional: Passwordless sudo

If you want `sudo` without a password inside the dev container:

```sh
sudo visudo
```

Add this line (replace `dev` with your user):

```conf
dev ALL=(ALL) NOPASSWD:ALL
```
