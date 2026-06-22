#!/usr/bin/env bash
# Update resolver for thinkorswim.
#
# Prints the current version + bootstrap sources as JSON on stdout:
#   { "version": "YYYY.MM.DD", "releaseDate": "YYYY-MM-DD",
#     "sources": [ { "filename": "thinkorswim-installer.sh", "url": "..." },
#                  { "filename": "zulu-jre.tar.gz",          "url": "..." } ] }
# Logs go to stderr. No hashing, no manifest rewriting — FlatPark applies the
# URLs and computes the extra-data pins at build time. The internal jars are NOT
# listed: install4j downloads and self-updates them at runtime from Schwab's
# config servers (thinkorswim-desktop*.schwab.com) in the data dir.
#
# Upstream ships a single "latest" installer at a fixed URL with no version
# endpoint, so the version anchor is the installer's Last-Modified date. It bumps
# whenever Schwab publishes a new bootstrap, which is what triggers a re-pin.
set -euo pipefail

INSTALLER_URL="https://tosmediaserver.schwab.com/installer/InstFiles/thinkorswim_installer.sh"
# Zulu JRE from Azul's official CDN. thinkorswim requires Java 21. Pinned; bump
# for security via Azul's metadata API: api.azul.com/metadata/v1/zulu/packages/
# ?java_version=21&os=linux&arch=x64&java_package_type=jre&javafx_bundled=false
# &latest=true&availability_types=CA&archive_type=tar.gz
JRE_URL="https://cdn.azul.com/zulu/bin/zulu21.50.19-ca-jre21.0.11-linux_x64.tar.gz"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need date; need python3

last_modified="$(curl -fsSL -I "$INSTALLER_URL" | sed -nE 's/^[Ll]ast-[Mm]odified:[[:space:]]*(.+)\r?$/\1/p' | head -n1)"
[ -n "$last_modified" ] || { echo "no Last-Modified header from $INSTALLER_URL" >&2; exit 1; }

version="$(date -u -d "$last_modified" +%Y.%m.%d)"
release_date="$(date -u -d "$last_modified" +%Y-%m-%d)"
echo "resolved thinkorswim bootstrap $version (Last-Modified: $last_modified)" >&2

python3 - "$version" "$release_date" "$INSTALLER_URL" "$JRE_URL" <<'PY'
import json, sys
version, release_date, installer_url, jre_url = sys.argv[1:5]
print(json.dumps({
    "version": version,
    "releaseDate": release_date,
    "sources": [
        {"filename": "thinkorswim-installer.sh", "url": installer_url},
        {"filename": "zulu-jre.tar.gz", "url": jre_url},
    ],
}, indent=2))
PY
