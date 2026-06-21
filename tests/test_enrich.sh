#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
command -v node >/dev/null 2>&1 || { echo "test_enrich: SKIP (no node)"; exit 0; }
[ -d "$ROOT/site/node_modules/yaml" ] && [ -d "$ROOT/site/node_modules/fast-xml-parser" ] \
    || { echo "test_enrich: SKIP (site deps not installed)"; exit 0; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
registry="$tmp/registry"
app="$registry/io.flatpark.TestOne"
mkdir -p "$app"

cat > "$app/io.flatpark.TestOne.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><rect width="64" height="64" fill="red"/></svg>
EOF
cat > "$app/io.flatpark.TestOne.yml" <<'EOF'
id: io.flatpark.TestOne
runtime: org.freedesktop.Platform
runtime-version: "25.08"
sdk: org.freedesktop.Sdk
command: test-one
finish-args:
  - --share=network
  - --socket=wayland
  - --device=dri
EOF
cat > "$app/io.flatpark.TestOne.metainfo.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>io.flatpark.TestOne</id>
  <name>Test One</name>
  <summary>First test app</summary>
  <project_license>MIT</project_license>
  <developer id="io.flatpark"><name>FlatPark Test Dev</name></developer>
  <url type="homepage">https://example.org/</url>
  <description>
    <p>A test application for FlatPark.</p>
    <p>Features:</p>
    <ul>
      <li>Feature alpha</li>
      <li>Feature beta</li>
    </ul>
  </description>
  <screenshots><screenshot type="default"><caption>Main</caption><image>https://example.org/shot.png</image></screenshot></screenshots>
  <releases><release version="1.0" date="2026-01-01" /></releases>
</component>
EOF
# A single flatpark.yml carries both the registry fields (id/name/summary/build)
# and developer metadata (website/maintainer) that enrich.mjs reads.
cat > "$app/flatpark.yml" <<'EOF'
id: io.flatpark.TestOne
name: Test One
summary: First test app
build:
  manifest: io.flatpark.TestOne.yml
catalog:
  category: Utilities
website: https://example.org/
maintainer:
  github: testuser
  email: test@example.org
EOF

data="$tmp/data"
REGISTRY_DIR="$registry" DATA_DIR="$data" "$ROOT/scripts/gen-apps-json.sh"
FLATPARK_DATA_DIR="$data" node "$ROOT/site/tools/enrich.mjs"

out="$data/apps/io.flatpark.TestOne.json"
assert_file "$out"
# permissions mapped from finish-args
assert_contains "$out" "\"label\": \"Network access\""
assert_contains "$out" "\"label\": \"Wayland display\""
assert_contains "$out" "\"label\": \"GPU acceleration\""
# metainfo-derived fields
assert_contains "$out" "\"FlatPark Test Dev\""
assert_contains "$out" "A test application for FlatPark."
# description is parsed into ordered blocks: paragraphs + list items
assert_contains "$out" "\"type\": \"list\""
assert_contains "$out" "Feature alpha"
assert_contains "$out" "Feature beta"
assert_contains "$out" "\"version\": \"1.0\""
assert_contains "$out" "\"label\": \"MIT\""
assert_contains "$out" "https://example.org/shot.png"
# flatpark.yml-derived maintainer
assert_contains "$out" "\"github\": \"testuser\""
# enrichment must strip the private source-path fields
if grep -q "_manifest\|_srcDir" "$out"; then echo "FAIL: enriched file still has _ fields"; exit 1; fi
assert_ok node -e "JSON.parse(require('fs').readFileSync('$out','utf8'))"
echo "test_enrich: PASS"
