#!/usr/bin/env bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
need gpg
mkdir -p "$GNUPGHOME_DIR" "$OUT_DIR"
chmod 700 "$GNUPGHOME_DIR"
export GNUPGHOME="$GNUPGHOME_DIR"

# Repo signing key structure:
#   master  = Certify-only (the long-term identity, the root of trust; in
#             production it is generated once, backed up offline, and never put
#             in CI).
#   subkey  = Sign-only (the operational key that actually signs the OSTree
#             repo; only its secret is shipped to CI via export-ci-subkey.sh).
# The signers pass the *master* fingerprint to gpg, which auto-selects the
# signing subkey (the master has no sign capability). KEY_PASSPHRASE is empty by
# default so local/CI signing is non-interactive; the offline master backup is
# protected by encrypting the backup file itself (see the launch checklist).
if ! gpg --list-keys "$KEY_EMAIL" >/dev/null 2>&1; then
    log "generating signing key (Certify master + signing subkey) for $KEY_EMAIL"
    gpg --batch --pinentry-mode loopback --passphrase "${KEY_PASSPHRASE:-}" \
        --quick-generate-key "$KEY_NAME <$KEY_EMAIL>" rsa4096 cert never
    master="$(gpg --list-keys --with-colons "$KEY_EMAIL" | awk -F: '/^fpr:/{print $10; exit}')"
    [ -n "$master" ] || die "failed to obtain master fingerprint"
    gpg --batch --pinentry-mode loopback --passphrase "${KEY_PASSPHRASE:-}" \
        --quick-add-key "$master" rsa4096 sign never
fi
fpr="$(gpg --list-keys --with-colons "$KEY_EMAIL" | awk -F: '/^fpr:/{print $10; exit}')"
[ -n "$fpr" ] || die "failed to obtain key fingerprint"
gpg --armor --export "$KEY_EMAIL" > "$PUBKEY_FILE"
log "public key -> $PUBKEY_FILE"
printf '%s\n' "$fpr"
