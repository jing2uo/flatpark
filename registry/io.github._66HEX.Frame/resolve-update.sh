#!/usr/bin/env bash
# Update resolver for Frame.
#
# Prints the current version + the x86_64 Linux tarball as JSON on stdout:
#   { "version": "0.30.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "frame-linux-x86_64.tar.gz", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="66HEX/frame"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# Prefer the plain portable tarball over AppImage/flatpak.zip assets.
url="$(jq -r 'first(.assets[] | select(.name == "frame-linux-x86_64.tar.gz") | .browser_download_url)' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve frame release" >&2; exit 1; }
echo "resolved frame $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"frame-linux-x86_64.tar.gz", url:$u}]}'
