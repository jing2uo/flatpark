#!/usr/bin/env bash
# Resolve the newest published Zuko release and its exact x86_64 Flutter Linux
# archive. FlatPark computes and rewrites the managed SHA-256 and size pins.
set -euo pipefail

repo=adonm/zuko
need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases/latest")"
tag="$(jq -er '.tag_name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))' <<<"$release")"
version="${tag#v}"
date="$(jq -er '.published_at | split("T")[0]' <<<"$release")"
asset="zuko-linux-${tag}-x86_64.tar.gz"
url="$(jq -er --arg name "$asset" \
  '[.assets[] | select(.name == $name)] | if length == 1 then .[0].browser_download_url else error("expected exactly one Linux archive") end' \
  <<<"$release")"

[[ "$url" == "https://github.com/adonm/zuko/releases/download/$tag/$asset" ]] || {
  echo "refusing unexpected release asset URL: $url" >&2
  exit 1
}
echo "resolved Zuko $version ($date): $url" >&2
jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"zuko-linux-x86_64.tar.gz", url:$u}]}'
