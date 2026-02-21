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
  --ssh-port 2202 \
  --projects-dir /volume1/projects
```

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

Change the password immediately.

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

Add a licence (MIT, Apache-2.0, etc.).
