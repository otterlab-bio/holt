#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="${here}/../scripts/resolve-platforms.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/mock"

cat > "$tmp/mock/curl" <<'MOCK'
#!/bin/sh
printf '%s\n' "$MOCK_BODY"
MOCK
chmod +x "$tmp/mock/curl"

check() {
  local body="$1" expected="$2"
  local actual
  actual="$(PATH="$tmp/mock:$PATH" MOCK_BODY="$body" OTTER_VERSION=v1.3.0 /bin/bash "$script")"
  [[ "$actual" == "$expected" ]] || { echo "expected $expected, got $actual" >&2; exit 1; }
}

check '{"assets": [{"name": "otter-linux-amd64-static"}, {"name": "otter-linux-arm64-static"}]}' 'linux/amd64,linux/arm64'
check '{"assets": [{"name": "otter-linux-amd64-static"}]}' 'linux/amd64'
if PATH="$tmp/mock:$PATH" MOCK_BODY='{"assets": [{"name": "otter-darwin-arm64"}]}' OTTER_VERSION=v1.0.0 /bin/bash "$script" >/dev/null 2>&1; then
  echo "expected failure for a release with no Linux assets" >&2; exit 1
fi
if PATH="$tmp/mock:$PATH" MOCK_BODY='{"assets": []}' OTTER_VERSION=v1.0.0 /bin/bash "$script" >/dev/null 2>&1; then
  echo "expected failure when no linux assets exist" >&2; exit 1
fi
echo "resolve-platforms tests passed"
