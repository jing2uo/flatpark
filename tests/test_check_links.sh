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

rm "$data/apps/io.flatpark.BadLink.json"

# A transport-level error (connection reset) is retried before it is believed,
# and a host on the soft-OK list is waived entirely. A local server that resets
# every connection produces ECONNRESET without leaving the machine; it logs one
# line per connection so the retries are observable rather than assumed.
cat > "$tmp/reset-server.mjs" <<'EOF'
import { createServer } from 'node:net';
import { appendFileSync, writeFileSync } from 'node:fs';
const log = process.argv[2];
writeFileSync(log, '');
const srv = createServer((s) => { appendFileSync(log, 'conn\n'); s.destroy(); });
srv.listen(0, '127.0.0.1', () => console.log(srv.address().port));
EOF
# Read the port the server chose, keep it running in the background.
node "$tmp/reset-server.mjs" "$tmp/conns" > "$tmp/port" &
srv_pid=$!
trap 'kill "$srv_pid" 2>/dev/null || true; rm -rf "$tmp"' EXIT
for _ in $(seq 50); do [ -s "$tmp/port" ] && break; sleep 0.1; done
port="$(cat "$tmp/port")"
[ -n "$port" ] || { echo "FAIL: reset server did not report a port"; exit 1; }

cat > "$data/apps/io.flatpark.Reset.json" <<EOF
{ "id": "io.flatpark.Reset", "name": "Reset", "screenshots": [], "website": "http://127.0.0.1:$port/", "urls": {}, "sourceUrl": "" }
EOF

# No retries: still broken, and the probe opens 2 connections (HEAD, then GET).
set +e
out="$(FLATPARK_DATA_DIR="$data" LINK_CHECK_RETRIES=0 node "$ROOT/site/tools/check-links.mjs" --json)"
rc=$?
set -e
[ "$rc" -eq 1 ] || { echo "FAIL: expected exit 1 on a reset connection, got $rc"; exit 1; }
printf '%s' "$out" | node -e 'const d=JSON.parse(require("fs").readFileSync(0,"utf8")); if(d.broken!==1){console.error("broken="+d.broken);process.exit(1)}'
base="$(wc -l < "$tmp/conns")"

# Two retries: the same URL is probed again, so strictly more connections.
: > "$tmp/conns"
set +e
FLATPARK_DATA_DIR="$data" LINK_CHECK_RETRIES=2 node "$ROOT/site/tools/check-links.mjs" >/dev/null
set -e
retried="$(wc -l < "$tmp/conns")"
[ "$retried" -gt "$base" ] || { echo "FAIL: retries did not re-probe ($retried <= $base)"; exit 1; }

# Same failure on a soft-OK host -> reachable-but-skipped warning, exit 0.
out="$(FLATPARK_DATA_DIR="$data" LINK_CHECK_RETRIES=0 LINK_CHECK_SOFT_OK_HOSTS=127.0.0.1 \
  node "$ROOT/site/tools/check-links.mjs" --json)"
printf '%s' "$out" | node -e 'const d=JSON.parse(require("fs").readFileSync(0,"utf8")); if(d.broken!==0||d.warned!==1){console.error("broken="+d.broken+" warned="+d.warned);process.exit(1)}'

# A refused connection means the host answered and the port is closed, so it is
# not in NET_ERRORS: the soft-OK list must not waive it.
kill "$srv_pid" 2>/dev/null; wait "$srv_pid" 2>/dev/null || true
cat > "$data/apps/io.flatpark.Reset.json" <<'EOF'
{ "id": "io.flatpark.Reset", "name": "Reset", "screenshots": [], "website": "http://127.0.0.1:9/gone", "urls": {}, "sourceUrl": "" }
EOF
set +e
FLATPARK_DATA_DIR="$data" LINK_CHECK_RETRIES=0 LINK_CHECK_SOFT_OK_HOSTS=127.0.0.1 \
  node "$ROOT/site/tools/check-links.mjs" >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 1 ] || { echo "FAIL: refused connection on a soft-OK host should stay broken, got $rc"; exit 1; }

# All-clean data dir -> exit 0.
rm "$data/apps/io.flatpark.Reset.json"
assert_ok env FLATPARK_DATA_DIR="$data" node "$ROOT/site/tools/check-links.mjs"
echo "test_check_links: PASS"
