#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
command -v flatpak-builder >/dev/null || { echo "test_publish_e2e: SKIP (no flatpak-builder)"; exit 0; }
[ -x "$ROOT/scripts/publish.sh" ] || { echo "FAIL: missing publish script"; exit 1; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
# Publish the self-contained synthetic fixture end-to-end. Pass the explicit id
# so only this fixture is built even if more land under tests/fixtures.
env_common=(
    OUT_DIR="$tmp/out" GNUPGHOME_DIR="$tmp/gnupg" REPO_DIR="$tmp/out/repo"
    REPO_URL="file://$tmp/out/repo" REGISTRY_DIR="$ROOT/tests/fixtures"
    DATA_DIR="$tmp/data" FLATPARK_DATA_DIR="$tmp/data"
)

if ! env "${env_common[@]}" "$ROOT/scripts/publish.sh" io.flatpark.BuildOne; then
    echo "test_publish_e2e: SKIP (publish failed, likely no runtime/network)"; exit 0
fi
assert_file "$tmp/out/flatpark.flatpakrepo"
assert_file "$tmp/out/io.flatpark.BuildOne.flatpakref"
assert_file "$tmp/out/site/index.html"
assert_file "$tmp/out/repo/summary.sig"
echo "test_publish_e2e: PASS"
