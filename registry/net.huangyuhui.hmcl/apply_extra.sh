#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Two extra-data
# sources are fetched on the user's machine:
#   hmcl.jar    - the HMCL launcher (a single executable jar; kept as-is)
#   jre.tar.gz  - a self-contained Temurin 21 JRE (provides the JVM)
# Unpack the JRE to a stable path the wrapper execs: /app/extra/jre. HMCL itself
# downloads JavaFX and the per-version Minecraft JREs at runtime into its data
# dir. The desktop file, icon and metainfo are shipped by the manifest at build
# time.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f hmcl.jar ] || { echo "missing extra-data: hmcl.jar" >&2; exit 1; }
[ -f jre.tar.gz ] || { echo "missing extra-data: jre.tar.gz" >&2; exit 1; }

# org.freedesktop.Platform ships tar + gzip. The Temurin tarball has a single
# version-stamped top dir (jdk-21.0.x+y-jre); strip it to a stable path.
rm -rf jre
mkdir jre
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
tar --no-same-owner -xzf jre.tar.gz -C jre --strip-components=1
[ -x jre/bin/java ] || { echo "java binary not found in JRE tarball" >&2; exit 1; }
rm -f jre.tar.gz
