#!/usr/bin/env bash
# check-apply-extra.sh must reject an apply_extra.sh that unpacks without
# --no-same-owner, and accept the same script once the flag is there.
#
# Hermetic: the payload is a zip we build here carrying an Info-ZIP 0x7875
# extra field with uid/gid 1001 — exactly what a CI-built release archive looks
# like — and it is served over file://, so the test never hits the network.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"

command -v flatpak >/dev/null || { echo "test_check_apply_extra: SKIP (no flatpak)"; exit 0; }
command -v bwrap   >/dev/null || { echo "test_check_apply_extra: SKIP (no bwrap)"; exit 0; }
command -v python3 >/dev/null || { echo "test_check_apply_extra: SKIP (no python3)"; exit 0; }
flatpak info --show-location org.freedesktop.Platform//25.08 >/dev/null 2>&1 \
    || { echo "test_check_apply_extra: SKIP (no org.freedesktop.Platform//25.08)"; exit 0; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
id="io.flatpark.ApplyExtra"
app="$tmp/registry/$id"
mkdir -p "$app"

# A zip whose members record uid=gid=1001, like any archive built on CI without
# fakeroot. Under uid 0 an unpacker restores that ownership unless told not to.
python3 - "$tmp/payload.zip" <<'PY'
import struct, sys, zipfile
def unix_uid_gid(uid, gid):
    body = b'\x01' + b'\x02' + struct.pack('<H', uid) + b'\x02' + struct.pack('<H', gid)
    return struct.pack('<HH', 0x7875, len(body)) + body
with zipfile.ZipFile(sys.argv[1], 'w') as z:
    for name in ('payload.txt', 'nested/other.txt'):
        zi = zipfile.ZipInfo(name)
        zi.external_attr = 0o100644 << 16
        zi.extra = unix_uid_gid(1001, 1001)
        z.writestr(zi, 'x')
PY
sha="$(sha256sum "$tmp/payload.zip" | cut -d' ' -f1)"

cat >"$app/flatpark.yml" <<EOF
id: $id
name: Apply Extra
summary: Synthetic apply_extra fixture
build:
  manifest: $id.yml
  branch: stable
  mode: extra-data
catalog:
  category: Utilities
EOF

cat >"$app/$id.yml" <<EOF
id: $id
runtime: org.freedesktop.Platform
runtime-version: '25.08'
sdk: org.freedesktop.Sdk
command: apply-extra
modules:
  - name: apply-extra
    buildsystem: simple
    build-commands:
      - install -Dm755 apply_extra.sh /app/bin/apply_extra
    sources:
      - type: extra-data
        filename: payload.zip
        only-arches:
          - $(flatpak --default-arch)
        url: file://$tmp/payload.zip
        sha256: $sha
        size: $(stat -c%s "$tmp/payload.zip")
EOF

write_apply() {  # $1 = extra bsdtar flags
    cat >"$app/apply_extra.sh" <<EOF
#!/bin/sh
set -eu
cd "\${EXTRA_ROOT:-/app/extra}"
rm -rf out; mkdir out
bsdtar $1 -xf payload.zip -C out
rm -f payload.zip
EOF
}

run_check() { env REGISTRY_DIR="$tmp/registry" "$ROOT/scripts/check-apply-extra.sh" "$id" >"$tmp/log" 2>&1; }

# 1. Without the flag the unpack must be rejected: bsdtar cannot chown to 1001
#    as an uncapable root, and exits nonzero after extracting everything.
write_apply ""
if run_check; then
    echo "FAIL: check-apply-extra accepted an unpack without --no-same-owner"
    cat "$tmp/log"; exit 1
fi
assert_contains "$tmp/log" "--no-same-owner"

# 2. With the flag it must pass.
write_apply "--no-same-owner"
if ! run_check; then
    echo "FAIL: check-apply-extra rejected a correct unpack"
    cat "$tmp/log"; exit 1
fi
assert_contains "$tmp/log" "apply_extra OK"

# 3. An app with no apply_extra.sh is skipped, not failed.
rm "$app/apply_extra.sh"
sed -i 's#install -Dm755 apply_extra.sh /app/bin/apply_extra#true#' "$app/$id.yml"
assert_ok run_check
assert_contains "$tmp/log" "nothing to check"

echo "test_check_apply_extra: PASS"
