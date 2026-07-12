#!/usr/bin/env bash
# changed-apps.sh: only build-relevant changes trigger a rebuild. Runs the real
# script from a throwaway git repo (scripts/ + config/ copied in, so ROOT
# resolves there).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
command -v git >/dev/null || { echo "test_changed_apps: SKIP (no git)"; exit 0; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

cp -r "$ROOT/scripts" "$ROOT/config" "$tmp/"
app="$tmp/registry/io.flatpark.TestOne"; mkdir -p "$app"
cat > "$app/flatpark.yml" <<'EOF'
id: io.flatpark.TestOne
name: Test One
summary: First test app
build:
  manifest: io.flatpark.TestOne.yml
  branch: stable
  mode: extra-data
catalog:
  category: Finance
  tags:
    - Trading
EOF
cat > "$app/io.flatpark.TestOne.yml" <<'EOF'
id: io.flatpark.TestOne
modules:
  - name: main
    sources:
      - type: extra-data
        url: https://example.org/app-1.0.deb
        sha256: aaaa
EOF

g() { git -C "$tmp" "$@"; }
g init -q
g -c user.name=t -c user.email=t@t add -A
g -c user.name=t -c user.email=t@t commit -qm base
base="$(g rev-parse HEAD)"
changed() { "$tmp/scripts/changed-apps.sh" "$base" HEAD; }
snap() { g -c user.name=t -c user.email=t@t commit -qam "$1"; }

# 1. catalog-only descriptor edit -> no rebuild, but --any-change still sees it
sed -i 's/category: Finance/category: Office/' "$app/flatpark.yml"
printf '  upstream_approved: true\n' >> "$app/flatpark.yml"
snap catalog-edit
assert_eq "$(changed)" ""
assert_eq "$("$tmp/scripts/changed-apps.sh" --any-change "$base" HEAD)" "io.flatpark.TestOne"

# 2. build block edit in the descriptor -> rebuild
sed -i 's/branch: stable/branch: beta/' "$app/flatpark.yml"
snap branch-edit
assert_eq "$(changed)" "io.flatpark.TestOne"

# 3. version pin bump in the manifest -> rebuild
g reset -q --hard "$base"
sed -i 's/app-1.0.deb/app-1.1.deb/' "$app/io.flatpark.TestOne.yml"
snap pin-bump
assert_eq "$(changed)" "io.flatpark.TestOne"

# 4. deleted app -> ignored (prune's job), even as the only/last diff entry
g reset -q --hard "$base"
g rm -rq registry/io.flatpark.TestOne
snap delete-app
assert_eq "$(changed)" ""

echo "test_changed_apps: PASS"
