#!/usr/bin/env bash
# Update resolver for Rowboat.
#
# Prints the latest stable version + the official amd64 Debian package URL:
#   { "version": "0.7.1", "releaseDate": "2026-07-07",
#     "sources": [ { "filename": "rowboat-amd64.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# Uses /releases/latest so pre-releases (Rowboat tags interim builds as
# pre-release) are excluded. Rowboat ships only an x86_64 Linux build.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

repo="rowboatlabs/rowboat"
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r '.assets[] | select(.name | test("^rowboat-linux_.*_amd64\\.deb$")) | .browser_download_url' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || {
  echo "failed to resolve Rowboat amd64 .deb for tag ${version:-<none>}" >&2
  exit 1
}

echo "resolved Rowboat $version ($url)" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"rowboat-amd64.deb", url:$u}]}'
