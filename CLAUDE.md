# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Holt** is a streamlined suite of Docker containers designed for bioinformatics workflows and multi-language development. The project consists of one repository and two container images:
- **`holt-build`**: Lightweight multi-language base container.
- **`holt-run`**: Full development and runtime workspace with R bioinformatics packages, JupyterLab, SSH, and AI development tools.

**Target Users**: Bioinformatics researchers, computational biologists, and data scientists working with genomics pipelines and multi-language tools.

**Container Architecture**:
```
archlinux:latest
    ↓
holt-build (Base: Python 3, R, pak, micromamba, yay, rustup, Node.js, npm, Go)
    ↓
holt-run (R packages, JupyterLab [manual], Ark, Air, SSH [auto], Claude Code, uv, fallingstar10 user)
```

---

## Container Architecture

### 1. **holt-build** (`holt-build/Dockerfile`): Base Container

- **Purpose**: Base multi-language compilation and development environment.
- **Base Image**: `archlinux:latest` with parallel compilation flags in `makepkg.conf`.
- **User**: `builduser` for AUR package installation.
- **Package Managers**:
  - `yay` (AUR helper)
  - `pak` (R package manager)
  - `micromamba` (lightweight Conda alternative)
  - `pip` (Python)
  - `cargo` (Rust)
  - `npm` (Node.js)
  - `go mod` (Go)
- **Languages**: Python 3, R, Rust, Node.js, Go.
- **Environment**:
  ```bash
  PATH=/opt/micromamba/bin:/root/.cargo/bin:/root/.local/bin:/root/go/bin:$PATH
  GOPATH=/root/go
  ```

---

### 2. **holt-run** (`holt-run/Dockerfile`): Runtime & Workspace Container

- **Purpose**: Complete runtime environment with statistical packages, services, and developer tooling.
- **Inherits**: `fallingstar10/holt-build:latest`
- **R Packages**:
  - **Group 1**: Shiny ecosystem & utilities (DT, shinyWidgets, shiny, bslib, optparse, openxlsx, etc.)
  - **Group 2**: Statistics & visualization (plotly, pROC, sva, sampling, pdftools, umap, tidyverse, etc.)
  - **Group 6**: Machine learning (mlr3verse)
  - **Group 7**: Developer tools (languageserver, lintr)
- **Services & Tools**:
  - **SSH**: Port 2222 (auto-started via `/usr/local/bin/start-services.sh`)
  - **JupyterLab**: Port 8889 (manual start required)
  - **Ark (Posit Dev)**: Enhanced R kernel for JupyterLab
  - **Air (Posit Dev)**: R developer workflow tool
  - **Claude Code CLI**: Installed globally via npm
  - **uv**: Fast Python package manager
  - **add-user tool**: Interactive script at `/usr/local/bin/add-user`
- **Default User**: `fallingstar10` (password: `fallingstar10`, sudo access enabled).
- **Reserved Ports**: 8080, 8787.

---

## Build and Development Commands

### Building Containers

```bash
# Build holt-build
docker build -t fallingstar10/holt-build:latest ./holt-build

# Build holt-run
docker build -t fallingstar10/holt-run:latest ./holt-run

# Or build both via docker compose
docker compose build
```

### Running Containers

```bash
# Interactive shell in holt-build
docker run -it --name holt-build fallingstar10/holt-build:latest

# Run holt-run workspace
docker run -d \
  -p 2222:2222 \
  -p 8889:8889 \
  -p 8080:8080 \
  -p 8787:8787 \
  --name holt-run \
  fallingstar10/holt-run:latest

# Or launch holt-run with docker compose
docker compose up -d holt-run
```

### Accessing Services

**SSH Access** (auto-started on port 2222):
```bash
ssh fallingstar10@localhost -p 2222
# Password: fallingstar10
```

**JupyterLab** (start manually inside container):
```bash
# Start directly from host
docker exec holt-run su - fallingstar10 -c "jupyter-lab --no-browser --allow-root --ip=* --port=8889" &
```
Then navigate to: `http://localhost:8889`

**User Management**:
```bash
docker exec -it holt-run add-user
```

---

## CI/CD (GitHub Actions)

**Location**: `.github/workflows/`

- **`holt-build.yml`**:
  - Scheduled: Fridays at 06:00 UTC
  - Push trigger on: `holt-build/**`, `.github/workflows/**`
  - Publishes: `${{ secrets.DOCKER_HUB_USERNAME }}/holt-build:latest`
- **`holt-run.yml`**:
  - Scheduled: Fridays at 08:00 UTC
  - Push trigger on: `holt-run/**`, `.github/workflows/**`
  - Publishes: `${{ secrets.DOCKER_HUB_USERNAME }}/holt-run:latest`

---

## Directory Structure

```
holt/
├── holt-build/
│   ├── Dockerfile          # Base container definition
│   └── makepkg.conf        # Arch Linux parallel build settings
├── holt-run/
│   ├── Dockerfile          # Runtime and workspace container definition
│   └── add_user_interactive.sh # User management script for image build
├── .github/workflows/
│   ├── holt-build.yml      # CI/CD for holt-build
│   └── holt-run.yml        # CI/CD for holt-run
├── docker-compose.yml      # Multi-container orchestration
├── add_user_interactive.sh # Standalone interactive user setup script
├── README.md               # User documentation
├── CLAUDE.md               # Development guide
├── LICENSE                 # MIT License
├── .gitignore
├── .dockerignore
└── .gitattributes
```

---

## Important Notes

1. **JupyterLab Manual Start**: JupyterLab is NOT auto-started by default to save idle resources. Users launch it when needed.
2. **Rust Environment**: For `fallingstar10`, run `source ~/.cargo/env` to initialize Rust in interactive shells.
3. **CRAN Mirror**: Configured by default to Tsinghua CRAN mirror for stable, fast R package installations.
