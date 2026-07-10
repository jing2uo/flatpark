#!/usr/bin/env bash
# Update resolver for GSE Profiler.
#
# Prints the current version + the installable .deb as JSON on stdout:
#   { "version": "1.2.0", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "gse-profiler.deb", "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark downloads the
# URL and computes the extra-data sha256/size at build time. The version is
# compared against the latest <release> in the AppStream metainfo.
#
# Upstream publishes GitHub Releases only for stable tags (prerelease rc/beta
# tags create no Release at all), so /releases/latest is always a stable build.
set -euo pipefail

repo="todevelopers/gseprofiler"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
# The thin arch-independent package is `gse-profiler_<ver>_all.deb`. Match it
# exactly so the source tarball and the self-hosted .flatpak bundle attached
# to the same Release are excluded.
url="$(jq -r 'first(.assets[] | select(.name | test("^gse-profiler_.*_all\\.deb$")) | .browser_download_url)' <<<"$rel")"

[ -n "$version" ] && [ -n "$url" ] || { echo "failed to resolve GSE Profiler release" >&2; exit 1; }
echo "resolved GSE Profiler $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"gse-profiler.deb", url:$u}]}'
