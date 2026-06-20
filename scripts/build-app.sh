#!/usr/bin/env bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
load_app "${1:?usage: build-app.sh <app-id>}"
need flatpak; need flatpak-builder; need gpg
export GNUPGHOME="$GNUPGHOME_DIR"
[ -f "$MANIFEST" ] || die "manifest not found: $MANIFEST"
fpr="$(gpg --list-keys --with-colons "$KEY_EMAIL" | awk -F: '/^fpr:/{print $10; exit}')"
[ -n "$fpr" ] || die "no signing key (run gen-signing-key.sh)"
mkdir -p "$OUT_DIR"
build_dir="$OUT_DIR/build-$APP_ID"
state_dir="$OUT_DIR/flatpak-builder-state"

args=(--force-clean --repo="$REPO_DIR" --default-branch="$APP_BRANCH"
      --state-dir="$state_dir"
      --gpg-sign="$fpr" --gpg-homedir="$GNUPGHOME_DIR")
[ -e /dev/fuse ] || args+=(--disable-rofiles-fuse)
if [ -n "${RUNTIME_REPO_URL:-}" ]; then
    flatpak --user remote-add --if-not-exists --from "$RUNTIME_REMOTE_NAME" "$RUNTIME_REPO_URL" || true
    args+=(--install-deps-from="$RUNTIME_REMOTE_NAME" --user)
fi

( cd "$APP_SRC" && flatpak-builder "${args[@]}" "$build_dir" "$MANIFEST" )
log "built $APP_ID into $REPO_DIR"
