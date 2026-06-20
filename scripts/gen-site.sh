#!/usr/bin/env bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
need node
need npm

: "${SITE_DIR:=$ROOT/site}"

# 1. Registry -> catalog.json + base apps/<id>.json (+ icons).
"$ROOT/scripts/gen-apps-json.sh" "$@"

# 2. Install site deps once (enrichment + build both need them).
if [ ! -d "$SITE_DIR/node_modules" ]; then
    log "installing site dependencies"
    ( cd "$SITE_DIR" && npm install --no-audit --no-fund )
fi

# 3. Enrich each app file from the developer repo (manifest/metainfo/flatpark.yml).
( cd "$SITE_DIR" && node tools/enrich.mjs )

# 4. Build the static site into PAGES_DIR.
log "building site -> $PAGES_DIR"
( cd "$SITE_DIR" && SITE_OUT_DIR="$PAGES_DIR" npm run build )

# Keep R2 lean: publish only what must be self-hosted. Detail pages are
# pre-rendered, so the per-app JSON is build-time only — strip it from the
# output. catalog.json stays (drives client-side search). Screenshots are
# hotlinked from upstream, never stored here.
rm -f "$PAGES_DIR/apps/"*.json
# Astro's content layer leaves empty module stubs in the output root; they are
# never linked from any page, so drop them from the published tree.
rm -f "$PAGES_DIR/content-assets.mjs" "$PAGES_DIR/content-modules.mjs"
log "wrote $PAGES_DIR"
