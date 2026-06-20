#!/usr/bin/env bash
# Print the app ids whose registry/<id>/ directory changed between two git refs,
# limited to apps that still exist (a deleted app is handled by prune, not build).
# Usage: changed-apps.sh <base-ref> [head-ref]
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
need git
base="${1:?usage: changed-apps.sh <base-ref> [head-ref]}"
head="${2:-HEAD}"

git -C "$ROOT" diff --name-only "$base" "$head" -- registry/ \
    | sed -nE 's#^registry/([^/]+)/.*#\1#p' \
    | sort -u \
    | while IFS= read -r id; do
        [ -f "$REGISTRY_DIR/$id/flatpark.yml" ] && printf '%s\n' "$id"
      done
