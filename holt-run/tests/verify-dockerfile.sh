#!/usr/bin/env bash
# Static checks for the arm64 verification Dockerfile, so a broken file fails
# fast without waiting for an arm64 runner.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dockerfile="${here}/../Dockerfile.arm64-verify"
grep -q '^FROM ubuntu:24.04$' "$dockerfile" || { echo 'expected an Ubuntu 24.04 base' >&2; exit 1; }
grep -q 'scripts/install-otter-tools.sh' "$dockerfile" || { echo 'must reuse the release installer' >&2; exit 1; }
grep -q 'ARCH=arm64' "$dockerfile" || { echo 'must request arm64 assets' >&2; exit 1; }
grep -q 'MAMBA_ROOT_PREFIX=/opt/conda' "$dockerfile" || { echo 'must pin the enva root prefix' >&2; exit 1; }
grep -q 'linux/arm64\|ubuntu:24.04' "$dockerfile" || { echo 'expected an arm64-oriented base' >&2; exit 1; }
if grep -qE '^[[:space:]]*ENV[[:space:]]+OTTER_VERSION=v[0-9]' "$dockerfile"; then
  echo 'must not pin OTTER_VERSION in ENV' >&2; exit 1
fi
echo 'verify Dockerfile checks passed'
