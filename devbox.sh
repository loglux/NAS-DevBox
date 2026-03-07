#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ./devbox.sh [options]

Options:
  --user NAME                     Devbox username (default: dev)
  --pass PASSWORD                 Devbox user password (default: changeme)
  --uid UID                       UID for container user (default: current host UID; empty in .env auto-detects)
  --gid GID                       GID for container user (default: current host GID; empty in .env auto-detects)
  --ssh-port PORT                 Host SSH port for main devbox (default: 2202)
  --docker-gid GID                GID of docker socket on NAS (default: 1000)
  --projects-dir PATH             Projects directory on NAS (default: /volume1/projects)
  --workspace-link MODE           /workspace compatibility link: on|off (default: on)
  --start-dir PATH                Auto-cd target on shell login (default: /workspace)
  --passwordless-sudo MODE        Passwordless sudo: on|off (default: on)
  --container NAME                Main container name (default: devbox)
  --home-dir PATH                 Persistent home dir on host (default: auto; /volume1/home/<user> if exists)
  --playwright                    Also start playwright profile container
  --playwright-ssh-port PORT      SSH port for playwright container (default: 2203)
  --playwright-container NAME     Playwright container name (default: devbox-playwright)
  --post-install TARGET           Optional post-install script/profile: example | dev | ai | /projects/path/script.sh
  --env-file PATH                 Optional env file (default auto-load: ./.env, then ./.env.local)
  --recreate                      Remove existing containers before rebuild
  -h, --help                      Show this help

Examples:
  ./devbox.sh --user dev --ssh-port 2202
  ./devbox.sh --playwright --post-install example --user devuser --uid 1000 --gid 1000
USAGE
}

DEVBOX_USER="dev"
DEVBOX_PASS="changeme"
DEVBOX_UID="$(id -u)"
DEVBOX_GID="$(id -g)"
DEVBOX_SSH_PORT="2202"
DOCKER_GID="1000"
DEVBOX_PROJECTS_DIR="/volume1/projects"
DEVBOX_PROJECTS_MOUNT="/projects"
DEVBOX_WORKSPACE_LINK="on"
DEVBOX_START_DIR="/workspace"
DEVBOX_PASSWORDLESS_SUDO="on"
DEVBOX_CONTAINER_NAME="devbox"
DEVBOX_HOME_DIR=""
DEVBOX_PLAYWRIGHT_ENABLED="no"
DEVBOX_PLAYWRIGHT_SSH_PORT="2203"
DEVBOX_PLAYWRIGHT_CONTAINER_NAME="devbox-playwright"
POST_INSTALL_TARGET=""
DEVBOX_ENV_FILE=""
RECREATE="no"

load_env_file() {
  local file="$1"
  [ -z "$file" ] && return 0
  [ -f "$file" ] || return 0
  set -a
  # shellcheck disable=SC1090
  . "$file"
  set +a
}

# Auto-load local environment values if present.
# CLI flags still override these defaults later.
# Load order: .env then .env.local (override).
[ -f "./.env" ] && load_env_file "./.env"
[ -f "./.env.local" ] && load_env_file "./.env.local"

