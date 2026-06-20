#!/usr/bin/env bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
need flatpak; need gpg
export GNUPGHOME="$GNUPGHOME_DIR"
repo="${1:-$REPO_DIR}"
[ -d "$repo" ] || die "repo dir not found: $repo"
fpr="$(gpg --list-keys --with-colons "$KEY_EMAIL" | awk -F: '/^fpr:/{print $10; exit}')"
[ -n "$fpr" ] || die "no signing key (run gen-signing-key.sh)"
flatpak build-update-repo --gpg-sign="$fpr" --gpg-homedir="$GNUPGHOME_DIR" "$repo"
[ -f "$repo/summary.sig" ] || die "summary.sig not produced"
log "summary refreshed and signed in $repo"
