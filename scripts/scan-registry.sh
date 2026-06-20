#!/usr/bin/env bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"

ids_only=0
if [ "${1:-}" = "--ids" ]; then
    ids_only=1
    shift
fi

if [ "$#" -gt 0 ]; then
    apps=("$@")
else
    apps=()
    for record in "$REGISTRY_DIR"/*/flatpark.yml; do
        [ -e "$record" ] || die "no app registry entries in $REGISTRY_DIR"
        apps+=("$(basename "$(dirname "$record")")")
    done
fi

for app_id in "${apps[@]}"; do
    load_app "$app_id"
    if [ "$ids_only" = "1" ]; then
        printf '%s\n' "$APP_ID"
    else
        printf '%s\t%s\t%s\t%s\n' "$APP_ID" "$APP_BRANCH" "$UPDATE_MODE" "$MANIFEST"
    fi
done
