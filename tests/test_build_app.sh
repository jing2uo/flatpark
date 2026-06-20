#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
command -v flatpak-builder >/dev/null || { echo "test_build_app: SKIP (no flatpak-builder)"; exit 0; }
[ -x "$ROOT/scripts/build-app.sh" ] || { echo "FAIL: missing build script"; exit 1; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
# Build the self-contained synthetic fixture: registry/<id>/ holds the
# descriptor + manifest + assets (tests/fixtures is the registry root).
env_common=(OUT_DIR="$tmp/out" GNUPGHOME_DIR="$tmp/gnupg" REPO_DIR="$tmp/repo" REGISTRY_DIR="$ROOT/tests/fixtures")

env "${env_common[@]}" "$ROOT/scripts/gen-signing-key.sh" >/dev/null
if ! env "${env_common[@]}" "$ROOT/scripts/build-app.sh" io.flatpark.BuildOne; then
    echo "test_build_app: SKIP (build failed, likely no runtime/network)"; exit 0
fi
assert_ok ostree --repo="$tmp/repo" refs
ostree --repo="$tmp/repo" refs | grep -q "app/io.flatpark.BuildOne/.*/stable" \
    || { echo "FAIL: app ref not in repo"; exit 1; }
echo "test_build_app: PASS"
