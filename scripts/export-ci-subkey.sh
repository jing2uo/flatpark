#!/usr/bin/env bash
# Print the armored SIGNING SUBKEY secret for the CI signing secret
# (the FLATPAK_GPG_PRIVATE_KEY GitHub Actions secret).
#
# It exports only the subkey secret — the master secret is replaced by a stub,
# so the long-term identity never leaves your machine. The keyring read is
# GNUPGHOME_DIR (the local .gnupg-flatpark by default).
#
#   ./scripts/export-ci-subkey.sh | gh secret set FLATPAK_GPG_PRIVATE_KEY
#
# Requires the key to be passphrase-less (the default from gen-signing-key.sh);
# CI signs non-interactively.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
need gpg
export GNUPGHOME="$GNUPGHOME_DIR"

fpr="$(gpg --list-keys --with-colons "$KEY_EMAIL" | awk -F: '/^fpr:/{print $10; exit}')"
[ -n "$fpr" ] || die "no signing key in $GNUPGHOME_DIR (run gen-signing-key.sh)"

# export-secret-subkeys exports every subkey secret with the master stubbed out
# (no `!`, which would force just the stubbed primary and drop the subkey).
out="$(gpg --batch --pinentry-mode loopback --passphrase "${KEY_PASSPHRASE:-}" \
        --armor --export-secret-subkeys "$fpr")"
printf '%s' "$out" | grep -q "PGP PRIVATE KEY" || die "subkey export produced no secret material"
printf '%s\n' "$out"
