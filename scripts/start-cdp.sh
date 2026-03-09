#!/bin/bash
# start-cdp.sh — Start Chrome with CDP inside devbox-playwright container
#
# Usage (from host):
#   docker exec devbox-playwright /usr/local/bin/start-cdp.sh
#
# This script:
#   1. Kills any existing Chrome instance
#   2. Starts Chrome in headless mode with remote debugging on port 9222
#   3. Forwards port 9222 to 0.0.0.0:9223 via a Python TCP proxy
#      (Chrome ignores --remote-debugging-address=0.0.0.0 and binds to 127.0.0.1)
#
# After this script runs, the CDP endpoint is reachable from the host at:
#   http://<container_ip>:9223
#
# Get the container IP:
#   docker inspect devbox-playwright \
#     --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'

set -e

# Kill existing Chrome and forwarder
pkill -f google-chrome 2>/dev/null || true
pkill -f "cdp-forwarder" 2>/dev/null || true
sleep 1

# Start Chrome with remote debugging
google-chrome \
  --no-sandbox \
  --headless \
  --disable-gpu \
  --remote-debugging-port=9222 \
  about:blank &>/tmp/chrome-cdp.log &

# Wait for Chrome to start
sleep 2

if ! grep -q "DevTools listening" /tmp/chrome-cdp.log; then
  echo "ERROR: Chrome failed to start. Check /tmp/chrome-cdp.log" >&2
  cat /tmp/chrome-cdp.log >&2
  exit 1
fi

# Forward 127.0.0.1:9222 → 0.0.0.0:9223 via Python TCP proxy
python3 - <<'PYEOF' &>/tmp/cdp-forwarder.log &
# cdp-forwarder
import socket, threading

def forward(src, dst):
    while True:
        try:
            data = src.recv(4096)
            if not data:
                break
            dst.send(data)
        except Exception:
            break
    src.close()
    dst.close()

server = socket.socket()
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind(('0.0.0.0', 9223))
server.listen(10)
print('CDP forwarder listening on 0.0.0.0:9223', flush=True)

while True:
    client, _ = server.accept()
    remote = socket.socket()
    remote.connect(('127.0.0.1', 9222))
    threading.Thread(target=forward, args=(client, remote), daemon=True).start()
    threading.Thread(target=forward, args=(remote, client), daemon=True).start()
PYEOF

sleep 1
echo "CDP ready at http://$(hostname -I | awk '{print $1}'):9223"
echo "Verify: curl http://<container_ip>:9223/json/version"
