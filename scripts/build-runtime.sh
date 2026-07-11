#!/usr/bin/env bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
load_runtime "${1:?usage: build-runtime.sh <runtime-id>}"
need flatpak; need flatpak-builder; need git; need gpg
export GNUPGHOME="$GNUPGHOME_DIR"
fpr="$(gpg --list-keys --with-colons "$KEY_EMAIL" | awk -F: '/^fpr:/{print $10; exit}')"
[ -n "$fpr" ] || die "no signing key (run gen-signing-key.sh)"

mkdir -p "$OUT_DIR"
src="$OUT_DIR/runtime-src-$RUNTIME_ID"
build_dir="$OUT_DIR/build-runtime-$RUNTIME_ID"
state_dir="$OUT_DIR/flatpak-builder-state"
rm -rf "$src"
git clone --quiet --no-checkout "$RUNTIME_REPOSITORY" "$src"
git -C "$src" checkout --quiet --detach "$RUNTIME_COMMIT"
[ "$(git -C "$src" rev-parse HEAD)" = "$RUNTIME_COMMIT" ] \
    || die "runtime checkout did not resolve to pinned commit"
[ -f "$src/$RUNTIME_MANIFEST" ] || die "runtime manifest not found: $RUNTIME_MANIFEST"

# A runtime manifest needs both its parent Platform and SDK installed.
flatpak --user install -y "$RUNTIME_REMOTE_NAME" \
    "org.freedesktop.Platform//$RUNTIME_BRANCH" \
    "org.freedesktop.Sdk//$RUNTIME_BRANCH"

args=(--force-clean --repo="$REPO_DIR" --state-dir="$state_dir"
      --gpg-sign="$fpr" --gpg-homedir="$GNUPGHOME_DIR")
[ -e /dev/fuse ] || args+=(--disable-rofiles-fuse)
( cd "$src" && flatpak-builder "${args[@]}" "$build_dir" "$RUNTIME_MANIFEST" )
log "built $RUNTIME_ID and $RUNTIME_SDK_ID into $REPO_DIR"
