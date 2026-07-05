#!/usr/bin/env bash
# Print the app ids whose registry/<id>/ changed between two git refs in a way
# that affects the built flatpak, limited to apps that still exist (a deleted
# app is handled by prune, not build).
#
# Any change to a non-descriptor file rebuilds: the manifest carries the
# extra-data version pins, and wrappers/metainfo/icons are baked into the
# artifact. Inside flatpark.yml only `id` and the `build:` block feed the
# build; name/summary/catalog/policy edits feed the site and discovery files,
# which every publish regenerates for the full catalog anyway — no rebuild.
# Usage: changed-apps.sh <base-ref> [head-ref]
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
need git
base="${1:?usage: changed-apps.sh <base-ref> [head-ref]}"
head="${2:-HEAD}"

# The build-relevant projection of a descriptor at a git rev: the id line plus
# the `build:` block, comments and blank lines dropped. Empty when the file
# does not exist at that rev.
build_view() {
    { git -C "$ROOT" show "$1:registry/$2/flatpark.yml" 2>/dev/null || true; } \
        | awk '
            /^id:/     { print; next }
            /^build:/  { inb = 1; print; next }
            /^[^ \t#]/ { inb = 0 }
            inb && NF && $1 !~ /^#/ { print }'
}

git -C "$ROOT" diff --name-only "$base" "$head" -- registry/ \
    | sed -nE 's#^registry/([^/]+)/.*#\1#p' \
    | sort -u \
    | while IFS= read -r id; do
        [ -f "$REGISTRY_DIR/$id/flatpark.yml" ] || continue
        # No grep -q here: with pipefail, grep -q closing the pipe early can
        # fail the whole pipeline on SIGPIPE even when it matched.
        non_descriptor="$(git -C "$ROOT" diff --name-only "$base" "$head" -- "registry/$id/" \
            | grep -v "^registry/$id/flatpark\.yml\$" || true)"
        if [ -n "$non_descriptor" ]; then
            printf '%s\n' "$id"
            continue
        fi
        # Descriptor-only change: rebuild only if the build-relevant part moved.
        if [ "$(build_view "$base" "$id")" != "$(build_view "$head" "$id")" ]; then
            printf '%s\n' "$id"
        fi
      done
