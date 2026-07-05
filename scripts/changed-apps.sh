#!/usr/bin/env bash
# Print the app ids whose registry/<id>/ changed between two git refs in a way
# that affects the built flatpak, limited to apps that still exist (a deleted
# app is handled by prune, not build).
#
# A change to a build-relevant file rebuilds: the manifest carries the
# extra-data version pins and build commands, and the wrappers, apply_extra.sh
# and the .desktop file are baked into the artifact and change how it runs.
# Inside flatpark.yml only `id` and the `build:` block feed the build;
# name/summary/catalog/policy edits feed the site and discovery files, which
# every publish regenerates for the full catalog anyway — no rebuild.
#
# Display-only files are NOT rebuild triggers even though they are baked into
# the flatpak too: the AppStream metainfo, the icon, and screenshot assets feed
# the website, which every publish regenerates in full. The site is the primary
# catalog, so a cosmetic edit reaches flatpark.org on the next publish without
# pushing a needless `flatpak update` to installed apps; the remote's baked
# appstream refreshes whenever the app next rebuilds for a real reason.
# With --any-change, ANY file change in the app dir counts (still limited to
# apps that exist) — for consumers that care about site-facing edits too, like
# the PR dead-link check.
# Usage: changed-apps.sh [--any-change] <base-ref> [head-ref]
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
need git
any_change=0
if [ "${1:-}" = "--any-change" ]; then
    any_change=1
    shift
fi
base="${1:?usage: changed-apps.sh [--any-change] <base-ref> [head-ref]}"
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
        if [ "$any_change" = "1" ]; then
            printf '%s\n' "$id"
            continue
        fi
        # No grep -q here: with pipefail, grep -q closing the pipe early can
        # fail the whole pipeline on SIGPIPE even when it matched.
        # Drop the descriptor and the display-only assets (metainfo/appdata,
        # icon, screenshots at any depth); what's left is build-relevant.
        non_descriptor="$(git -C "$ROOT" diff --name-only "$base" "$head" -- "registry/$id/" \
            | grep -vE "^registry/$id/(flatpark\.yml|[^/]+\.(metainfo|appdata)\.xml)\$|^registry/$id/.*\.(png|svg|webp|jpe?g|gif)\$" \
            || true)"
        if [ -n "$non_descriptor" ]; then
            printf '%s\n' "$id"
            continue
        fi
        # Descriptor-only change: rebuild only if the build-relevant part moved.
        if [ "$(build_view "$base" "$id")" != "$(build_view "$head" "$id")" ]; then
            printf '%s\n' "$id"
        fi
      done
