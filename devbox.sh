#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ./devbox.sh [options]

Options:
  --user NAME            Devbox username (default: loglux)
  --pass PASSWORD        Devbox user password (default: changeme)
  --ssh-port PORT        Host SSH port to expose (default: 2202)
  --docker-gid GID       GID of docker socket on NAS (default: 1000)
  --projects-dir PATH    Projects directory on NAS (default: /volume1/projects)
  --container NAME       Container name (default: devbox)
  --recreate             Remove existing container before rebuild
  -h, --help             Show this help

Examples:
  ./devbox.sh --user dev --ssh-port 2222
  ./devbox.sh --recreate --user dev --pass 'StrongPass'
USAGE
}

DEVBOX_USER="loglux"
DEVBOX_PASS="changeme"
DEVBOX_SSH_PORT="2202"
DOCKER_GID="1000"
DEVBOX_PROJECTS_DIR="/volume1/projects"
DEVBOX_CONTAINER_NAME="devbox"
RECREATE="no"

while [ $# -gt 0 ]; do
  case "$1" in
    --user) DEVBOX_USER="${2:-}"; shift 2 ;;
    --pass) DEVBOX_PASS="${2:-}"; shift 2 ;;
    --ssh-port) DEVBOX_SSH_PORT="${2:-}"; shift 2 ;;
    --docker-gid) DOCKER_GID="${2:-}"; shift 2 ;;
    --projects-dir) DEVBOX_PROJECTS_DIR="${2:-}"; shift 2 ;;
    --container) DEVBOX_CONTAINER_NAME="${2:-}"; shift 2 ;;
    --recreate) RECREATE="yes"; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
elif docker-compose version >/dev/null 2>&1; then
  COMPOSE=(docker-compose)
else
  echo "Error: docker compose or docker-compose is required on the NAS host." >&2
  exit 1
fi

export DEVBOX_USER DEVBOX_PASS DEVBOX_SSH_PORT DOCKER_GID DEVBOX_PROJECTS_DIR DEVBOX_CONTAINER_NAME

if [ "${RECREATE}" = "yes" ]; then
  "${COMPOSE[@]}" down --remove-orphans
fi

"${COMPOSE[@]}" up -d --build

# Ensure /workspace is writable for the dev user (bind-mount comes from host)
docker exec -u 0 "${DEVBOX_CONTAINER_NAME}" chown -R "${DEVBOX_USER}:${DEVBOX_USER}" /workspace
