#!/usr/bin/env bash
# Print registered FlatPark runtime ids, one per line.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"

requested=("$@")
if [ "${#requested[@]}" -eq 0 ]; then
    requested=()
    for record in "$RUNTIMES_DIR"/*/runtime.conf; do
        [ -e "$record" ] || exit 0
        requested+=("$(basename "$(dirname "$record")")")
    done
fi

for id in "${requested[@]}"; do
    load_runtime "$id"
    printf '%s\n' "$RUNTIME_ID"
done
