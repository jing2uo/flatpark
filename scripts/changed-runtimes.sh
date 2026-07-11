#!/usr/bin/env bash
# Print registered runtime ids changed between two git refs.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
need git
base="${1:?usage: changed-runtimes.sh <base-ref> [head-ref]}"
head="${2:-HEAD}"

git -C "$ROOT" diff --name-only "$base" "$head" -- runtimes/ \
    | sed -nE 's#^runtimes/([^/]+)/.*#\1#p' \
    | sort -u \
    | while IFS= read -r id; do
        [ -f "$RUNTIMES_DIR/$id/runtime.conf" ] && printf '%s\n' "$id"
      done
