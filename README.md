# NAS DevBox — Development Box

Run a full Linux development environment on your NAS — safely inside a container — without modifying the NAS operating system.

NAS DevBox turns your NAS into a remote Linux workstation while keeping Docker and storage on the host.

## 📌 Origin

This project started from the architecture described in this article:
- https://www.linkedin.com/pulse/turning-nas-full-linux-development-environment-docker-sorokin-6o9oe/

---

## ✨ Key Features

- Full Ubuntu environment accessible via SSH
- No changes to the NAS OS
- Projects stored directly on NAS storage
- Manage host Docker from inside the dev container
- Isolated, disposable development environment

Ideal for homelabs, self-hosted setups, and lightweight remote development.

---

## 🧱 Architecture

```
Your PC ── SSH ──► Dev Container (Ubuntu)
                       │
                       ▼
                 Docker Engine (NAS)
                       │
                       ▼
                 Project Containers
```

**How it works**

- The NAS runs Docker normally
- DevBox runs an Ubuntu container with development tools
- Your projects live on the NAS and are mounted into `/projects`
- `/home/<user>/projects` is a symlink to `/projects`
- `/workspace` can be enabled as a compatibility symlink
- The container controls host Docker via the Docker socket

No changes to the NAS firmware or OS are required.

---

## ✅ Requirements

- NAS with Docker installed
- SSH access to the NAS
- A directory for projects on the NAS (e.g. `/volume1/projects`)

---

## 🚀 Quick Start

### 1. Create A Projects Directory On The NAS

```bash
mkdir -p /volume1/projects
```

---

### 2. Clone The Repository

```bash
mkdir -p /volume1/projects/devbox
cd /volume1/projects/devbox
git clone https://github.com/loglux/NAS-DevBox.git .
```

---

### 3. Configure `.env` (Recommended)

Use `.env` as the primary configuration source so recreate/start commands stay short and consistent.

```bash
cp .env.example .env
# edit .env and set at least:
# DEVBOX_USER, DEVBOX_PASS, DEVBOX_SSH_PORT, DEVBOX_PROJECTS_DIR
# optionally: DEVBOX_HOME_DIR, DEVBOX_START_DIR, DEVBOX_PASSWORDLESS_SUDO
```

Minimal example:

```env
DEVBOX_USER=loglux
DEVBOX_PASS=your-strong-password
DEVBOX_SSH_PORT=2202
DEVBOX_PROJECTS_DIR=/volume1/projects
```

`devbox.sh` loads config in this order:

1. script defaults
2. `./.env`
3. `./.env.local` (optional override)
4. `--env-file <path>` (if provided)
5. CLI flags (highest priority)

---

### 3.1 Configuration Reference (`.env` and CLI)

| Variable              | Description                                  | Default                          |
| --------------------- | -------------------------------------------- | -------------------------------- |
| DEVBOX_USER           | Container username                           | dev                              |
| DEVBOX_PASS           | User password                                | changeme                         |
| DEVBOX_SSH_PORT       | SSH port                                     | 2202                             |
| DOCKER_GID            | Docker group ID                              | 1000                             |
| DEVBOX_UID            | Container user UID                           | host `id -u` (auto if empty)     |
| DEVBOX_GID            | Container user GID                           | host `id -g` (auto if empty)     |
| DEVBOX_PROJECTS_DIR   | Projects path on NAS                         | /volume1/projects                |
| DEVBOX_WORKSPACE_LINK | Create `/workspace` compatibility symlink    | on                               |
| DEVBOX_START_DIR      | Auto-cd target on interactive login          | /workspace                       |
| DEVBOX_PASSWORDLESS_SUDO | Passwordless sudo mode                    | on                               |
| DEVBOX_HOME_DIR       | Persistent home dir on host                  | auto-resolved by `devbox.sh`     |
| DEVBOX_CONTAINER_NAME | Container name                               | devbox                           |

Flags override environment variables.
Note: auto-resolution for `DEVBOX_HOME_DIR` applies only when `DEVBOX_HOME_DIR` is empty/unset.

### 3.2 Path Model (Important)

- projects mount: `${DEVBOX_PROJECTS_DIR}` -> `/projects`
- settings/home mount: `${DEVBOX_HOME_DIR}` -> `/home/<user>`
- convenience symlink: `/home/<user>/projects` -> `/projects`
- optional compatibility symlink: `/workspace` -> `/home/<user>/projects` (only when `DEVBOX_WORKSPACE_LINK=on`)

### 4. Start The Development Container

Minimal start:

```bash
./devbox.sh
```

Full profile (main + playwright + AI tools):

```bash
./devbox.sh --playwright --post-install ai
```

One-time CLI override example (without editing `.env`):

```bash
./devbox.sh --user loglux --pass 'your-strong-password' --ssh-port 2202
```

What `devbox.sh` does:

- passes your parameters to Docker build/runtime
- builds or rebuilds the DevBox image
- starts the container in background mode
- mounts your NAS projects directory to `/projects`
- connects container to host Docker via `/var/run/docker.sock`
- if `--recreate` is used, removes old container before fresh start

---

### 5. Connect Via SSH

```bash
ssh <user>@NAS_IP -p <ssh_port>
```

Your projects are available inside the container at:

```
/projects
```

Convenience paths:

```
/home/<user>/projects
/workspace (optional, only when DEVBOX_WORKSPACE_LINK=on)
```

---

## 🔐 Default Credentials

- Username: value of `DEVBOX_USER` (or `--user`)
- Password: value of `DEVBOX_PASS` (or `--pass`)
- If you do not set them, defaults are `dev` / `changeme`

