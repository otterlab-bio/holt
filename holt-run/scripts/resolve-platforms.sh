#!/usr/bin/env bash
# Print the comma-separated docker platforms that the resolved OTTER release
# can actually serve. Keeps holt-run from publishing an image for an
# architecture the release does not ship.
#
# Environment: OTTER_REPO (default otterlab-bio/otter), OTTER_VERSION
# (default latest), GITHUB_TOKEN (optional, for rate limits).
set -euo pipefail
OTTER_REPO="${OTTER_REPO:-otterlab-bio/otter}"
OTTER_VERSION="${OTTER_VERSION:-latest}"
OTTER_API_BASE="${OTTER_API_BASE:-https://api.github.com}"

if [[ "${1:-}" == "--version" ]]; then
  OTTER_VERSION="${2:?--version requires a tag}"
fi

auth=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  auth=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

if [[ "$OTTER_VERSION" == "latest" ]]; then
  OTTER_VERSION="$(curl -fsSL --retry 5 --retry-delay 2 -H 'Accept: application/vnd.github+json' "${auth[@]+"${auth[@]}"}" \
    "${OTTER_API_BASE}/repos/${OTTER_REPO}/releases/latest" \
    | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
  [[ -n "$OTTER_VERSION" ]] || { echo "could not resolve the latest release" >&2; exit 1; }
fi

body="$(curl -fsSL --retry 5 --retry-delay 2 -H 'Accept: application/vnd.github+json' "${auth[@]+"${auth[@]}"}" \
  "${OTTER_API_BASE}/repos/${OTTER_REPO}/releases/tags/${OTTER_VERSION}")"

platforms=()
for arch in amd64 arm64; do
  if grep -Fq "\"name\": \"otter-linux-${arch}-static\"" <<< "$body"; then
    platforms+=("linux/${arch}")
  fi
done
if [[ ${#platforms[@]} -eq 0 ]]; then
  echo "release ${OTTER_VERSION} has no linux binaries" >&2
  exit 1
fi
printf '%s\n' "${platforms[*]}" | tr ' ' ','
