#!/usr/bin/env bash
set -euo pipefail

# Optional AI tooling profile for DevBox.
# Installs Node.js + npm and global CLIs for Codex and Claude Code.

export DEBIAN_FRONTEND=noninteractive

# Install Node.js 20.x from NodeSource (stable npm for global CLI tooling)
if ! command -v node >/dev/null 2>&1; then
  apt-get update
  apt-get install -y --no-install-recommends ca-certificates curl gnupg
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

npm install -g @openai/codex @anthropic-ai/claude-code

apt-get clean
rm -rf /var/lib/apt/lists/*

echo "post-install-ai: done"
node --version
npm --version
codex --version || true
claude --version || true
