#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
. "$ROOT/scripts/lib/common.sh"

load_config "$ROOT"
assert_eq "$REPO_TITLE" "FlatPark"
assert_eq "$REPO_URL" "https://dl.flatpark.org/"
assert_eq "$REPO_FILE_URL" "https://dl.flatpark.org/flatpark.flatpakrepo"
assert_eq "$REMOTE_NAME" "flatpark"
assert_eq "$RUNTIME_REMOTE_NAME" "flathub"
assert_eq "$REGISTRY_DIR" "$ROOT/registry"

# load_app against a synthetic descriptor registry — no real app referenced.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/io.flatpark.TestOne"
cat > "$tmp/io.flatpark.TestOne/flatpark.yml" <<'EOF'
id: io.flatpark.TestOne
name: Test One
summary: Synthetic test app
build:
  manifest: io.flatpark.TestOne.yml
EOF
REGISTRY_DIR="$tmp" load_config "$ROOT"
load_app "io.flatpark.TestOne"
assert_eq "$APP_ID" "io.flatpark.TestOne"
assert_eq "$APP_REF_URL" "https://dl.flatpark.org/io.flatpark.TestOne.flatpakref"
assert_eq "$REPO_DIR" "$OUT_DIR/repo"

# env override wins
OUT_DIR="/tmp/flatpark-test-out" load_config "$ROOT"
assert_eq "$OUT_DIR" "/tmp/flatpark-test-out"
assert_eq "$REPO_DIR" "/tmp/flatpark-test-out/repo"
echo "test_config: PASS"
