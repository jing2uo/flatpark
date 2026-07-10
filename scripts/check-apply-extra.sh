#!/usr/bin/env bash
# Run an app's apply_extra.sh the way a *system-wide* install runs it: as root,
# with every capability dropped, offline, against the real pinned artifact.
#
# Why this exists. `flatpak install` (system) executes apply_extra under
# flatpak-system-helper as root with `--cap-drop ALL`, so the script cannot
# chown to whatever uid the upstream archive happens to record. bsdtar and tar
# both restore ownership by default under uid 0; the resulting EPERM is fatal
# under `set -e` even though every member extracted correctly, and the user sees
# only `apply_extra script failed, exit status 256` (512 for GNU tar) with the
# real message buried in the system helper's journal.
#
# Nothing else in CI reaches this code path: build-app.sh only *builds*, and
# extra-data is fetched at install time, so a green build says nothing about
# whether the app can actually be installed system-wide. A `--user` install
# won't catch it either — there the script runs as the invoking user and
# ownership is never restored.
#
# This does not need root itself: `bwrap --unshare-user --uid 0` gives an
# unprivileged user namespace whose root has no capabilities over the host, and
# a chown to an unmapped uid fails there just as a dropped CAP_CHOWN does under
# the real system helper (EINVAL rather than EPERM; same failure branch in
# libarchive and tar).
#
# Usage: check-apply-extra.sh <app-id>...
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
need flatpak; need bwrap; need curl; need sha256sum; need node

[ "$#" -gt 0 ] || die "usage: check-apply-extra.sh <app-id>..."

arch="$(flatpak --default-arch)"

check_one() {
    load_app "$1"
    local apply="$APP_SRC/apply_extra.sh"
    if [ ! -f "$apply" ]; then
        log "$APP_ID: no apply_extra.sh, nothing to check"
        return 0
    fi

    local runtime="" runtime_version="" sources=() kind a b c
    while IFS=$'\t' read -r kind a b c; do
        case "$kind" in
            runtime) runtime="$a"; runtime_version="$b" ;;
            extra)   sources+=("$a"$'\t'"$b"$'\t'"$c") ;;
        esac
    done < <(node "$ROOT/scripts/read-extra-data.mjs" "$MANIFEST" "$arch")

    if [ "${#sources[@]}" -eq 0 ]; then
        log "$APP_ID: no extra-data for $arch, nothing to check"
        return 0
    fi

    # The runtime must already be installed; apply_extra runs against its /usr.
    local loc files
    loc="$(flatpak info --show-location "$runtime//$runtime_version" 2>/dev/null)" \
        || die "$APP_ID: runtime not installed: $runtime//$runtime_version"
    files="$loc/files"
    [ -d "$files" ] || die "$APP_ID: runtime has no files dir: $files"

    # check_one always runs in a subshell, so an EXIT trap is scoped to this app
    # and still fires on the `die` paths below. The log lives outside $work:
    # apply_extra deletes the extra-data it consumed, and would take the log too.
    local work log_file
    work="$(mktemp -d)"
    log_file="$(mktemp)"
    # shellcheck disable=SC2064
    trap "rm -rf '$work' '$log_file'" EXIT

    local src filename url want got
    for src in "${sources[@]}"; do
        IFS=$'\t' read -r filename url want <<<"$src"
        log "$APP_ID: fetching $filename"
        curl -fsSL --retry 3 --max-time 900 -o "$work/$filename" "$url" \
            || die "$APP_ID: download failed: $url"
        got="$(sha256sum "$work/$filename" | cut -d' ' -f1)"
        [ "$got" = "$want" ] || die "$APP_ID: sha256 mismatch for $filename (pinned $want, got $got)"
    done

    cp "$apply" "$work/apply_extra.sh"

    # Mirror flatpak's apply_extra sandbox: uid 0, no caps, no network, no /proc
    # (flatpak passes FLATPAK_RUN_FLAG_NO_PROC there), runtime at /usr, the
    # extra-data dir bound read-write at /app/extra.
    local rc=0
    bwrap \
        --unshare-user --unshare-pid --unshare-net --die-with-parent \
        --uid 0 --gid 0 --cap-drop ALL \
        --ro-bind "$files" /usr \
        --symlink usr/bin /bin --symlink usr/sbin /sbin \
        --symlink usr/lib /lib --symlink usr/lib64 /lib64 \
        --bind "$work" /app/extra --chdir /app/extra \
        --dev /dev --tmpfs /tmp \
        /bin/sh -c 'sh /app/extra/apply_extra.sh' >"$log_file" 2>&1 || rc=$?

    if [ "$rc" -ne 0 ]; then
        # A chown failure names every member; the tail is enough to identify it.
        warn "$APP_ID: last lines of apply_extra output:"
        tail -n 20 "$log_file" | sed 's/^/    /' >&2
        die "$APP_ID: apply_extra failed under a system-wide install (exit $rc; flatpak would report 'exit status $((rc * 256))'). If it unpacks an archive, it must do so with --no-same-owner."
    fi
    log "$APP_ID: apply_extra OK as root with no capabilities"
}

# Each app in its own subshell so load_app's globals and the tmpdir trap don't
# leak between them — and so one failure still reports the rest.
fail=0
for id in "$@"; do
    ( check_one "$id" ) || fail=1
done
exit "$fail"
