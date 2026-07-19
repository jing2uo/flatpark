#!/usr/bin/env bash
# Resolve the newest published tldraw offline release and its exact amd64
# Debian package. FlatPark computes and rewrites the managed SHA-256 and size
# pins; this script only resolves the version and the download URL.
set -euo pipefail

repo=tldraw/tldraw-offline
need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases/latest")"
tag="$(jq -er '.tag_name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))' <<<"$release")"
version="${tag#v}"
date="$(jq -er '.published_at | split("T")[0]' <<<"$release")"

# The asset name is version-independent, so match it exactly: this excludes the
# arm64/x86_64 AppImages (not an accepted artifact), the macOS and Windows
# builds, and the electron-updater latest*.yml metadata.
asset="tldraw-offline-linux-amd64.deb"
url="$(jq -er --arg name "$asset" \
  '[.assets[] | select(.name == $name)] | if length == 1 then .[0].browser_download_url else error("expected exactly one amd64 .deb") end' \
  <<<"$release")"

[[ "$url" == "https://github.com/$repo/releases/download/$tag/$asset" ]] || {
  echo "refusing unexpected release asset URL: $url" >&2
  exit 1
}
echo "resolved tldraw offline $version ($date): $url" >&2
jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"tldraw-offline.deb", url:$u}]}'
