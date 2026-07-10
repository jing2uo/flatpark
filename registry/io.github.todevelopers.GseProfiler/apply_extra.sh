#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Upstream ships GSE
# Profiler as a thin Debian package: pure-Python application code under
# /usr/share/gse-profiler ("app" plus the bundled "bridge-extension" GNOME
# Shell extension) with all native dependencies expected from the platform —
# inside this Flatpak the GNOME runtime provides them. Unpack the .deb's data
# member and keep the two payload directories at stable paths the wrapper
# execs: /app/extra/app and /app/extra/bridge-extension. The desktop file,
# icon and AppStream metainfo are shipped by the manifest at *build* time —
# extra-data is fetched later on the user's machine, so anything Flatpak must
# export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f gse-profiler.deb ] || { echo "missing extra-data: gse-profiler.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb
# ar container directly; pipe its data member into a second bsdtar to unpack
# the tree (the inner data.tar compression is auto-detected). --no-same-owner
# keeps the root and non-root paths identical: system-wide installs run
# apply_extra as uid 0 with all capabilities dropped, where restoring a
# non-root owner recorded in the archive would EPERM.
rm -rf stage app bridge-extension
mkdir stage
bsdtar -xOf gse-profiler.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -f stage/usr/share/gse-profiler/app/main.py ] || { echo "app payload not found in .deb" >&2; exit 1; }
mv stage/usr/share/gse-profiler/app app
mv stage/usr/share/gse-profiler/bridge-extension bridge-extension
rm -rf stage gse-profiler.deb
[ -f app/main.py ] && [ -f bridge-extension/metadata.json ] || { echo "payload missing after stage" >&2; exit 1; }
