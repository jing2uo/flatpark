#!/usr/bin/env bash
# Update resolver for Lap.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "0.3.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "lap.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="julyx10/lap"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The Linux x86_64 build is `Lap_<version>_amd64.deb`. The release also carries
# an arm64 .deb, macOS .dmg/.app.tar.gz, Windows .msi and AppImages, so anchor
# the match on the amd64 .deb suffix.
url="$(jq -r '.assets[] | select(.name | test("_amd64\\.deb$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve lap release" >&2; exit 1; }
echo "resolved lap $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"lap.deb", url:$u}]}'
