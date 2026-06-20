#!/usr/bin/env bash
# Regenerate app data, then batch-check every external URL the site hotlinks.
# Exits non-zero if any link is broken. Usage:
#   scripts/check-links.sh [--json] [app-id ...]
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
need node
: "${SITE_DIR:=$ROOT/site}"

json=""
appids=()
for a in "$@"; do
    case "$a" in
        --json) json="--json" ;;
        *) appids+=("$a") ;;
    esac
done

"$ROOT/scripts/gen-apps-json.sh" ${appids[@]+"${appids[@]}"}

if [ ! -d "$SITE_DIR/node_modules" ]; then
    need npm
    ( cd "$SITE_DIR" && npm install --no-audit --no-fund )
fi

( cd "$SITE_DIR" && node tools/enrich.mjs )
( cd "$SITE_DIR" && node tools/check-links.mjs $json )
