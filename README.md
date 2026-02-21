# NAS Development Box

Run a full Linux development environment on your NAS — safely, inside a container — without modifying the NAS operating system.

DevBox lets you:

- SSH into a full Ubuntu environment
- Keep Docker running on the NAS host
- Store projects directly on NAS storage
- Manage host Docker from inside the dev container

Ideal for turning a NAS into a lightweight remote development machine.

---

## How it works

```
Your PC ── SSH ──► Dev Container (Ubuntu)
                       │
                       ▼
                 Docker Engine (NAS)
                       │
                       ▼
                 Project Containers
```

- The NAS runs Docker normally
- DevBox runs an Ubuntu container with development tools
- Your projects live on the NAS and are mounted into `/workspace`
- The container can control host Docker via the Docker socket

No changes to the NAS OS are required.

---

## Requirements

- NAS with Docker installed
- SSH access to the NAS
- A directory for projects on the NAS (e.g. `/volume1/projects`)

---

## Quick Start

### 1. Create a projects directory

```
mkdir -p /volume1/projects
```

---

### 2. Clone the repository

```
mkdir -p /volume1/home/devbox
cd /volume1/home/devbox
git clone https://github.com/loglux/NAS-DevBox.git .
```

---

### 3. Start the dev container

Choose:

- a container username
- an SSH port (not 22, default is 2202)
- your projects directory

```
./devbox.sh \
  --user dev \
  --ssh-port 2202 \
  --projects-dir /volume1/projects
```

---

### 4. Connect via SSH

```
ssh dev@NAS_IP -p 2202
```

Your projects will be available inside the container at:

```
/workspace
```

---

## Changing the default password

Default password: `changeme`

Change it from the NAS host:

```
docker exec -it devbox passwd dev
```

---

## Configuration

You can configure DevBox using command-line flags or environment variables.

|Variable|Description|Default|
|---|---|---|
|DEVBOX_USER|Container username|dev|
|DEVBOX_PASS|User password|changeme|
|DEVBOX_SSH_PORT|SSH port|2202|
|DOCKER_GID|Docker group ID|1000|
|DEVBOX_PROJECTS_DIR|Projects path on NAS|— (required)|
|DEVBOX_CONTAINER_NAME|Container name|devbox|

Flags override environment variables.

---

## Recreate the container

```
./devbox.sh --recreate --user dev --ssh-port 2202 --projects-dir /volume1/projects
```

Recreate builds a fresh container. The user and password are reset to the
values you pass (or the defaults). If you do not pass `--pass`, it will revert
to `changeme` and should be changed again.

---

## Verify Docker access

Inside the container:

```
docker ps
```

You should see containers running on the NAS host.

---

## Optional: Passwordless sudo

Inside the dev container:

```
sudo visudo
```

Add:

```
dev ALL=(ALL) NOPASSWD:ALL
```
