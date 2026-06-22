#!/usr/bin/env bash
# Update resolver for GeoLibre.
#
# Prints the current version + the x86_64 Linux .deb as JSON on stdout:
#   { "version": "1.5.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "geolibre.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="opengeos/GeoLibre"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The x86_64 desktop build is the `GeoLibre.Desktop_<ver>_amd64.deb` asset (the
# others are the .rpm/.AppImage, the .app.tar.gz / .dmg / .msi / .exe / .msix
# and the Android .apk).
url="$(jq -r '.assets[] | select(.name | test("_amd64\\.deb$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve geolibre release" >&2; exit 1; }
echo "resolved geolibre $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"geolibre.deb", url:$u}]}'
