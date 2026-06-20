#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
command -v node >/dev/null 2>&1 || { echo "test_check_links: SKIP (no node)"; exit 0; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
data="$tmp/data"; mkdir -p "$data/apps"

# App with no external URLs -> nothing to check.
cat > "$data/apps/io.flatpark.NoLinks.json" <<'EOF'
{ "id": "io.flatpark.NoLinks", "name": "No Links", "screenshots": [], "website": "", "urls": {}, "sourceUrl": "" }
EOF
# App with one dead URL (refused localhost port) -> exercises the broken path
# hermetically, no external network.
cat > "$data/apps/io.flatpark.BadLink.json" <<'EOF'
{ "id": "io.flatpark.BadLink", "name": "Bad Link", "screenshots": [{ "url": "http://127.0.0.1:9/missing.png" }], "website": "", "urls": {}, "sourceUrl": "" }
EOF

# Broken link present -> exit 1, broken count 1.
set +e
out="$(FLATPARK_DATA_DIR="$data" LINK_CHECK_TIMEOUT_MS=2000 node "$ROOT/site/tools/check-links.mjs" --json)"
rc=$?
set -e
[ "$rc" -eq 1 ] || { echo "FAIL: expected exit 1 with a dead link, got $rc"; exit 1; }
printf '%s' "$out" | node -e 'const d=JSON.parse(require("fs").readFileSync(0,"utf8")); if(d.checked!==1||d.broken!==1){console.error("checked="+d.checked+" broken="+d.broken);process.exit(1)}'

# All-clean data dir -> exit 0.
rm "$data/apps/io.flatpark.BadLink.json"
assert_ok env FLATPARK_DATA_DIR="$data" node "$ROOT/site/tools/check-links.mjs"
echo "test_check_links: PASS"
