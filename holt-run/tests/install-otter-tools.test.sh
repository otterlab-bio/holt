#!/usr/bin/env bash
# Offline tests for install-otter-tools.sh using a stubbed curl.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="${here}/../scripts/install-otter-tools.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

tools=(otter enva craftmake xenofilx pairbam seq2mat methx qctb fastqcx matsrun)
mkdir -p "$tmp/release/v1.3.0" "$tmp/mock" "$tmp/bin" "$tmp/links" "$tmp/envs" "$tmp/fallback"
for tool in "${tools[@]}"; do
  printf '#!/bin/sh\necho "%s v1.3.0"\n' "$tool" > "$tmp/release/v1.3.0/${tool}-linux-arm64-static"
done
chmod +x "$tmp/release/v1.3.0/"*linux-arm64-static
for f in otter-core.yaml otter-snakemake.yaml otter-extra.yaml; do
  printf 'name: %s\n' "${f%.yaml}" > "$tmp/release/v1.3.0/$f"
done
(cd "$tmp/release/v1.3.0" && shasum -a 256 * > checksums.txt)

cat > "$tmp/mock/curl" <<'MOCK'
#!/bin/sh
out=""; url=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    -H|--retry|--retry-delay|--connect-timeout) shift 2 ;;
    -*) shift ;;
    *) url="$1"; shift ;;
  esac
done
case "$url" in
  *api.github.com/repos/*/releases/latest)
    printf '{"tag_name": "v1.3.0"}\n' ;;
  *api.github.com/repos/*/releases\?per_page=*)
    printf '[{"tag_name": "v2.9.9", "prerelease": false}, {"tag_name": "v1.3.0", "prerelease": false}]\n' ;;
  *api.github.com/repos/*/releases/tags/*)
    tag="${url##*/tags/}"
    if [ "$tag" = v2.9.9 ]; then
      printf '{"tag_name": "%s", "prerelease": false, "assets": [{"name": "otter-linux-amd64-static"}]}\n' "$tag"
      exit 0
    fi
    if [ "$tag" = v1.3.0 ]; then
      # Pad the payload past a pipe buffer so this exercises the same path as
      # the real API response, where printf used to die of SIGPIPE.
      padding="$(printf '%4000s' '' | tr ' ' x)"
      # Only list the assets this test actually publishes for arm64.
      names=""
      for f in "$RELEASE_ROOT/$tag"/*; do
        b="$(basename "$f")"
        case "$b" in checksums.txt|*.yaml) continue ;; esac
        names="$names{\"name\": \"$b\"},"
      done
      printf '{"tag_name": "%s", "prerelease": false, "padding": "%s", "assets": [%s]}\n' "$tag" "$padding" "${names%,}"
    else
      printf '{"tag_name": "%s", "prerelease": false, "assets": []}\n' "$tag"
    fi ;;
  */releases/download/*)
    src="$RELEASE_ROOT/${url#*/releases/download/}"
    [ -f "$src" ] || { echo "404 $url" >&2; exit 22; }
    if [ -n "$out" ]; then cp "$src" "$out"; else cat "$src"; fi ;;
  *) echo "unexpected url: $url" >&2; exit 1 ;;
esac
MOCK
chmod +x "$tmp/mock/curl"

run() {
  PATH="$tmp/mock:$PATH" RELEASE_ROOT="$tmp/release" OTTER_REPO=owner/otter \
  OTTER_VERSION="$1" ARCH=arm64 BIN_DIR="$tmp/bin" LINK_DIR="$tmp/links" \
  ENV_DIR="$tmp/envs" FALLBACK_ENV_DIR="$tmp/fallback" /bin/bash "$script" "${@:2}"
}
export -f run 2>/dev/null || true

# 1. latest resolves the stable tag, installs verified binaries and symlinks.
run latest >/dev/null
test -x "$tmp/bin/otter"
test "$(cat "$tmp/VERSION")" = "v1.3.0"
test -L "$tmp/links/methx"
test -f "$tmp/envs/otter-core.yaml"

# 2. A tampered binary must fail verification.
cp "$tmp/release/v1.3.0/otter-linux-arm64-static" "$tmp/otter.bak"
printf 'tampered\n' >> "$tmp/release/v1.3.0/otter-linux-arm64-static"
if run v1.3.0 >/dev/null 2>&1; then
  echo "tampered artifact was accepted" >&2; exit 1
fi
cp "$tmp/otter.bak" "$tmp/release/v1.3.0/otter-linux-arm64-static"

# 3. Missing release YAML falls back to the bundled copy.
printf 'name: otter-extra\n' > "$tmp/fallback/otter-extra.yaml"
mv "$tmp/release/v1.3.0/otter-extra.yaml" "$tmp/otter-extra.removed"
(cd "$tmp/release/v1.3.0" && shasum -a 256 * > checksums.txt)
rm -f "$tmp/envs/otter-extra.yaml"
run v1.3.0 >/dev/null
test -f "$tmp/envs/otter-extra.yaml"

# 4. Dry run performs no network access and writes nothing.
rm -rf "$tmp/bin"; mkdir -p "$tmp/bin"
out="$(run latest --dry-run)"
grep -q '<latest>/otter-linux-arm64-static' <<< "$out"
test -z "$(ls -A "$tmp/bin")"
echo "install-otter-tools tests passed"

# 5. A newer release without the requested architecture is skipped, not half-installed.
rm -rf "$tmp/bin"; mkdir -p "$tmp/bin"
run latest >/dev/null
test "$(cat "$tmp/VERSION")" = "v1.3.0"
echo "latest skips releases that lack the target architecture"

# 6. An explicitly pinned release without assets fails loudly.
if run v1.2.2 >/dev/null 2>&1; then
  echo "pinned release without assets was accepted" >&2; exit 1
fi

# 7. LINK_DIR= disables symlinks instead of silently falling back to /usr/local/bin.
rm -rf "$tmp/bin" "$tmp/links"; mkdir -p "$tmp/bin"
PATH="$tmp/mock:$PATH" RELEASE_ROOT="$tmp/release" OTTER_REPO=owner/otter \
  OTTER_VERSION=v1.3.0 ARCH=arm64 BIN_DIR="$tmp/bin" LINK_DIR= \
  ENV_DIR="$tmp/envs" /bin/bash "$script" >/dev/null
test -x "$tmp/bin/otter" && test ! -e /usr/local/bin/otter
echo "LINK_DIR= installs into BIN_DIR only"

# 8. The default OTTER_VERSION is 'latest'; the workflow used to pin the tag,
#    which hid a SIGPIPE in release parsing on real API payloads.
rm -rf "$tmp/bin"; mkdir -p "$tmp/bin"
env -u OTTER_VERSION PATH="$tmp/mock:$PATH" RELEASE_ROOT="$tmp/release" \
  OTTER_REPO=owner/otter ARCH=arm64 BIN_DIR="$tmp/bin" LINK_DIR= \
  ENV_DIR="$tmp/envs" /bin/bash "$script" > "$tmp/latest.log" 2>&1
test "$(cat "$tmp/VERSION")" = "v1.3.0"
echo "default OTTER_VERSION resolves the latest stable release"
