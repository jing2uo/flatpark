#!/usr/bin/env bash
# Update resolver for Orca.
#
# Prints the current stable version + the x86_64 Linux .deb as JSON on stdout:
#   { "version": "1.4.128", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "orca.deb", "url": "..." } ] }
# Logs go to stderr. Hashing and manifest rewriting are done by FlatPark.
set -euo pipefail

repo="stablyai/orca"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

# releases/latest is the newest non-prerelease stable release; Orca also
# publishes rc builds, which should not update the stable FlatPark package.
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r --arg v "$version" '.assets[] | select(.name == ("orca-ide_" + $v + "_amd64.deb")) | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve Orca release" >&2; exit 1; }
echo "resolved Orca $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"orca.deb", url:$u}]}'
