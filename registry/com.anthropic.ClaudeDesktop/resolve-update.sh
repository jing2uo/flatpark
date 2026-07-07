#!/usr/bin/env bash
# Update resolver for Claude Desktop.
#
# Prints the current version + official Debian package URLs for amd64 and arm64:
#   { "version": "1.18286.0", "sources": [
#       { "filename": "claude-desktop-amd64.deb", "url": "..." },
#       { "filename": "claude-desktop-arm64.deb", "url": "..." }
#   ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URLs and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq
need sort

base="https://downloads.claude.ai/claude-desktop/apt/stable"

resolve_arch() {
  local arch="$1"
  local index_url="$base/dists/stable/main/binary-$arch/Packages"
  curl -fsSL "$index_url" | awk -v RS='' -v base="$base" '
    /^Package: claude-desktop\n/ || $1 == "Package:" {
      version = filename = ""
      n = split($0, lines, "\n")
      for (i = 1; i <= n; i++) {
        if (lines[i] ~ /^Version: /) version = substr(lines[i], 10)
        else if (lines[i] ~ /^Filename: /) filename = substr(lines[i], 11)
      }
      if (version != "" && filename != "")
        printf "%s\t%s/%s\n", version, base, filename
    }' | sort -V -k1,1 | tail -n1
}

amd64="$(resolve_arch amd64)"
arm64="$(resolve_arch arm64)"

[ -n "$amd64" ] && [ -n "$arm64" ] || {
  echo "failed to resolve Claude Desktop packages" >&2
  exit 1
}

IFS=$'\t' read -r version_amd64 url_amd64 <<<"$amd64"
IFS=$'\t' read -r version_arm64 url_arm64 <<<"$arm64"

[ "$version_amd64" = "$version_arm64" ] || {
  echo "architecture versions differ: amd64=$version_amd64 arm64=$version_arm64" >&2
  exit 1
}

echo "resolved Claude Desktop $version_amd64" >&2

jq -n \
  --arg v "$version_amd64" \
  --arg u_amd64 "$url_amd64" \
  --arg u_arm64 "$url_arm64" \
  '{version:$v, sources:[
    {filename:"claude-desktop-amd64.deb", url:$u_amd64},
    {filename:"claude-desktop-arm64.deb", url:$u_arm64}
  ]}'