# Pre-parse optional env file so explicit CLI flags can still override it.
ARGS=("$@")
for ((i=0; i<${#ARGS[@]}; i++)); do
  if [ "${ARGS[$i]}" = "--env-file" ] && [ $((i + 1)) -lt ${#ARGS[@]} ]; then
    DEVBOX_ENV_FILE="${ARGS[$((i + 1))]}"
    break
  fi
done
[ -n "$DEVBOX_ENV_FILE" ] && load_env_file "$DEVBOX_ENV_FILE"

while [ $# -gt 0 ]; do
  case "$1" in
    --user) DEVBOX_USER="${2:-}"; shift 2 ;;
    --pass) DEVBOX_PASS="${2:-}"; shift 2 ;;
    --uid) DEVBOX_UID="${2:-}"; shift 2 ;;
    --gid) DEVBOX_GID="${2:-}"; shift 2 ;;
    --ssh-port) DEVBOX_SSH_PORT="${2:-}"; shift 2 ;;
    --docker-gid) DOCKER_GID="${2:-}"; shift 2 ;;
    --projects-dir) DEVBOX_PROJECTS_DIR="${2:-}"; shift 2 ;;
    --workspace-link) DEVBOX_WORKSPACE_LINK="${2:-}"; shift 2 ;;
    --start-dir) DEVBOX_START_DIR="${2:-}"; shift 2 ;;
    --passwordless-sudo) DEVBOX_PASSWORDLESS_SUDO="${2:-}"; shift 2 ;;
    --container) DEVBOX_CONTAINER_NAME="${2:-}"; shift 2 ;;
    --home-dir) DEVBOX_HOME_DIR="${2:-}"; shift 2 ;;
    --playwright) DEVBOX_PLAYWRIGHT_ENABLED="yes"; shift ;;
    --playwright-ssh-port) DEVBOX_PLAYWRIGHT_SSH_PORT="${2:-}"; shift 2 ;;
    --playwright-container) DEVBOX_PLAYWRIGHT_CONTAINER_NAME="${2:-}"; shift 2 ;;
    --post-install) POST_INSTALL_TARGET="${2:-}"; shift 2 ;;
    --env-file) DEVBOX_ENV_FILE="${2:-}"; shift 2 ;; # already loaded in pre-parse
    --recreate) RECREATE="yes"; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ "${DEVBOX_WORKSPACE_LINK}" != "on" ] && [ "${DEVBOX_WORKSPACE_LINK}" != "off" ]; then
  echo "Error: --workspace-link must be 'on' or 'off'." >&2
  exit 1
fi
if [ "${DEVBOX_PASSWORDLESS_SUDO}" != "on" ] && [ "${DEVBOX_PASSWORDLESS_SUDO}" != "off" ]; then
  echo "Error: --passwordless-sudo must be 'on' or 'off'." >&2
  exit 1
fi
# Keep .env portable across hosts: blank UID/GID means "use current host user/group".
if [ -z "${DEVBOX_UID}" ]; then
  DEVBOX_UID="$(id -u)"
fi
if [ -z "${DEVBOX_GID}" ]; then
  DEVBOX_GID="$(id -g)"
fi

# Resolve host directory for persistent user settings.
# Priority:
# 1) explicit DEVBOX_HOME_DIR / --home-dir
# 2) /volume1/home/<user> when present
# 3) /home/<user> when present
# 4) fallback isolated path under projects
if [ -z "${DEVBOX_HOME_DIR}" ]; then
  if [ -d "/volume1/home/${DEVBOX_USER}" ]; then
    DEVBOX_HOME_DIR="/volume1/home/${DEVBOX_USER}"
  elif [ -d "/home/${DEVBOX_USER}" ]; then
    DEVBOX_HOME_DIR="/home/${DEVBOX_USER}"
  else
    DEVBOX_HOME_DIR="/volume1/projects/.devbox-home/${DEVBOX_USER}"
  fi
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
elif docker-compose version >/dev/null 2>&1; then
  COMPOSE=(docker-compose)
else
  echo "Error: docker compose or docker-compose is required on the NAS host." >&2
  exit 1
fi

