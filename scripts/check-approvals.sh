#!/usr/bin/env bash
# Keep the developer-approved shield auditable: every registry descriptor with
# catalog.upstream_approved: true must have an evidence row in the Approved
# table of docs/upstream-approvals.md. That direction is a hard error; a doc
# row without the flag (e.g. a withdrawal in progress) only warns.
# Usage: scripts/check-approvals.sh
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$ROOT/docs/upstream-approvals.md"

[ -f "$DOC" ] || { echo "::error::missing $DOC"; exit 1; }

# App ids flagged approved in the registry.
flagged="$(grep -l '^  upstream_approved: true$' "$ROOT"/registry/*/flatpark.yml 2>/dev/null \
             | sed 's|.*/registry/||; s|/flatpark.yml||' | sort)"

# App ids recorded in the doc's Approved table: rows between "## Approved" and
# the next section, second cell backtick-quoted.
recorded="$(awk '/^## Approved$/{on=1; next} /^## /{on=0} on' "$DOC" \
              | sed -n 's/^| [^|]* | `\([^`]*\)` |.*/\1/p' | sort)"

fail=0
for id in $flagged; do
    if ! grep -qx "$id" <<<"$recorded"; then
        echo "::error::registry/$id/flatpark.yml sets upstream_approved: true but docs/upstream-approvals.md has no Approved row for it — add the evidence link (see the doc header for what counts)"
        fail=1
    fi
done
for id in $recorded; do
    if ! grep -qx "$id" <<<"$flagged"; then
        echo "::warning::docs/upstream-approvals.md lists $id as Approved but registry/$id/flatpark.yml does not set upstream_approved: true — move the row to Not approved or flip the flag"
    fi
done

[ "$fail" -eq 0 ] && echo "approvals doc and registry flags are in sync ($(wc -w <<<"$flagged") approved apps)"
exit "$fail"
