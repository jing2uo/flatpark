#!/usr/bin/env bash
# Update resolver for DevPod prereleases.
#
# Prints the newest GitHub prerelease and its x86_64 Linux .deb as JSON:
#   { "version": "0.7.0-alpha.34", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "devpod.deb", "url": "..." } ] }
set -euo pipefail

repo="loft-sh/devpod"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rels="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases?per_page=30")"

rel="$(jq -c '[.[] | select(.prerelease == true) | select(any(.assets[]; .name | test("^DevPod_.*_amd64\\.deb$")))][0]' <<<"$rels")"
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r '.assets[] | select(.name | test("^DevPod_.*_amd64\\.deb$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ "$version" != "null" ] && [ -n "$url" ] || {
  echo "failed to resolve DevPod prerelease" >&2
  exit 1
}
echo "resolved DevPod prerelease $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"devpod.deb", url:$u}]}'
