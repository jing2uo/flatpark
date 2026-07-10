#!/usr/bin/env bash
# Update resolver for MQTT Viewer.
#
# Prints the current version + the Linux x86_64 .deb as JSON on stdout:
#   { "version": "1.0.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "mqtt-viewer.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="mqtt-viewer/mqtt-viewer"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# releases/latest excludes prereleases, so this tracks the stable channel
# (MQTT Viewer also publishes betas as prereleases, e.g. v0.7.0-beta1).
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The Linux x86_64 build is the lone `*_linux_amd64.deb` asset (the others are
# the arm64 .deb, the .rpm/.AppImage/.zip, and the macOS/Windows archives). The
# per-asset `.sha256` sidecars match the same glob, so exclude them.
url="$(jq -r '.assets[] | select(.name | test("_linux_amd64\\.deb$")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve mqtt-viewer release" >&2; exit 1; }
echo "resolved mqtt-viewer $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"mqtt-viewer.deb", url:$u}]}'
