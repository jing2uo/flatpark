#!/usr/bin/env bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
load_app "${1:?usage: gen-discovery.sh <app-id>}"
need gpg; need base64
export GNUPGHOME="$GNUPGHOME_DIR"
mkdir -p "$OUT_DIR" "$REPO_DIR"
gpgkey_b64="$(gpg --export "$KEY_EMAIL" | base64 -w0)"
[ -n "$gpgkey_b64" ] || die "no exportable key (run gen-signing-key.sh first)"

repo_file="$REPO_DIR/flatpark.flatpakrepo"
ref_file="$REPO_DIR/$APP_ID.flatpakref"

cat > "$repo_file" <<EOF
[Flatpak Repo]
Title=$REPO_TITLE
Url=$REPO_URL
Homepage=$REPO_HOMEPAGE
Comment=$REPO_COMMENT
GPGKey=$gpgkey_b64
EOF

# SuggestRemoteName pins the auto-added remote to our canonical name; without
# it flatpak derives one from the ref (e.g. "tabby-origin") and every
# documented `flatpak install flatpark <id>` command misses for that user.
cat > "$ref_file" <<EOF
[Flatpak Ref]
Name=$APP_ID
Branch=$APP_BRANCH
Title=$APP_NAME
Url=$REPO_URL
SuggestRemoteName=$REMOTE_NAME
RuntimeRepo=$RUNTIME_REPO_URL
GPGKey=$gpgkey_b64
IsRuntime=false
EOF
cp "$repo_file" "$OUT_DIR/flatpark.flatpakrepo"
cp "$ref_file" "$OUT_DIR/$APP_ID.flatpakref"
log "wrote flatpark.flatpakrepo and $APP_ID.flatpakref"
