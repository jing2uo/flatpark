#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
command -v node >/dev/null 2>&1 || { echo "test_update_pins: SKIP (no node)"; exit 0; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

printf 'OLD-CONTENT' > "$tmp/old.bin"
printf 'NEW-CONTENT-LONGER' > "$tmp/new.bin"
old_sha="$(sha256sum "$tmp/old.bin" | cut -d' ' -f1)"; old_size="$(wc -c < "$tmp/old.bin")"
new_sha="$(sha256sum "$tmp/new.bin" | cut -d' ' -f1)"; new_size="$(wc -c < "$tmp/new.bin")"

mk_manifest() { # <url> <sha> <size>
cat > "$tmp/manifest.yml" <<EOF
modules:
  - name: app
    sources:
      # BEGIN MANAGED EXTRA-DATA
      - type: extra-data
        filename: app.bin
        only-arches:
          - x86_64
        url: $1
        sha256: $2
        size: $3
      # END MANAGED EXTRA-DATA
EOF
}
mk_metainfo() { # <version>
cat > "$tmp/app.metainfo.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>io.flatpark.Up</id>
  <name>Up</name>
  <releases>
    <release version="$1" date="2026-01-01" />
  </releases>
</component>
EOF
}
RC=0; OUT=""
run() { # <resolver-json> -> sets RC/OUT (called directly, not piped, so globals stick)
  set +e
  OUT="$(printf '%s' "$1" | node "$ROOT/scripts/update-pins.mjs" "$tmp/manifest.yml" "$tmp/app.metainfo.xml")"
  RC=$?
  set -e
}

# 1) version unchanged -> exit 10, nothing rewritten (no download even attempted).
mk_manifest "file://$tmp/old.bin" "$old_sha" "$old_size"
mk_metainfo "1.0"
run "$(printf '{"version":"1.0","sources":[{"filename":"app.bin","url":"file://%s/old.bin"}]}' "$tmp")"
assert_eq "$RC" "10"

# 2) version bump -> exit 0, pins refreshed from the new source, release prepended.
run "$(printf '{"version":"2.0","releaseDate":"2026-02-02","sources":[{"filename":"app.bin","url":"file://%s/new.bin"}]}' "$tmp")"
assert_eq "$RC" "0"
assert_eq "$OUT" "2.0"
assert_contains "$tmp/manifest.yml" "url: file://$tmp/new.bin"
assert_contains "$tmp/manifest.yml" "sha256: $new_sha"
assert_contains "$tmp/manifest.yml" "size: $new_size"
assert_contains "$tmp/app.metainfo.xml" "<release version=\"2.0\" date=\"2026-02-02\" />"
# the new release must be first (newest-first), old one retained
first_ver="$(grep -oE 'release version="[^"]*"' "$tmp/app.metainfo.xml" | head -1)"
assert_eq "$first_ver" 'release version="2.0"'
assert_contains "$tmp/app.metainfo.xml" "<release version=\"1.0\""

# 3) re-running the same resolver is now a no-op (anchor moved to 2.0).
run "$(printf '{"version":"2.0","releaseDate":"2026-02-02","sources":[{"filename":"app.bin","url":"file://%s/new.bin"}]}' "$tmp")"
assert_eq "$RC" "10"

echo "test_update_pins: PASS"
