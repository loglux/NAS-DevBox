# NAS DevBox — Development Box

Run a full Linux development environment on your NAS — safely inside a container — without modifying the NAS operating system.

NAS DevBox turns your NAS into a remote Linux workstation while keeping Docker and storage on the host.

## Key features

- Full Ubuntu environment accessible via SSH
- No changes to the NAS OS
- Projects stored directly on NAS storage
- Manage host Docker from inside the dev container
- Isolated, disposable development environment

Ideal for homelabs, self-hosted setups, and lightweight remote development.

---

## Architecture

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
- Your projects live on the NAS and are mounted into `/workspace`
- The container controls host Docker via the Docker socket

No changes to the NAS firmware or OS are required.

---

## Requirements

- NAS with Docker installed
- SSH access to the NAS
- A directory for projects on the NAS (e.g. `/volume1/projects`)

---

## Quick Start

### 1. Create a projects directory on the NAS

```bash
mkdir -p /volume1/projects
```

---

### 2. Clone the repository

```bash
mkdir -p /volume1/home/devbox
cd /volume1/home/devbox
git clone https://github.com/loglux/NAS-DevBox.git .
```

---

### 3. Start the development container

Choose:

- a username
- an SSH port (must not be 22)
- your projects directory

```bash
./devbox.sh \
  --user dev \
  --pass 'changeme' \
  --ssh-port 2202 \
  --projects-dir /volume1/projects
```

What `devbox.sh` does:

- passes your parameters to Docker build/runtime
- builds or rebuilds the DevBox image
- starts the container in background mode
- mounts your NAS projects directory to `/workspace`
- connects container to host Docker via `/var/run/docker.sock`
- if `--recreate` is used, removes old container before fresh start

---

### 4. Connect via SSH

```bash
ssh dev@NAS_IP -p 2202
```

Your projects will be available inside the container at:

```
/workspace
```

---

## Default credentials

- Username: as specified with `--user`
- Password: `changeme`

`changeme` is an intentional bootstrap placeholder required for first login.
Change it immediately after installation.

From the NAS host:

```bash
docker exec -it devbox passwd dev
```

---

## Basic Usage

### Check access to host Docker

Inside the container:

```bash
docker ps
```

You should see containers running on the NAS host.

---

### Optional: Passwordless sudo

Inside the container:

```bash
sudo visudo
```

Add:

```
dev ALL=(ALL) NOPASSWD:ALL
```

---

## Recreate the Container

Recreate removes the existing container and builds a fresh one.

Important:

- DevBox does not remember previous settings
- You must pass all required parameters again
- The password resets unless `--pass` is specified
- Existing project data is safe (stored on NAS)

### Recommended recreate command

```bash
./devbox.sh --recreate \
  --user dev \
  --ssh-port 2202 \
  --projects-dir /volume1/projects
```

---

### Password behaviour

If `--pass` is not provided, the password resets to `changeme`. Change it again after recreation.

---

## Configuration

DevBox can be configured via command-line flags or environment variables.

| Variable              | Description          | Default  |
| --------------------- | -------------------- | -------- |
| DEVBOX_USER           | Container username   | dev      |
| DEVBOX_PASS           | User password        | changeme |
| DEVBOX_SSH_PORT       | SSH port             | 2202     |
| DOCKER_GID            | Docker group ID      | 1000     |
| DEVBOX_PROJECTS_DIR   | Projects path on NAS | required |
| DEVBOX_CONTAINER_NAME | Container name       | devbox   |

Flags override environment variables.

Running `./devbox.sh` without flags uses defaults from the script and does not reuse previous values.

---

## Security Notes

- The container has access to the host Docker socket
- Anyone with container access can control host containers
- Use strong passwords or SSH keys
- Consider restricting network exposure

---

## When to use NAS DevBox

This setup is useful if you want to:

- Develop directly on NAS storage
- Keep your NAS OS untouched
- Run disposable dev environments
- Use NAS as a remote build machine
- Manage Docker workloads remotely

---

## License

MIT

---

## Persistent Codex/SSH and Playwright

To avoid losing shell/Codex/SSH settings after recreate, mount one persistent home directory:

- `DEVBOX_HOME_DIR` -> `/home/<user>`

The updated `devbox.sh` does this by default:

- `DEVBOX_HOME_DIR=/volume1/projects/.devbox-home`

### User and file ownership

DevBox creates the container user from these values:

- `DEVBOX_USER`
- `DEVBOX_UID`
- `DEVBOX_GID`

By default, `devbox.sh` uses your current host `id -u` and `id -g`.
That keeps file ownership in `/workspace` aligned with your host user.

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

### Playwright profile (browser sandbox permissions)

To run browser automation reliably in containerized NAS environments, use the dedicated profile:

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

### Optional post-install (user choice)

To keep the base image neutral, extra tools are installed via optional post-install scripts.

Built-in targets:

- `example` -> `/workspace/devbox/scripts/post-install-example.sh`
- `dev` -> `/workspace/devbox/scripts/post-install-dev.sh`
- `ai` -> `/workspace/devbox/scripts/post-install-ai.sh`

Run with:

```bash
./devbox.sh --post-install example
```

With Playwright profile:

```bash
./devbox.sh --playwright --post-install dev

AI tooling profile:

```bash
./devbox.sh --post-install ai
```

This installs Node.js/npm plus:
- `@openai/codex`
- `@anthropic-ai/claude-code`

References:
- https://docs.anthropic.com/en/docs/claude-code/setup
- https://github.com/openai/codex
```

Custom script path (absolute or relative to `/workspace`):

```bash
./devbox.sh --post-install /workspace/my-scripts/post-install.sh
# or
./devbox.sh --post-install my-scripts/post-install.sh
```

This allows every user to keep their own tool stack without forcing it into the default image.

### Keep password/settings across recreate via `.env`

Use a local env file so you don't have to pass `--pass` every time:

```bash
cd /volume1/home/simulacra/devbox
cp .env.example .env
# edit .env and set DEVBOX_PASS, DEVBOX_USER, UID/GID, ports, paths
```

`devbox.sh` auto-loads:

1. `./.env`
2. `./.env.local` (optional override)

You can also load a custom file explicitly:

```bash
./devbox.sh --env-file /path/to/my.env --recreate
```

CLI flags always override env values.
