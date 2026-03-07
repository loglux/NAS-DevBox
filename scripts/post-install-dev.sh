#!/usr/bin/env bash
set -euo pipefail

# Optional personal/dev profile.
# Keep this script small and reproducible.

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
  jq \
  ripgrep \
  fd-find \
  tree \
  unzip

apt-get clean
rm -rf /var/lib/apt/lists/*

echo "post-install-dev: done"
