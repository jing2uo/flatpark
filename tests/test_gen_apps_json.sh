#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
registry="$tmp/registry"
one_dir="$registry/io.flatpark.TestOne"
two_dir="$registry/io.flatpark.TestTwo"
mkdir -p "$one_dir" "$two_dir"
# Icon is auto-detected from <APP_SRC>/<id>.svg (APP_SRC defaults to the app dir).
cat > "$one_dir/io.flatpark.TestOne.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><rect width="64" height="64" fill="red"/></svg>
EOF
cat > "$one_dir/flatpark.yml" <<'EOF'
id: io.flatpark.TestOne
name: Test One
summary: First test app
build:
  manifest: test-one.yml
catalog:
  category: Utilities
  tags:
    - Local
    - Test
EOF
# TestTwo ships only a PNG icon (no SVG); the resolver falls back to <id>.png.
printf '\x89PNG\r\n\x1a\n' > "$two_dir/io.flatpark.TestTwo.png"
cat > "$two_dir/flatpark.yml" <<'EOF'
id: io.flatpark.TestTwo
name: Test Two
summary: Second test app
build:
  manifest: test-two.yml
catalog:
  category: Finance
  tags:
    - Markets
EOF

data="$tmp/data"
REGISTRY_DIR="$registry" DATA_DIR="$data" "$ROOT/scripts/gen-apps-json.sh"

catalog="$data/catalog.json"
one="$data/apps/io.flatpark.TestOne.json"
two="$data/apps/io.flatpark.TestTwo.json"

# Light catalog: card fields for every app, plus repo block.
assert_file "$catalog"
assert_contains "$catalog" "\"id\": \"io.flatpark.TestOne\""
assert_contains "$catalog" "\"id\": \"io.flatpark.TestTwo\""
assert_contains "$catalog" "\"name\": \"Test One\""
assert_contains "$catalog" "\"category\": \"Finance\""
assert_contains "$catalog" "\"remoteCmd\": \"flatpak --user remote-add --if-not-exists flatpark"
# Catalog stays light: no per-app heavy fields leak in.
if grep -q "_manifest" "$catalog"; then echo "FAIL: catalog carries _manifest"; exit 1; fi

# Base per-app files carry install data + source paths for enrichment.
assert_file "$one"
assert_file "$two"
assert_file "$data/icons/io.flatpark.TestOne.svg"
assert_file "$data/icons/io.flatpark.TestTwo.png"
assert_contains "$one" "\"installCmd\": \"flatpak --user install flatpark io.flatpark.TestOne\""
assert_contains "$one" "\"_manifest\": \"$one_dir/test-one.yml\""
assert_contains "$one" "\"_srcDir\": \"$one_dir\""

# Valid JSON.
if command -v node >/dev/null 2>&1; then
    assert_ok node -e "['$catalog','$one','$two'].forEach(f=>JSON.parse(require('fs').readFileSync(f,'utf8')))"
fi
echo "test_gen_apps_json: PASS"
