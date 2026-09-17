# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Holt** is a streamlined suite of Docker containers designed for the [Otter](https://github.com/otterlab-bio/otter) bioinformatics ecosystem and multi-language development. The project consists of one repository and two container images published to **GitHub Container Registry (GHCR)**:
- **`ghcr.io/otterlab-bio/holt-build`**: Base multi-language build container.
- **`ghcr.io/otterlab-bio/holt-run`**: Full bioinformatics workbench with Otter suite, `otter-core` runtime, JupyterLab, SSH, and AI development tools.

**Target Users**: Bioinformatics researchers, computational biologists, and software engineers working with genomics workflows and multi-language toolchains.

**Container Architecture**:
```
archlinux:latest
    ↓
holt-build (Go, Node.js/npm, Python 3, R, Rust, yay, user: otter-pup)
    ↓
holt-run (Otter suite, enva otter-core, JupyterLab, Ark, SSH, Claude Code, uv, user: otter-pup)
```

---

## Container Architecture

### 1. **holt-build** (`holt-build/Dockerfile`): Base Container

- **Purpose**: Base multi-language compilation and development environment.
- **Base Image**: `archlinux:latest` with parallel compilation flags in `makepkg.conf`.
- **Default User**: `otter-pup` (password: `otter-pup`, full sudo access).
- **Languages & Package Managers**:
  - `go` (system package via pacman)
  - `nodejs` & `npm` (system package via pacman)
  - `python` & `pip` (system package via pacman)
  - `r` & `pak` (system package via pacman + CRAN mirror)
  - `rustup` & `cargo` (Rust stable)
  - `yay` (AUR helper)
- **Environment**:
  ```bash
  PATH=/home/otter-pup/go/bin:/home/otter-pup/.cargo/bin:/home/otter-pup/.local/bin:/root/.cargo/bin:/root/go/bin:$PATH
  GOPATH=/home/otter-pup/go
  ```

---

### 2. **holt-run** (`holt-run/Dockerfile`): Runtime & Workbench Container

- **Purpose**: Complete runtime environment with Otter bioinformatics toolchain, JupyterLab, SSH, and developer tooling.
- **Inherits**: `ghcr.io/otterlab-bio/holt-build:latest`
- **Default User**: `otter-pup` (password: `otter-pup`, full sudo access).
- **Otter Tool Suite**:
  - `otter` (workflow orchestrator)
  - `enva` (Rattler-based environment manager)
  - `craftmake` (pipeline client)
  - `xenofilx` (PDX/CDX human-mouse read filtering)
  - `pairbam` (paired-end BAM reconciliation)
  - `seq2mat` (matrix transformation)
  - `methx` (methylation analysis suite)
  - `qctb` (quality assessment)
  - `fastqcx` (FASTQ QC)
  - `matsrun` (rMATS alternative splicing runner)
- **Conda Environment**:
  - `otter-core` pre-initialized via `enva` at `/opt/conda/envs/otter-core`
  - Includes: `bismark`, `bowtie2`, `samtools`, `star`, `htseq`, `rmats`, `fastqc`, `seqkit`, `picard`, `macs2`, `bwa`
- **Services & Tools**:
  - **SSH**: Port 2222 (auto-started via `/usr/local/bin/start-services.sh`)
  - **JupyterLab**: Port 8889 (manual start required)
  - **Ark (Posit Dev)**: Enhanced R kernel for JupyterLab
  - **Claude Code CLI**: Installed globally via npm (`claude-code`)
  - **uv**: Fast Python package manager
  - **add-user tool**: Interactive script at `/usr/local/bin/add-user`
- **Reserved Ports**: 8080, 8787.

---

## Build and Development Commands

### Building Containers

```bash
# Build holt-build
docker build -t ghcr.io/otterlab-bio/holt-build:latest ./holt-build

# Build holt-run
docker build -t ghcr.io/otterlab-bio/holt-run:latest ./holt-run

# Or build both via docker compose
docker compose build
```

### Running Containers

```bash
# Interactive shell in holt-build
docker run -it --name holt-build ghcr.io/otterlab-bio/holt-build:latest

# Run holt-run workspace
docker run -d \
  -p 2222:2222 \
  -p 8889:8889 \
  -p 8080:8080 \
  -p 8787:8787 \
  --name holt-run \
  ghcr.io/otterlab-bio/holt-run:latest

# Or launch holt-run with docker compose
docker compose up -d holt-run
```

### Accessing Services

**SSH Access** (auto-started on port 2222):
```bash
ssh otter-pup@localhost -p 2222
# Password: otter-pup
```

**JupyterLab** (start manually inside container):
```bash
# Start directly from host
docker exec holt-run su - otter-pup -c "jupyter-lab --no-browser --allow-root --ip=* --port=8889" &
```
Then navigate to: `http://localhost:8889`

**User Management**:
```bash
docker exec -it holt-run sudo add-user
```

---

## CI/CD (GitHub Actions)

**Location**: `.github/workflows/`

- **`holt-build.yml`**:
  - Scheduled: Fridays at 06:00 UTC
  - Push trigger on: `holt-build/**`, `.github/workflows/holt-build.yml`
  - Publishes: `ghcr.io/otterlab-bio/holt-build:latest`
- **`holt-run.yml`**:
  - Scheduled: Fridays at 08:00 UTC
  - Push trigger on: `holt-run/**`, `.github/workflows/holt-run.yml`
  - Publishes: `ghcr.io/otterlab-bio/holt-run:latest`

---

## Directory Structure

```
holt/
├── holt-build/
│   ├── Dockerfile          # Base container definition
│   └── makepkg.conf        # Arch Linux parallel build settings
├── holt-run/
│   ├── Dockerfile          # Runtime and workspace container definition
│   ├── add_user_interactive.sh # User management script for image build
│   └── envs/               # Otter environment configurations
├── .github/workflows/
│   ├── holt-build.yml      # CI/CD for holt-build (GHCR)
│   └── holt-run.yml        # CI/CD for holt-run (GHCR)
├── docker-compose.yml      # Multi-container orchestration
├── README.md               # User documentation
├── CLAUDE.md               # Development guide
├── LICENSE                 # MIT License
├── .gitignore
├── .dockerignore
└── .gitattributes
```
