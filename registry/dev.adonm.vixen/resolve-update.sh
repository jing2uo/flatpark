#!/usr/bin/env bash
set -euo pipefail

repo="adonm/vixen"
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
url="$(jq -r '.assets[] | select(.name == "vixen-linux-x86_64.tar.gz") | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve Vixen Linux release" >&2; exit 1; }
echo "resolved Vixen $version ($date): $url" >&2
jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"vixen-linux-x86_64.tar.gz", url:$u}]}'
