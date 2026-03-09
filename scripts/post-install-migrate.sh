#!/usr/bin/env bash
set -euo pipefail

# Optional one-time migration helper.
# Runs only when explicitly requested: ./devbox.sh --post-install migrate
# No default source paths are hardcoded.
#
# Variables (set in /projects/devbox/.env or .env.local):
#   MIGRATE_CODEX_FROM        source directory containing .codex data
#   MIGRATE_CODEX_TO          target directory (default: /home/<user>/.codex)
#   MIGRATE_BASH_HISTORY_FROM source file for bash history (optional)
#   MIGRATE_BASH_HISTORY_TO   target file (default: /home/<user>/.bash_history)

load_env_file() {
  local file="$1"
  [ -f "$file" ] || return 0
  set -a
  # shellcheck disable=SC1090
  . "$file"
  set +a
}

load_env_file "/projects/devbox/.env"
load_env_file "/projects/devbox/.env.local"

TARGET_USER="${DEVBOX_USER:-}"
if [ -z "${TARGET_USER}" ] || [ ! -d "/home/${TARGET_USER}" ]; then
  TARGET_USER="$(find /home -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | head -n 1 || true)"
fi
if [ -z "${TARGET_USER}" ]; then
  echo "post-install-migrate: cannot resolve target user under /home" >&2
  exit 1
fi

TARGET_HOME="/home/${TARGET_USER}"
MIGRATE_CODEX_FROM="${MIGRATE_CODEX_FROM:-}"
MIGRATE_CODEX_TO="${MIGRATE_CODEX_TO:-${TARGET_HOME}/.codex}"
MIGRATE_BASH_HISTORY_FROM="${MIGRATE_BASH_HISTORY_FROM:-}"
MIGRATE_BASH_HISTORY_TO="${MIGRATE_BASH_HISTORY_TO:-${TARGET_HOME}/.bash_history}"

migrated_any="no"

if [ -n "${MIGRATE_CODEX_FROM}" ]; then
  if [ -d "${MIGRATE_CODEX_FROM}" ]; then
    if [ ! -e "${MIGRATE_CODEX_TO}" ]; then
      echo "Migrating Codex data: ${MIGRATE_CODEX_FROM} -> ${MIGRATE_CODEX_TO}"
      mkdir -p "$(dirname "${MIGRATE_CODEX_TO}")"
      cp -a "${MIGRATE_CODEX_FROM}" "${MIGRATE_CODEX_TO}"
      chown -R "${TARGET_USER}:${TARGET_USER}" "${MIGRATE_CODEX_TO}" || true
      migrated_any="yes"
    else
      echo "Skipping Codex migration: target exists (${MIGRATE_CODEX_TO})"
    fi
  else
    echo "Skipping Codex migration: source not found (${MIGRATE_CODEX_FROM})"
  fi
else
  echo "Skipping Codex migration: MIGRATE_CODEX_FROM is not set"
fi

if [ -n "${MIGRATE_BASH_HISTORY_FROM}" ]; then
  if [ -f "${MIGRATE_BASH_HISTORY_FROM}" ]; then
    if [ ! -e "${MIGRATE_BASH_HISTORY_TO}" ]; then
      echo "Migrating bash history: ${MIGRATE_BASH_HISTORY_FROM} -> ${MIGRATE_BASH_HISTORY_TO}"
      mkdir -p "$(dirname "${MIGRATE_BASH_HISTORY_TO}")"
      cp -a "${MIGRATE_BASH_HISTORY_FROM}" "${MIGRATE_BASH_HISTORY_TO}"
      chown "${TARGET_USER}:${TARGET_USER}" "${MIGRATE_BASH_HISTORY_TO}" || true
      migrated_any="yes"
    else
      echo "Skipping bash history migration: target exists (${MIGRATE_BASH_HISTORY_TO})"
    fi
  else
    echo "Skipping bash history migration: source not found (${MIGRATE_BASH_HISTORY_FROM})"
  fi
else
  echo "Skipping bash history migration: MIGRATE_BASH_HISTORY_FROM is not set"
fi

echo "post-install-migrate: done (migrated_any=${migrated_any})"
