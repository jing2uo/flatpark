#!/bin/sh
set -eu

# Runs offline at install time. Stages the read-only bootstrap into /app/extra:
# the install4j installer script and an extracted JRE. thinkorswim itself is
# installed into the writable per-app data dir on first launch (see
# thinkorswim-wrapper), where install4j downloads and self-updates its jars from
# Schwab's config servers. /app stays read-only; the real home is never touched.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f thinkorswim-installer.sh ] || { echo "missing extra-data: thinkorswim-installer.sh" >&2; exit 1; }
[ -f zulu-jre.tar.gz ]         || { echo "missing extra-data: zulu-jre.tar.gz" >&2; exit 1; }

# Extract the JRE to a stable path the wrapper expects: /app/extra/jre.
rm -rf jre jre-stage
mkdir -p jre-stage
tar -xzf zulu-jre.tar.gz -C jre-stage
jre_java="$(find jre-stage -path '*/bin/java' -type f | head -n 1)"
[ -n "$jre_java" ] || { echo "failed to find java in zulu-jre.tar.gz" >&2; exit 1; }
mv "$(dirname "$(dirname "$jre_java")")" jre
rm -rf jre-stage zulu-jre.tar.gz

chmod +x thinkorswim-installer.sh
