#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
reg="$tmp/registry"; mkdir -p "$reg/io.flatpark.TestOne"
cat > "$reg/io.flatpark.TestOne/flatpark.yml" <<'EOF'
id: io.flatpark.TestOne
name: Test One
summary: Synthetic test app
build:
  manifest: io.flatpark.TestOne.yml
EOF
env_common=(OUT_DIR="$tmp/out" GNUPGHOME_DIR="$tmp/gnupg" REPO_URL="file://$tmp/out/repo" REGISTRY_DIR="$reg")

env "${env_common[@]}" "$ROOT/scripts/gen-signing-key.sh" >/dev/null
env "${env_common[@]}" "$ROOT/scripts/gen-discovery.sh" io.flatpark.TestOne

repo="$tmp/out/flatpark.flatpakrepo"
repo_canonical="$tmp/out/repo/flatpark.flatpakrepo"
ref="$tmp/out/io.flatpark.TestOne.flatpakref"
ref_canonical="$tmp/out/repo/io.flatpark.TestOne.flatpakref"
assert_file "$repo"
assert_file "$repo_canonical"
assert_contains "$repo" "Title=FlatPark"
assert_contains "$repo" "Url=file://$tmp/out/repo"
assert_contains "$repo" "GPGKey="
assert_file "$ref"
assert_file "$ref_canonical"
assert_contains "$ref" "Name=io.flatpark.TestOne"
assert_contains "$ref" "RuntimeRepo=https://dl.flathub.org/repo/flathub.flatpakrepo"
# GPGKey line must carry a non-empty base64 payload
grep -q "^GPGKey=..*" "$repo" || { echo "FAIL: empty GPGKey"; exit 1; }
echo "test_gen_discovery: PASS"
