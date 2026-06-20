#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
. "$ROOT/scripts/lib/common.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
reg="$tmp/registry"; mkdir -p "$reg/io.flatpark.TestOne"
cat > "$reg/io.flatpark.TestOne/flatpark.yml" <<'EOF'
id: io.flatpark.TestOne
name: Test One
summary: First test app
build:
  manifest: io.flatpark.TestOne.yml
  branch: stable
  mode: extra-data-url
catalog:
  category: Finance
  tags:
    - Trading
    - Markets
    - Workstation
EOF

REGISTRY_DIR="$reg" load_config "$ROOT"
load_app "io.flatpark.TestOne"
assert_eq "$APP_NAME" "Test One"
assert_eq "$APP_BRANCH" "stable"
assert_eq "$UPDATE_MODE" "extra-data-url"
assert_eq "$MANIFEST" "$reg/io.flatpark.TestOne/io.flatpark.TestOne.yml"
assert_eq "$APP_SRC" "$reg/io.flatpark.TestOne"
assert_eq "$APP_CATEGORY" "Finance"
assert_eq "$APP_TAGS" "Trading, Markets, Workstation"

ids="$(REGISTRY_DIR="$reg" "$ROOT/scripts/scan-registry.sh" --ids)"
assert_eq "$ids" "io.flatpark.TestOne"
scan="$(REGISTRY_DIR="$reg" "$ROOT/scripts/scan-registry.sh" io.flatpark.TestOne)"
case "$scan" in
    *"io.flatpark.TestOne"*"extra-data-url"*) ;;
    *) echo "FAIL: scan output missing app/update mode: $scan"; exit 1 ;;
esac

# explicit env overrides must win over the descriptor defaults
override_scan="$(REGISTRY_DIR="$reg" APP_SRC="/tmp/flatpark-app-src" MANIFEST="/tmp/flatpark-app.yml" \
    "$ROOT/scripts/scan-registry.sh" io.flatpark.TestOne)"
case "$override_scan" in
    *"/tmp/flatpark-app.yml") ;;
    *) echo "FAIL: scan did not preserve explicit manifest override: $override_scan"; exit 1 ;;
esac
echo "test_registry: PASS"