Recommended:
- set `DEVBOX_USER` and `DEVBOX_PASS` in `.env` before first start
- use `--user/--pass` only for temporary override

From the NAS host:

```bash
docker exec -it devbox passwd <user>
```

---

## 🛠️ Basic Usage

### Check Access To Host Docker

Inside the container:

```bash
docker ps
```

You should see containers running on the NAS host.

Expected DevBox container names by default:
- `devbox`
- `devbox-playwright` (only when started with `--playwright`)

You can customize names via:
- `DEVBOX_CONTAINER_NAME`
- `DEVBOX_PLAYWRIGHT_CONTAINER_NAME`

Quick host-side check:

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}' | grep -E 'devbox|devbox-playwright'
```

---

### Passwordless Sudo

Passwordless sudo is enabled by default (`DEVBOX_PASSWORDLESS_SUDO=on`).
To disable it, set `DEVBOX_PASSWORDLESS_SUDO=off` or use `--passwordless-sudo off`.

Why this is useful:
- install system packages without interactive password prompts (`sudo apt ...`)
- run setup/bootstrap scripts non-interactively
- simplify automation from CLI tools inside the container

---

## 🔄 Recreate The Container

Recreate removes the existing container and builds a fresh one.

Important:

- Recreate replaces containers and applies current config values
- Keep your preferred values in `.env` so you do not need to pass all flags each time
- The password resets to `changeme` only if neither `.env` nor CLI sets `DEVBOX_PASS`/`--pass`
- Existing project data is safe (stored on NAS)

### Recommended Recreate Command

```bash
./devbox.sh --recreate
```

Recommended recreate flow:

```bash
# main + playwright + AI tooling
./devbox.sh --recreate --playwright --post-install ai

# custom env file
./devbox.sh --recreate --env-file /path/to/my.env
```

---

## 🛡️ Security Notes

- The container has access to the host Docker socket
- Anyone with container access can control host containers
- Use strong passwords or SSH keys
- Consider restricting network exposure

---

## 🎯 When To Use NAS DevBox

This setup is useful if you want to:

- Develop directly on NAS storage
- Keep your NAS OS untouched
- Run disposable dev environments
- Use NAS as a remote build machine
- Manage Docker workloads remotely

---

## 💾 Persistence, Playwright, and Tooling

To avoid losing shell/Codex/SSH settings after recreate, mount one persistent home directory:

- `DEVBOX_HOME_DIR` -> `/home/<user>`

Default resolution in `devbox.sh`:

1. explicit `DEVBOX_HOME_DIR` / `--home-dir`
2. `/volume1/home/<user>` if it exists
3. `/home/<user>` if it exists
4. fallback: `/volume1/projects/.devbox-home/<user>`

### User And File Ownership

DevBox creates the container user from these values:

- `DEVBOX_USER`
- `DEVBOX_UID`
- `DEVBOX_GID`

By default, `devbox.sh` uses your current host `id -u` and `id -g`.
That keeps file ownership in your mounted projects path aligned with your host user.

You can still override them explicitly in `.env` or via CLI flags.

Example:

```bash
./devbox.sh --recreate \
  --user devuser \
  --uid 1000 \
  --gid 1000 \
  --ssh-port 2202 \
  --projects-dir /volume1/projects
```

### Workspace Compatibility Symlink

Projects are always mounted to:

- `/projects`

User convenience symlink:

- `/home/<user>/projects` -> `/projects`

Optional symlink:

- `/workspace` -> `/home/<user>/projects` -> `/projects`

Control it with:

- `DEVBOX_WORKSPACE_LINK=on|off`
- CLI: `--workspace-link on|off`

### Playwright Profile (Browser Sandbox Permissions)

When you enable `--playwright`, DevBox starts a second container (`devbox-playwright`) in addition to the main `devbox`.

Why a second container is used:
- Browser automation often needs relaxed sandbox settings that are not needed for normal CLI development.
- These permissions are applied only to `devbox-playwright`, while the main `devbox` stays stricter.
- This keeps day-to-day development and browser automation separated.

Playwright container runtime settings:
- `security_opt: seccomp=unconfined`
- `cap_add: SYS_ADMIN`
- `ipc: host`

Start both containers (main + playwright):

```bash
./devbox.sh --playwright --recreate \
  --user devuser \
  --ssh-port 2202 \
  --playwright-ssh-port 2203
```

SSH endpoints:

- Main devbox: `ssh <user>@<NAS_IP> -p 2202`
- Playwright devbox: `ssh <user>@<NAS_IP> -p 2203`

Typical usage:
- Use `devbox` (`2202`) for normal coding, tooling, and shell work.
- Use `devbox-playwright` (`2203`) only for browser automation tasks.

### Optional Post-Install (User Choice)

To keep the base image neutral, extra tools are installed via optional post-install scripts.
This option is independent from the Playwright profile.

Built-in targets:

- `example` -> `/projects/devbox/scripts/post-install-example.sh`
- `dev` -> `/projects/devbox/scripts/post-install-dev.sh`
- `ai` -> `/projects/devbox/scripts/post-install-ai.sh`

Run with:

```bash
./devbox.sh --post-install example
```

Playwright can be combined with any post-install target (optional):

```bash
./devbox.sh --playwright --post-install dev
```

AI tooling profile:

```bash
./devbox.sh --post-install ai
```

This installs Node.js/npm and AI CLI tools (`codex`, `claude`).

Custom script path (absolute or relative to mounted projects directory):

```bash
./devbox.sh --post-install /projects/my-scripts/post-install.sh
# or
./devbox.sh --post-install my-scripts/post-install.sh
```

This allows every user to keep their own tool stack without forcing it into the default image.

---

## 📄 License

MIT
