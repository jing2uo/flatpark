#!/usr/bin/env bash
# Update resolver for AB Download Manager.
#
# Prints the current version + the x86_64 Linux app-image tarball as JSON on
# stdout:
#   { "version": "1.9.1", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "abdm.tar.gz", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="amir1376/ab-download-manager"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The x86_64 desktop build is the lone `*_linux_x64.tar.gz` asset (the others are
# arm64 Linux, the macOS .dmg/.tar.gz, the Windows .exe/.zip, the Android .apk,
# and their .md5 sidecars).
url="$(jq -r '.assets[] | select(.name | test("_linux_x64\\.tar\\.gz$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve ab-download-manager release" >&2; exit 1; }
echo "resolved ab-download-manager $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"abdm.tar.gz", url:$u}]}'
