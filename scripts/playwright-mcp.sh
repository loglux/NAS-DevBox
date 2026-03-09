#!/bin/bash
# playwright-mcp.sh — Launch @playwright/mcp connected to devbox-playwright via CDP.
#
# Resolves the container IP dynamically so the config never needs updating
# after container recreates. Works from inside another container (e.g. devbox)
# where localhost port mappings are not reachable.
#
# Usage in MCP config (.mcp.json or plugin cache):
#   {
#     "playwright": {
#       "command": "/path/to/playwright-mcp.sh"
#     }
#   }
#
# Override container name via env:
#   DEVBOX_PLAYWRIGHT_CONTAINER_NAME=my-playwright ./playwright-mcp.sh

CONTAINER="${DEVBOX_PLAYWRIGHT_CONTAINER_NAME:-devbox-playwright}"
IP=$(docker inspect "$CONTAINER" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null)

if [ -z "$IP" ]; then
  echo "ERROR: cannot resolve IP for container '$CONTAINER'" >&2
  echo "Make sure the container is running: docker ps | grep $CONTAINER" >&2
  exit 1
fi

exec npx @playwright/mcp@latest --cdp-endpoint "http://$IP:9223"
