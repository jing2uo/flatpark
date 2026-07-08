#!/usr/bin/env bash
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

repo_root="https://apt.enpass.io"
packages="$(curl -fsSL "$repo_root/dists/stable/main/binary-amd64/Packages")"

entry="$(awk '
  BEGIN { RS=""; FS="\n" }
  {
    package = ""
    arch = ""
    for (i = 1; i <= NF; i++) {
      if ($i == "Package: enpass") package = "enpass"
      if ($i == "Architecture: amd64") arch = "amd64"
    }
    if (package == "enpass" && arch == "amd64") {
      print
      exit
    }
  }
' <<<"$packages")"

[ -n "$entry" ] || { echo "failed to resolve Enpass amd64 package" >&2; exit 1; }

field() {
  awk -F': ' -v key="$1" '$1 == key { print $2; exit }' <<<"$entry"
}

version="$(field Version)"
filename="$(field Filename)"
sha256="$(field SHA256)"
size="$(field Size)"

[ -n "$version" ] && [ -n "$filename" ] && [ -n "$sha256" ] && [ -n "$size" ] || {
  echo "resolved Enpass package is missing required fields" >&2
  exit 1
}

url="$repo_root/$filename"
echo "resolved Enpass $version: $url" >&2

jq -n \
  --arg v "$version" \
  --arg u "$url" \
  --arg s "$sha256" \
  --argjson z "$size" \
  '{version:$v, sources:[{filename:"enpass.deb", url:$u, sha256:$s, size:$z}]}'
