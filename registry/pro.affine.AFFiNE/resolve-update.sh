#!/usr/bin/env bash
# Update resolver for AFFiNE.
#
# Prints the current version + the x86_64 Linux .deb as JSON on stdout:
#   { "version": "0.26.3", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "affine.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="toeverything/AFFiNE"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# releases/latest is the newest non-prerelease (stable) tag; AFFiNE's canary and
# X.Y.Z-beta.N builds are all flagged prerelease, so they are excluded here.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The x86_64 desktop build is `affine-<ver>-stable-linux-x64.deb`. Match it
# exactly so the .appimage/.flatpak/.zip and the macOS assets are all excluded.
url="$(jq -r '.assets[] | select(.name | test("-stable-linux-x64\\.deb$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve AFFiNE release" >&2; exit 1; }
echo "resolved AFFiNE $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"affine.deb", url:$u}]}'
