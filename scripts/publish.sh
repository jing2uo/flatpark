#!/usr/bin/env bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
verify=0
requested_apps=()
for arg in "$@"; do
    case "$arg" in
        --verify) verify=1 ;;
        *) requested_apps+=("$arg") ;;
    esac
done

apps=()
while IFS= read -r app_id; do
    apps+=("$app_id")
done < <("$ROOT/scripts/scan-registry.sh" --ids "${requested_apps[@]}")
[ "${#apps[@]}" -gt 0 ] || die "registry scan returned no apps"

"$ROOT/scripts/gen-signing-key.sh" >/dev/null
for app_id in "${apps[@]}"; do
    "$ROOT/scripts/build-app.sh" "$app_id"
done
"$ROOT/scripts/publish-repo.sh"
for app_id in "${apps[@]}"; do
    "$ROOT/scripts/gen-discovery.sh" "$app_id"
done
"$ROOT/scripts/gen-site.sh" "${apps[@]}"
log "publish complete -> $OUT_DIR"

if [ "$verify" = "1" ]; then
    need flatpak
    remote="$VERIFY_REMOTE_NAME"
    remote_url="file://$REPO_DIR"
    remote_args=(--title="$REPO_TITLE" --comment="$REPO_COMMENT"
        --homepage="$REPO_HOMEPAGE" --gpg-import="$PUBKEY_FILE")
    if flatpak --user remotes | awk '{print $1}' | grep -qxF "$remote"; then
        flatpak --user remote-modify --url="$remote_url" "${remote_args[@]}" "$remote"
    else
        flatpak --user remote-add "${remote_args[@]}" "$remote" "$remote_url"
    fi
    for app_id in "${apps[@]}"; do
        flatpak --user install -y "$remote" "$app_id"
        log "verify: installed $app_id from local signed repo OK"
    done
fi
