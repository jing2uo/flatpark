#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

fpr="$(OUT_DIR="$tmp/out" GNUPGHOME_DIR="$tmp/gnupg" "$ROOT/scripts/gen-signing-key.sh")"
assert_file "$tmp/out/flatpark.pub.asc"
assert_contains "$tmp/out/flatpark.pub.asc" "BEGIN PGP PUBLIC KEY BLOCK"
[ -n "$fpr" ] || { echo "FAIL: empty fingerprint"; exit 1; }

# idempotent: second run reuses the same key, same fingerprint
fpr2="$(OUT_DIR="$tmp/out" GNUPGHOME_DIR="$tmp/gnupg" "$ROOT/scripts/gen-signing-key.sh")"
assert_eq "$fpr2" "$fpr"
echo "test_gen_signing_key: PASS"
