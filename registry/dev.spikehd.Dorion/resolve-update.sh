#!/usr/bin/env bash
# Update resolver for Dorion.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "6.12.2", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "dorion.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="SpikeHD/Dorion"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The Linux x86_64 build is the `Dorion_<version>_amd64.deb` asset (the arm64 and
# armhf .debs, the .rpm/.AppImage/portable tarballs and the macOS/Windows builds
# are skipped).
url="$(jq -r '.assets[] | select(.name | test("_amd64\\.deb$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve dorion release" >&2; exit 1; }
echo "resolved dorion $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"dorion.deb", url:$u}]}'
