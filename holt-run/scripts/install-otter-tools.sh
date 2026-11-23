#!/usr/bin/env bash
# Install the OTTER toolchain from a published otterlab-bio/otter release.
#
# OTTER_VERSION=latest (the default) resolves the newest *stable* release at
# build time, so the container follows the OTTER repository instead of pinning
# a version in the Dockerfile. Pin explicitly with e.g. OTTER_VERSION=v1.3.0.
#
# Every binary is verified against the release's published checksums.txt before
# it is installed. Environment YAML files are taken from the same release so the
# runtime definition cannot drift from the binaries.
#
# Usage:
#   OTTER_VERSION=latest install-otter-tools.sh [--dry-run]
#
# Environment:
#   OTTER_REPO         GitHub repository (default otterlab-bio/otter)
#   OTTER_VERSION      Release tag or "latest" (default latest)
#   OTTER_API_BASE     GitHub API base (default https://api.github.com)
#   OTTER_RELEASES_BASE  Release download base (default https://github.com/$OTTER_REPO/releases/download)
#   ARCH               Release architecture: amd64 or arm64 (default: detected)
#   BIN_DIR            Binary install directory (default /opt/otter/bin)
#   LINK_DIR           Directory that receives PATH symlinks (default /usr/local/bin;
#                      set LINK_DIR= to install only into BIN_DIR)
#   ENV_DIR            Environment YAML destination (default /opt/otter/envs)
#   FALLBACK_ENV_DIR   Copy YAMLs from here if the release has none (optional)
set -euo pipefail

OTTER_REPO="${OTTER_REPO:-otterlab-bio/otter}"
OTTER_VERSION="${OTTER_VERSION:-latest}"
OTTER_API_BASE="${OTTER_API_BASE:-https://api.github.com}"
OTTER_RELEASES_BASE="${OTTER_RELEASES_BASE:-https://github.com/${OTTER_REPO}/releases/download}"
BIN_DIR="${BIN_DIR:-/opt/otter/bin}"
LINK_DIR="${LINK_DIR-/usr/local/bin}"
ENV_DIR="${ENV_DIR:-/opt/otter/envs}"
FALLBACK_ENV_DIR="${FALLBACK_ENV_DIR:-}"

TOOLS=(otter enva craftmake xenofilx pairbam seq2mat methx qctb fastqcx matsrun)
ENV_FILES=(otter-core.yaml otter-snakemake.yaml otter-extra.yaml)

DRY_RUN=false
case "${1:-}" in
  --dry-run) DRY_RUN=true ;;
  "") ;;
  *) echo "unknown argument: $1" >&2; exit 2 ;;
esac

log() { printf '==> %s\n' "$*" >&2; }

if [[ -z "${ARCH:-}" ]]; then
  case "$(uname -m)" in
    x86_64|amd64) ARCH=amd64 ;;
    aarch64|arm64) ARCH=arm64 ;;
    *) echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
  esac
fi
case "$ARCH" in
  amd64|arm64) ;;
  *) echo "ARCH must be amd64 or arm64 (got $ARCH)" >&2; exit 1 ;;
esac

curl_api() { curl -fsSL --retry 5 --retry-delay 2 --connect-timeout 20 "$@"; }

release_has_arch() {
  # $1 is the JSON for a single release. Match the exact asset name so a
  # release that predates this architecture is skipped instead of producing a
  # half-populated image.
  # A herestring keeps grep from closing the pipe early: with pipefail a large
  # release JSON made printf die of SIGPIPE and the lookup fail.
  grep -Fq -- "\"name\": \"otter-linux-${ARCH}-static\"" <<< "$1"
}

resolve_version() {
  local body tag
  body="$(curl_api -H 'Accept: application/vnd.github+json' \
    "${OTTER_API_BASE}/repos/${OTTER_REPO}/releases?per_page=20")"
  # Prefer the newest stable release that actually ships this architecture.
  # releases/latest ignores drafts and prereleases; the list endpoint includes
  # them, so skip anything marked "prerelease": true.
  while IFS= read -r tag; do
    [ -n "$tag" ] || continue
    if curl_api -H 'Accept: application/vnd.github+json' \
        "${OTTER_API_BASE}/repos/${OTTER_REPO}/releases/tags/${tag}" > "$work/release.json" 2>/dev/null &&
      ! grep -Fq '"prerelease": true' "$work/release.json" &&
      release_has_arch "$(cat "$work/release.json")"; then
      printf '%s\n' "$tag"
      return 0
    fi
  done < <(printf '%s\n' "$body" | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p')
  return 1
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

if [[ "$OTTER_VERSION" == "latest" ]]; then
  if [[ "$DRY_RUN" == true ]]; then
    echo "would resolve the latest stable release of ${OTTER_REPO}"
    OTTER_VERSION="<latest>"
  else
    log "resolving the latest stable release of ${OTTER_REPO}"
    resolved="$(resolve_version)"
    if [[ -z "$resolved" ]]; then
      echo "could not resolve a stable ${OTTER_REPO} release that ships linux/${ARCH} binaries" >&2
      exit 1
    fi
    OTTER_VERSION="$resolved"
  fi
fi

base="${OTTER_RELEASES_BASE}/${OTTER_VERSION}"
log "installing OTTER ${OTTER_VERSION} (linux/${ARCH})"

if [[ "$DRY_RUN" == true ]]; then
  for tool in "${TOOLS[@]}"; do echo "would download ${base}/${tool}-linux-${ARCH}-static"; done
  for env_file in "${ENV_FILES[@]}"; do echo "would download ${base}/${env_file}"; done
  exit 0
fi

mkdir -p "$BIN_DIR" "$ENV_DIR"

curl_api "${base}/checksums.txt" -o "$work/checksums.txt"
verify() {
  local asset="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$work" && grep -E "[[:space:]]${asset//./\\.}$" checksums.txt | sha256sum -c -)
  else
    (cd "$work" && grep -E "[[:space:]]${asset//./\\.}$" checksums.txt | shasum -a 256 -c -)
  fi
}

for tool in "${TOOLS[@]}"; do
  asset="${tool}-linux-${ARCH}-static"
  log "downloading ${asset}"
  curl_api "${base}/${asset}" -o "$work/${asset}"
  verify "$asset"
  install -m 0755 "$work/${asset}" "$BIN_DIR/${tool}"
  if [[ -n "$LINK_DIR" ]]; then
    mkdir -p "$LINK_DIR"
    ln -sf "$BIN_DIR/${tool}" "$LINK_DIR/${tool}"
  fi
done

for env_file in "${ENV_FILES[@]}"; do
  if curl_api "${base}/${env_file}" -o "$ENV_DIR/${env_file}" 2>/dev/null; then
    log "downloaded ${env_file}"
  elif [[ -n "$FALLBACK_ENV_DIR" && -f "${FALLBACK_ENV_DIR}/${env_file}" ]]; then
    log "release has no ${env_file}; using the bundled copy"
    cp "${FALLBACK_ENV_DIR}/${env_file}" "$ENV_DIR/${env_file}"
  else
    log "release has no ${env_file} and no bundled copy; skipping"
  fi
done

printf '%s\n' "$OTTER_VERSION" > "$(dirname "$BIN_DIR")/VERSION"
if "$BIN_DIR/otter" --version >/dev/null 2>&1; then
  "$BIN_DIR/otter" --version
else
  # Cross-built assets cannot run on the build host; the container's own
  # platform matches the target, so this only affects local testing.
  log "installed ${ARCH} binaries; skipping --version (not runnable on this host)"
fi
log "OTTER ${OTTER_VERSION} installed into ${BIN_DIR}"
