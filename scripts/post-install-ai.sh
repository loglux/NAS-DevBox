#!/usr/bin/env bash
set -euo pipefail

# Optional AI tooling profile for DevBox.
# Installs Node.js + npm and global CLIs for Codex and Claude Code.

export DEBIAN_FRONTEND=noninteractive

resolve_target_user() {
  if [ -n "${DEVBOX_USER:-}" ] && id -u "${DEVBOX_USER}" >/dev/null 2>&1; then
    echo "${DEVBOX_USER}"
    return 0
  fi

  if getent passwd 1000 >/dev/null 2>&1; then
    getent passwd 1000 | cut -d: -f1
    return 0
  fi

  if [ -d /home ]; then
    set -- /home/*
    if [ "$#" -eq 1 ] && [ -d "$1" ]; then
      basename "$1"
      return 0
    fi
  fi

  echo "post-install-ai: cannot resolve target user" >&2
  exit 1
}

TARGET_USER="$(resolve_target_user)"
TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
TARGET_GROUP="$(id -gn "${TARGET_USER}")"
NPM_PREFIX="${TARGET_HOME}/.npm-global"

# Install Node.js 20.x from NodeSource (stable npm for global CLI tooling)
# curl, ca-certificates, gnupg are guaranteed by the base Dockerfile
if ! command -v node >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
  chmod a+r /etc/apt/keyrings/nodesource.gpg
  . /etc/os-release
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" \
    > /etc/apt/sources.list.d/nodesource.list
  apt-get update
  apt-get install -y --no-install-recommends nodejs
fi

install -d -o "${TARGET_USER}" -g "${TARGET_GROUP}" "${NPM_PREFIX}"

NPMRC="${TARGET_HOME}/.npmrc"
touch "${NPMRC}"
chown "${TARGET_USER}:${TARGET_GROUP}" "${NPMRC}"
if grep -q '^prefix=' "${NPMRC}"; then
  sed -i "s#^prefix=.*#prefix=${NPM_PREFIX}#" "${NPMRC}"
else
  printf 'prefix=%s\n' "${NPM_PREFIX}" >> "${NPMRC}"
fi

PROFILE="${TARGET_HOME}/.bashrc"
touch "${PROFILE}"
chown "${TARGET_USER}:${TARGET_GROUP}" "${PROFILE}"
sed -i '/### DEVBOX NPM PREFIX ###/,/### \/DEVBOX NPM PREFIX ###/d' "${PROFILE}"
cat >> "${PROFILE}" <<EOF
### DEVBOX NPM PREFIX ###
export PATH="${NPM_PREFIX}/bin:\$PATH"
### /DEVBOX NPM PREFIX ###
EOF

LOGIN_PROFILE="${TARGET_HOME}/.profile"
touch "${LOGIN_PROFILE}"
chown "${TARGET_USER}:${TARGET_GROUP}" "${LOGIN_PROFILE}"
sed -i '/### DEVBOX NPM PREFIX ###/,/### \/DEVBOX NPM PREFIX ###/d' "${LOGIN_PROFILE}"
cat >> "${LOGIN_PROFILE}" <<'EOF'
### DEVBOX NPM PREFIX ###
if [ -d "$HOME/.npm-global/bin" ]; then
  PATH="$HOME/.npm-global/bin:$PATH"
fi
### /DEVBOX NPM PREFIX ###
EOF

su - "${TARGET_USER}" -c "npm install -g @openai/codex"

# Install Claude Code via native installer (no Node.js required)
su - "${TARGET_USER}" -c "curl -fsSL https://claude.ai/install.sh | bash"

apt-get clean
rm -rf /var/lib/apt/lists/*

echo "post-install-ai: done"
node --version
npm --version
su - "${TARGET_USER}" -c 'codex --version || true'
su - "${TARGET_USER}" -c 'claude --version || true'
