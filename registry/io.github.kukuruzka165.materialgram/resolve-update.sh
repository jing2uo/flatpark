#!/usr/bin/env bash
# Update resolver for materialgram.
#
# Prints the current version + the Linux release tarball as JSON on stdout:
#   { "version": "6.7.7.1", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "materialgram.tar.zst", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="kukuruzka165/materialgram"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The Linux build is the lone `materialgram-v<tag>.tar.zst` asset (the others are
# the macOS .zip and the win64 .zip).
url="$(jq -r '.assets[] | select(.name | test("^materialgram-v.*\\.tar\\.zst$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve materialgram release" >&2; exit 1; }
echo "resolved materialgram $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"materialgram.tar.zst", url:$u}]}'
