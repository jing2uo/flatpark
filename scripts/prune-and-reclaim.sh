#!/usr/bin/env bash
# Reclaim repo space with prune-diff targeted deletes (never a blind mirror):
#   1. delete refs for apps no longer in the registry (delist),
#   2. prune to the current commit of every remaining ref (keep current only —
#      fix forward, no rollback retention),
#   3. write the exact set of objects pruning removed to a reclaim list.
#
# The caller then re-signs the summary (publish-repo.sh) and runs sync-r2.sh
# with RECLAIM_LIST pointed at the file written here, so the new summary goes
# live BEFORE the orphaned objects are deleted from R2.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
need ostree
repo="${1:-$REPO_DIR}"
[ -d "$repo/objects" ] || die "not an ostree repo: $repo"
mkdir -p "$OUT_DIR"
reclaim="${RECLAIM_LIST:-$OUT_DIR/reclaim-objects.txt}"

# 1. Delist: drop app/<id> refs whose registry entry is gone.
ostree --repo="$repo" refs | while IFS= read -r ref; do
    case "$ref" in
        app/*)
            id="${ref#app/}"; id="${id%%/*}"
            if [ ! -f "$REGISTRY_DIR/$id/flatpark.yml" ]; then
                log "delist: removing ref $ref (no registry entry)"
                ostree --repo="$repo" refs --delete "$ref"
            fi
            ;;
    esac
done

before="$(mktemp)"; after="$(mktemp)"
trap 'rm -f "$before" "$after"' EXIT
( cd "$repo" && find objects -type f 2>/dev/null | sort ) > "$before"

# 2. Keep only the current commit of each ref.
log "pruning to current commit (depth=0, refs-only)"
ostree --repo="$repo" prune --refs-only --depth=0 >&2

( cd "$repo" && find objects -type f 2>/dev/null | sort ) > "$after"

# 3. removed = before - after => the orphaned objects to delete from R2.
comm -23 "$before" "$after" > "$reclaim"
removed_n="$(wc -l < "$reclaim" | tr -d ' ')"
before_n="$(wc -l < "$before" | tr -d ' ')"
log "reclaim: $removed_n of $before_n object(s) pruned -> $reclaim"
printf '%s\n' "$reclaim"