resolve_post_install_script() {
  local target="$1"
  if [ -z "$target" ]; then
    echo ""
    return 0
  fi
  case "$target" in
    example) echo "${DEVBOX_PROJECTS_MOUNT}/devbox/scripts/post-install-example.sh" ;;
    dev) echo "${DEVBOX_PROJECTS_MOUNT}/devbox/scripts/post-install-dev.sh" ;;
    ai) echo "${DEVBOX_PROJECTS_MOUNT}/devbox/scripts/post-install-ai.sh" ;;
    *)
      if [[ "$target" = /* ]]; then
        echo "$target"
      else
        echo "${DEVBOX_PROJECTS_MOUNT}/$target"
      fi
      ;;
  esac
}

run_post_install() {
  local container="$1"
  local script_path="$2"
  [ -z "$script_path" ] && return 0

  docker exec -u 0 "$container" sh -lc "test -f '$script_path'" \
    || { echo "Post-install script not found in container: $script_path" >&2; return 1; }

  echo "Running post-install in $container: $script_path"
  docker exec -u 0 "$container" sh -lc "bash '$script_path'"
}

configure_container_runtime() {
  local container="$1"
  docker exec -u 0 "$container" sh -lc \
    "set -e; \
     mkdir -p '/home/${DEVBOX_USER}'; \
     ln -sfn '${DEVBOX_PROJECTS_MOUNT}' '/home/${DEVBOX_USER}/projects'; \
     if [ '${DEVBOX_WORKSPACE_LINK}' = 'on' ]; then [ -e /workspace ] && [ ! -L /workspace ] && rm -rf /workspace || true; ln -sfn '/home/${DEVBOX_USER}/projects' /workspace; else [ -L /workspace ] && rm -f /workspace || true; fi; \
     PROFILE='/home/${DEVBOX_USER}/.bashrc'; \
     touch \"\$PROFILE\"; \
     sed -i '/### DEVBOX AUTO-CD ###/,/### \\/DEVBOX AUTO-CD ###/d' \"\$PROFILE\"; \
     cat >> \"\$PROFILE\" <<EOF
### DEVBOX AUTO-CD ###
if [ -n \"\\\$PS1\" ]; then
  if [ -d \"${DEVBOX_START_DIR}\" ]; then
    cd \"${DEVBOX_START_DIR}\"
  elif [ -d \"/workspace\" ]; then
    cd \"/workspace\"
  fi
fi
### /DEVBOX AUTO-CD ###
EOF
     LOGIN_PROFILE='/home/${DEVBOX_USER}/.profile'; \
     touch \"\$LOGIN_PROFILE\"; \
     sed -i '/### DEVBOX SOURCE BASHRC ###/,/### \\/DEVBOX SOURCE BASHRC ###/d' \"\$LOGIN_PROFILE\"; \
     cat >> \"\$LOGIN_PROFILE\" <<'EOF'
### DEVBOX SOURCE BASHRC ###
if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi
### /DEVBOX SOURCE BASHRC ###
EOF
     if [ '${DEVBOX_PASSWORDLESS_SUDO}' = 'on' ]; then echo '${DEVBOX_USER} ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/90-devbox-nopasswd; chmod 0440 /etc/sudoers.d/90-devbox-nopasswd; else rm -f /etc/sudoers.d/90-devbox-nopasswd; fi"
}

export DEVBOX_USER DEVBOX_PASS DEVBOX_UID DEVBOX_GID DEVBOX_SSH_PORT DOCKER_GID
export DEVBOX_PROJECTS_DIR DEVBOX_PROJECTS_MOUNT DEVBOX_WORKSPACE_LINK DEVBOX_START_DIR DEVBOX_PASSWORDLESS_SUDO DEVBOX_CONTAINER_NAME DEVBOX_HOME_DIR
export DEVBOX_PLAYWRIGHT_SSH_PORT DEVBOX_PLAYWRIGHT_CONTAINER_NAME

POST_INSTALL_SCRIPT="$(resolve_post_install_script "$POST_INSTALL_TARGET")"

mkdir -p "${DEVBOX_PROJECTS_DIR}"
mkdir -p "${DEVBOX_HOME_DIR}" "${DEVBOX_HOME_DIR}/.ssh"
chmod 700 "${DEVBOX_HOME_DIR}/.ssh" || true

# One-time migration: recover legacy Codex settings stored under projects/codex/.codex.
LEGACY_CODEX_DIR="${DEVBOX_PROJECTS_DIR}/codex/.codex"
TARGET_CODEX_DIR="${DEVBOX_HOME_DIR}/.codex"
if [ ! -e "${TARGET_CODEX_DIR}" ] && [ -d "${LEGACY_CODEX_DIR}" ]; then
  echo "Migrating legacy Codex settings: ${LEGACY_CODEX_DIR} -> ${TARGET_CODEX_DIR}"
  cp -a "${LEGACY_CODEX_DIR}" "${TARGET_CODEX_DIR}"
fi

# One-time migration: populate SSH settings in mounted home when empty.
TARGET_SSH_DIR="${DEVBOX_HOME_DIR}/.ssh"
HOST_USER_NAME="$(id -un)"
HOST_SSH_CANDIDATE_A="/volume1/home/${HOST_USER_NAME}/.ssh"
HOST_SSH_CANDIDATE_B="${HOME}/.ssh"
if [ -z "$(find "${TARGET_SSH_DIR}" -mindepth 1 -maxdepth 1 2>/dev/null | head -n 1)" ]; then
  if [ -d "${HOST_SSH_CANDIDATE_A}" ] && [ "${HOST_SSH_CANDIDATE_A}" != "${TARGET_SSH_DIR}" ]; then
    echo "Migrating SSH settings: ${HOST_SSH_CANDIDATE_A} -> ${TARGET_SSH_DIR}"
    cp -a "${HOST_SSH_CANDIDATE_A}/." "${TARGET_SSH_DIR}/"
  elif [ -d "${HOST_SSH_CANDIDATE_B}" ] && [ "${HOST_SSH_CANDIDATE_B}" != "${TARGET_SSH_DIR}" ]; then
    echo "Migrating SSH settings: ${HOST_SSH_CANDIDATE_B} -> ${TARGET_SSH_DIR}"
    cp -a "${HOST_SSH_CANDIDATE_B}/." "${TARGET_SSH_DIR}/"
  fi
fi

if [ "${RECREATE}" = "yes" ]; then
  if [ "${DEVBOX_PLAYWRIGHT_ENABLED}" = "yes" ]; then
    "${COMPOSE[@]}" --profile playwright down --remove-orphans
  else
    "${COMPOSE[@]}" down --remove-orphans
  fi

  # Compose down can miss stale containers if project metadata changed.
  docker rm -f "${DEVBOX_CONTAINER_NAME}" >/dev/null 2>&1 || true
  if [ "${DEVBOX_PLAYWRIGHT_ENABLED}" = "yes" ]; then
    docker rm -f "${DEVBOX_PLAYWRIGHT_CONTAINER_NAME}" >/dev/null 2>&1 || true
  fi
fi

if [ "${DEVBOX_PLAYWRIGHT_ENABLED}" = "yes" ]; then
  "${COMPOSE[@]}" --profile playwright up -d --build
else
  "${COMPOSE[@]}" up -d --build
fi

configure_container_runtime "${DEVBOX_CONTAINER_NAME}"

if [ "${DEVBOX_PLAYWRIGHT_ENABLED}" = "yes" ]; then
  configure_container_runtime "${DEVBOX_PLAYWRIGHT_CONTAINER_NAME}"
fi

# Ensure mounted dirs are writable for the selected user
docker exec -u 0 "${DEVBOX_CONTAINER_NAME}" sh -lc \
  "chown -R '${DEVBOX_USER}' '${DEVBOX_PROJECTS_MOUNT}' '/home/${DEVBOX_USER}' || true"

if [ "${DEVBOX_PLAYWRIGHT_ENABLED}" = "yes" ]; then
  docker exec -u 0 "${DEVBOX_PLAYWRIGHT_CONTAINER_NAME}" sh -lc \
    "chown -R '${DEVBOX_USER}' '${DEVBOX_PROJECTS_MOUNT}' '/home/${DEVBOX_USER}' || true"
fi

if [ -n "$POST_INSTALL_SCRIPT" ]; then
  run_post_install "${DEVBOX_CONTAINER_NAME}" "$POST_INSTALL_SCRIPT"
  if [ "${DEVBOX_PLAYWRIGHT_ENABLED}" = "yes" ]; then
    run_post_install "${DEVBOX_PLAYWRIGHT_CONTAINER_NAME}" "$POST_INSTALL_SCRIPT"
  fi
fi

echo
echo "Container is ready."
echo "+------------------------------------------------------------+"
echo "| User: ${DEVBOX_USER} (UID:${DEVBOX_UID} GID:${DEVBOX_GID})"
echo "| Main SSH: ${DEVBOX_SSH_PORT}"
echo "| Projects mount: ${DEVBOX_PROJECTS_DIR} -> ${DEVBOX_PROJECTS_MOUNT}"
echo "| Home mount: ${DEVBOX_HOME_DIR} -> /home/${DEVBOX_USER}"
echo "| /workspace link: ${DEVBOX_WORKSPACE_LINK}"
echo "| Login start dir: ${DEVBOX_START_DIR}"
echo "| Passwordless sudo: ${DEVBOX_PASSWORDLESS_SUDO}"
if [ "${DEVBOX_PLAYWRIGHT_ENABLED}" = "yes" ]; then
  echo "| Playwright SSH: ${DEVBOX_PLAYWRIGHT_SSH_PORT}"
fi
if [ -n "$POST_INSTALL_SCRIPT" ]; then
  echo "| Post-install: ${POST_INSTALL_SCRIPT}"
fi
if [ "${DEVBOX_PASS}" = "changeme" ]; then
  echo "| Password: changeme (default)."
else
  echo "| Password: value from --pass/.env (custom)."
fi
echo "| Please change the password after first login."
echo "+------------------------------------------------------------+"
