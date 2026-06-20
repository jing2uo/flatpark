#!/usr/bin/env bash
# Publish the local OSTree repo (REPO_DIR) + discovery files to R2 with rclone.
#
# Ordering matters: content-addressed objects go up FIRST (and are cached
# forever), the mutable `summary` pointer goes up LAST, so a client never reads
# a summary that references objects not yet uploaded. With RECLAIM_LIST set, the
# orphaned objects listed there are deleted AFTER the new summary is live (see
# prune-and-reclaim.sh).
#
# rclone must have an R2 (S3) remote configured; in CI that is done with
# RCLONE_CONFIG_<REMOTE>_* env vars. Required: R2_BUCKET. Optional: R2_REMOTE
# (default r2), RECLAIM_LIST.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
need rclone
repo="${1:-$REPO_DIR}"
[ -d "$repo" ] || die "repo dir not found: $repo"
remote="${R2_REMOTE:-r2}"
bucket="${R2_BUCKET:?set R2_BUCKET (the R2 bucket name)}"
dest="$remote:$bucket"

IMMUTABLE="Cache-Control: public, max-age=31536000, immutable"
MUTABLE="Cache-Control: public, max-age=0, must-revalidate"
FLAGS=(--fast-list --transfers=16 --checkers=32)

log "sync objects -> $dest (immutable)"
# Content-addressed: same name => same bytes, so --size-only is safe and fast.
rclone copy "$repo/objects" "$dest/objects" --size-only --header-upload "$IMMUTABLE" "${FLAGS[@]}"
[ -d "$repo/deltas" ] && rclone copy "$repo/deltas" "$dest/deltas" --size-only --header-upload "$IMMUTABLE" "${FLAGS[@]}"

log "sync refs/config/discovery -> $dest (revalidate)"
rclone copy "$repo/refs" "$dest/refs" --checksum --header-upload "$MUTABLE" "${FLAGS[@]}"
rclone copy "$repo" "$dest" --max-depth 1 --checksum --header-upload "$MUTABLE" "${FLAGS[@]}" \
    --include "config" --include "*.flatpakrepo" --include "*.flatpakref" --include "*.pub.asc"

log "sync summary -> $dest (LAST, revalidate)"
rclone copy "$repo" "$dest" --max-depth 1 --checksum --header-upload "$MUTABLE" "${FLAGS[@]}" \
    --include "summary" --include "summary.sig" --include "summary.idx"
[ -d "$repo/summaries" ] && rclone copy "$repo/summaries" "$dest/summaries" --checksum --header-upload "$MUTABLE" "${FLAGS[@]}"

if [ -n "${RECLAIM_LIST:-}" ] && [ -s "$RECLAIM_LIST" ]; then
    n="$(wc -l < "$RECLAIM_LIST")"
    log "reclaim: deleting $n orphaned object(s) from $dest"
    while IFS= read -r obj; do
        [ -n "$obj" ] || continue
        rclone deletefile "$dest/$obj" 2>/dev/null || warn "could not delete $obj (already gone?)"
    done < "$RECLAIM_LIST"
fi

log "R2 sync complete -> $dest"
