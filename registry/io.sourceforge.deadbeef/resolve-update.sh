#!/usr/bin/env bash
# Update resolver for DeaDBeeF stable Linux portable builds.
#
# Prints the current stable version + the x86_64 portable tarball as JSON:
#   { "version": "1.10.3", "sources": [
#       { "filename": "deadbeef-static.tar.bz2", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting: FlatPark downloads the
# URL and computes the extra-data sha256/size at build time.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

download_page="https://deadbeef.sourceforge.io/download.html"
html="$(curl -fsSL "$download_page")"

url="$(grep -Eo 'https://sourceforge\.net/projects/deadbeef/files/Builds/[0-9.]+/linux/deadbeef-static_[0-9.]+-[0-9]+_x86_64\.tar\.bz2/download' <<<"$html" | head -n1)"
version="$(sed -E 's#^https://sourceforge\.net/projects/deadbeef/files/Builds/([^/]+)/.*$#\1#' <<<"$url")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve DeaDBeeF stable Linux build" >&2; exit 1; }
echo "resolved DeaDBeeF $version: $url" >&2

jq -n --arg v "$version" --arg u "$url" \
  '{version:$v, sources:[{filename:"deadbeef-static.tar.bz2", url:$u}]}'
