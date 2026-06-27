#!/usr/bin/env bash
# Update resolver for DiscordChatExporter.
#
# Prints the current version + the Linux x86_64 GUI zip as JSON on stdout:
#   { "version": "2.47.3", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "dce.zip", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
set -euo pipefail

repo="Tyrrrz/DiscordChatExporter"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The x86_64 desktop GUI build is the lone `DiscordChatExporter.linux-x64.zip`
# asset — NOT the `.Cli.` console builds, the `musl`/`arm` variants, or the
# macOS/Windows zips.
url="$(jq -r '.assets[] | select(.name == "DiscordChatExporter.linux-x64.zip") | .browser_download_url' <<<"$rel" | head -n1)"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve DiscordChatExporter release" >&2; exit 1; }
echo "resolved DiscordChatExporter $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"dce.zip", url:$u}]}'
