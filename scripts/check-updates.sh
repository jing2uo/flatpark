#!/usr/bin/env bash
# Run each app's update resolver, recompute its extra-data pins + metainfo
# release, and rewrite them in place. Prints the ids of apps that changed (one
# per line) — the update workflow turns those into a PR.
# Does NOT commit or open a PR itself.
#
# Usage: check-updates.sh [app-id ...]   (default: every app with an update cmd)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
need node

apps=()
while IFS= read -r id; do apps+=("$id"); done < <("$ROOT/scripts/scan-registry.sh" --ids "$@")
[ "${#apps[@]}" -gt 0 ] || die "registry scan returned no apps"

changed=()
for id in "${apps[@]}"; do
    load_app "$id"
    [ -n "${APP_UPDATE_COMMAND:-}" ] || { log "$id: no update command, skipping"; continue; }
    [ -f "$MANIFEST" ] || { warn "$id: manifest not found ($MANIFEST)"; continue; }

    log "$id: resolving via $APP_UPDATE_COMMAND"
    if ! resolver_json="$( cd "$APP_SRC" && eval "$APP_UPDATE_COMMAND" )"; then
        warn "$id: resolver failed"; continue
    fi

    metainfo="$APP_SRC/$APP_ID.metainfo.xml"
    set +e
    version="$(printf '%s' "$resolver_json" | node "$ROOT/scripts/update-pins.mjs" "$MANIFEST" "$metainfo")"
    rc=$?
    set -e
    case "$rc" in
        0)  log "$id: pins updated -> ${version:-?}"; changed+=("$id") ;;
        10) log "$id: up to date" ;;
        *)  warn "$id: update-pins failed (exit $rc)" ;;
    esac
done

printf '%s\n' "${changed[@]}"
