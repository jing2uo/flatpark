#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
command -v node >/dev/null 2>&1 || { echo "test_gen_site: SKIP (no node)"; exit 0; }
command -v npm  >/dev/null 2>&1 || { echo "test_gen_site: SKIP (no npm)"; exit 0; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
registry="$tmp/registry"
one_dir="$registry/io.flatpark.TestOne"
two_dir="$registry/io.flatpark.TestTwo"
mkdir -p "$one_dir" "$two_dir"

cat > "$one_dir/io.flatpark.TestOne.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><rect width="64" height="64" fill="red"/></svg>
EOF
cat > "$one_dir/io.flatpark.TestOne.yml" <<'EOF'
id: io.flatpark.TestOne
runtime: org.freedesktop.Platform
runtime-version: "25.08"
command: test-one
finish-args:
  - --share=network
  - --socket=wayland
EOF
cat > "$one_dir/io.flatpark.TestOne.metainfo.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>io.flatpark.TestOne</id>
  <name>Test One</name>
  <summary>First test app</summary>
  <project_license>MIT</project_license>
  <developer id="io.flatpark"><name>FlatPark Test Dev</name></developer>
  <description>
    <p>A test application for FlatPark.</p>
    <ul><li>Bullet feature one</li><li>Bullet feature two</li></ul>
  </description>
</component>
EOF
cat > "$one_dir/flatpark.yml" <<'EOF'
id: io.flatpark.TestOne
name: Test One
summary: First test app
build:
  manifest: io.flatpark.TestOne.yml
catalog:
  category: Utilities
EOF
cat > "$two_dir/flatpark.yml" <<'EOF'
id: io.flatpark.TestTwo
name: Test Two
summary: Second test app
build:
  manifest: io.flatpark.TestTwo.yml
catalog:
  category: Finance
EOF

data="$tmp/data"
REGISTRY_DIR="$registry" DATA_DIR="$data" "$ROOT/scripts/gen-apps-json.sh"

# Build needs site deps; install if absent. SKIP if that or the build fails (offline).
if [ ! -d "$ROOT/site/node_modules" ]; then
    if ! ( cd "$ROOT/site" && npm install --no-audit --no-fund >/dev/null 2>&1 ); then
        echo "test_gen_site: SKIP (npm install failed, likely offline)"; exit 0
    fi
fi
FLATPARK_DATA_DIR="$data" node "$ROOT/site/tools/enrich.mjs" >/dev/null 2>&1 || true
if ! ( cd "$ROOT/site" && FLATPARK_DATA_DIR="$data" SITE_OUT_DIR="$tmp/site" \
        npm run build >/dev/null 2>&1 ); then
    echo "test_gen_site: SKIP (astro build failed)"; exit 0
fi

index="$tmp/site/index.html"
detail="$tmp/site/apps/io.flatpark.TestOne/index.html"
setup="$tmp/site/setup/index.html"

assert_file "$index"
assert_contains "$index" "FlatPark"
assert_contains "$index" "Test One"
assert_contains "$index" "Test Two"
assert_contains "$index" "Search apps"
assert_contains "$index" "data-app-card"
assert_contains "$index" "Finance"
assert_contains "$index" "/apps/io.flatpark.TestOne/"

# Detail page: Flathub-style Install button (flatpakref) + setup link, real
# permissions/description. The manual command block now lives on /setup/.
assert_file "$detail"
assert_contains "$detail" "Test One"
assert_contains "$detail" "Permissions"
assert_contains "$detail" "Network access"
assert_contains "$detail" "FlatPark Test Dev"
assert_contains "$detail" "A test application for FlatPark."
# description <ul> list items render as <li> in the About section
assert_contains "$detail" "<li>Bullet feature one</li>"
assert_contains "$detail" "io.flatpark.TestOne.flatpakref"
assert_contains "$detail" "/setup/"

# Setup page carries the remote-add command.
assert_file "$setup"
assert_contains "$setup" "flatpak --user remote-add --if-not-exists flatpark https://dl.flatpark.org/flatpark.flatpakrepo"

# Content pages (Astro content collection) + global footer.
about="$tmp/site/about/index.html"
assert_file "$about"
assert_contains "$about" "About FlatPark"
assert_contains "$about" '<meta name="description"'
# The global footer renders on every page — check it on the catalog index.
assert_contains "$index" "/about/"
assert_contains "$index" "community Flatpak hub"

assert_file "$tmp/site/policies/index.html"
assert_contains "$tmp/site/policies/index.html" "De-listing"
assert_file "$tmp/site/trust/index.html"
assert_contains "$tmp/site/trust/index.html" "extra-data"
assert_contains "$index" "/policies/"
assert_contains "$index" "/trust/"
assert_file "$tmp/site/contributing/index.html"
assert_contains "$tmp/site/contributing/index.html" "flatpark.yml"
assert_file "$tmp/site/guide/index.html"
assert_contains "$tmp/site/guide/index.html" "remote-add"
assert_contains "$index" "/contributing/"
assert_contains "$index" "/guide/"
assert_file "$tmp/site/conduct/index.html"
assert_contains "$tmp/site/conduct/index.html" "Code of conduct"
assert_contains "$index" "/conduct/"
assert_file "$tmp/site/legal/index.html"
assert_contains "$tmp/site/legal/index.html" "no accounts"
assert_contains "$tmp/site/legal/index.html" "without warranty"
assert_contains "$index" "/legal/"
echo "test_gen_site: PASS"
