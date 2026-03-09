# Playwright CDP Setup with devbox-playwright

The `devbox-playwright` container runs Chrome with relaxed sandbox permissions
required for headless browser automation. This document explains how to expose
Chrome's CDP (Chrome DevTools Protocol) endpoint and connect to it from various
tools — Playwright scripts, MCP clients, and AI coding assistants.

---

## How It Works

```
Your tool (script / MCP client / AI assistant)
      │
      │  CDP over HTTP/WebSocket
      ▼
localhost:9223         ← host port mapped from container (docker-compose ports)
      │
      ▼
0.0.0.0:9223          ← Python TCP proxy inside devbox-playwright
      │
      ▼
127.0.0.1:9222        ← Chrome DevTools Protocol
                        (Chrome ignores --remote-debugging-address and always
                         binds to 127.0.0.1; the proxy makes it reachable from outside)
      │
      ▼
Chrome (headless, --no-sandbox, inside devbox-playwright)
```

---

## One-Time Setup

### 1. Start devbox-playwright

```bash
./devbox.sh --playwright
```

### 2. start-cdp.sh is baked into the image

`start-cdp.sh` is copied into the image at build time (`/usr/local/bin/start-cdp.sh`).
No manual installation needed — it is available in every container built from this Dockerfile.

### 3. Get the container IP

```bash
docker inspect devbox-playwright \
  --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
# e.g. 172.30.0.2
```

> The IP is assigned by Docker and may change after container recreate.
> To fix it, set a static address in `docker-compose.yml`:
> ```yaml
> networks:
>   default:
>     ipv4_address: 172.30.0.2
> ```

---

## Before Each Session

Start Chrome and the port forwarder inside the container:

```bash
PLAYWRIGHT=$(docker ps --filter name=playwright --format '{{.Names}}' | head -1)
docker exec "$PLAYWRIGHT" start-cdp.sh
```

Or if using the default container name:

```bash
docker exec devbox-playwright start-cdp.sh
```

Verify:

```bash
curl http://localhost:9223/json/version
```

---

## Connecting

### Playwright script (Node.js)

```js
import { chromium } from 'playwright'

const browser = await chromium.connectOverCDP('http://localhost:9223')
const page = await browser.newPage()
await page.goto('http://your-app')
```

### Playwright script (Python)

```python
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.connect_over_cdp('http://localhost:9223')
    page = browser.new_page()
    page.goto('http://your-app')
```

### playwright.config.js (for `npm run test:e2e`)

```js
export default defineConfig({
  use: {
    connectOptions: { wsEndpoint: 'http://localhost:9223' },
  },
})
```

### MCP client (any tool that supports @playwright/mcp)

If your MCP client runs **directly on the NAS host**, use `localhost`:

```json
{
  "playwright": {
    "command": "npx",
    "args": ["@playwright/mcp@latest", "--cdp-endpoint", "http://localhost:9223"]
  }
}
```

If your MCP client runs **inside the devbox container**, `localhost:9223` is not
reachable — the port mapping only works at the NAS host level. Use the wrapper
script `scripts/playwright-mcp.sh` which resolves the container IP automatically:

```json
{
  "playwright": {
    "command": "/usr/local/bin/playwright-mcp.sh"
  }
}
```

`playwright-mcp.sh` is baked into the devbox image at build time — available at
`/usr/local/bin/playwright-mcp.sh` regardless of where the repo was cloned.
It uses `docker inspect` to find the current IP of `devbox-playwright` at startup —
no hardcoded IPs, works after container recreates.

Override the container name if needed:

```bash
DEVBOX_PLAYWRIGHT_CONTAINER_NAME=my-playwright npx ...
```

#### Claude Code (specific case)

Claude Code loads MCP config from these locations (lowest → highest priority):

| Level | File | Scope |
|---|---|---|
| Plugin cache | `~/.claude/plugins/cache/claude-plugins-official/playwright/<hash>/.mcp.json` | All projects (overwritten on plugin update) |
| User | `~/.claude/mcp.json` | All projects |
| Project | `.mcp.json` in project root | This project only |

Since Claude Code runs inside `devbox`, use `playwright-mcp.sh` as the command.
Restart Claude Code after editing the config.

---

## Troubleshooting

**Connection refused on port 9223**

Chrome binds to `127.0.0.1` regardless of `--remote-debugging-address`.
The `start-cdp.sh` script handles the forwarding. Check the logs:

```bash
docker exec devbox-playwright start-cdp.sh
# check logs if it fails:
docker exec devbox-playwright cat /tmp/chrome-cdp.log
docker exec devbox-playwright cat /tmp/cdp-forwarder.log
```

**Chrome not found**

Container was started without `--playwright`. Recreate:

```bash
./devbox.sh --recreate --playwright
```

**IP changed after recreate**

Re-run step 3 and update your config.
