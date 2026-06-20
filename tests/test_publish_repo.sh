#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
command -v ostree >/dev/null || { echo "test_publish_repo: SKIP (no ostree)"; exit 0; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
env_common=(OUT_DIR="$tmp/out" GNUPGHOME_DIR="$tmp/gnupg")

env "${env_common[@]}" "$ROOT/scripts/gen-signing-key.sh" >/dev/null

repo="$tmp/repo"
ostree --repo="$repo" init --mode=archive-z2
mkdir -p "$tmp/tree/files"; echo hi > "$tmp/tree/files/x"
ostree --repo="$repo" commit --branch=app/test.App/x86_64/stable --subject=t "$tmp/tree" >/dev/null

env "${env_common[@]}" "$ROOT/scripts/publish-repo.sh" "$repo"
assert_file "$repo/summary"
assert_file "$repo/summary.sig"
echo "test_publish_repo: PASS"
