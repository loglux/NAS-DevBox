#!/usr/bin/env bash
set -euo pipefail

# Example optional post-install script for DevBox.
# Run inside container as root via: ./devbox.sh --post-install example
# Edit this file (or copy it) to install your own extra tooling.

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
  jq \
  ripgrep \
  fd-find

apt-get clean
rm -rf /var/lib/apt/lists/*

echo "post-install-example: done"
