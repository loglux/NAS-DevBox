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
<container_ip>:9223   ← Python TCP proxy inside devbox-playwright
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

### 2. Install start-cdp.sh into the container

```bash
docker cp scripts/start-cdp.sh devbox-playwright:/usr/local/bin/start-cdp.sh
docker exec devbox-playwright chmod +x /usr/local/bin/start-cdp.sh
```

Repeat after `--recreate`.

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
docker exec devbox-playwright /usr/local/bin/start-cdp.sh
```

Verify:

```bash
curl http://172.30.0.2:9223/json/version
```

---

## Connecting

### Playwright script (Node.js)

```js
import { chromium } from 'playwright'

const browser = await chromium.connectOverCDP('http://172.30.0.2:9223')
const page = await browser.newPage()
await page.goto('http://your-app')
```

### Playwright script (Python)

```python
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.connect_over_cdp('http://172.30.0.2:9223')
    page = browser.new_page()
    page.goto('http://your-app')
```

### playwright.config.js (for `npm run test:e2e`)

```js
export default defineConfig({
  use: {
    connectOptions: { wsEndpoint: 'http://172.30.0.2:9223' },
  },
})
```

### MCP client (any tool that supports @playwright/mcp)

```bash
npx @playwright/mcp@latest --cdp-endpoint http://172.30.0.2:9223
```

Or in an `.mcp.json` / MCP server config:

```json
{
  "playwright": {
    "command": "npx",
    "args": ["@playwright/mcp@latest", "--cdp-endpoint", "http://172.30.0.2:9223"]
  }
}
```

#### Claude Code (specific case)

Claude Code loads MCP config from these locations (lowest → highest priority):

| Level | File | Scope |
|---|---|---|
| Plugin cache | `~/.claude/plugins/cache/claude-plugins-official/playwright/<hash>/.mcp.json` | All projects (overwritten on plugin update) |
| User | `~/.claude/mcp.json` | All projects |
| Project | `.mcp.json` in project root | This project only |

Edit whichever level suits your workflow — the config format is the same as above.
Restart Claude Code after editing.

---

## Troubleshooting

**Connection refused on port 9223**

Chrome binds to `127.0.0.1` regardless of `--remote-debugging-address`.
The `start-cdp.sh` script handles the forwarding. Check the logs:

```bash
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
