#!/bin/sh
set -eu

# Runs offline at install time. Unpacks the upstream materialgram release tarball
# (a single self-contained binary plus FHS metadata) and keeps only the binary at
# a stable path the wrapper expects: /app/extra/materialgram. The desktop file,
# icon and AppStream metainfo are shipped by the manifest at *build* time —
# extra-data is fetched later on the user's machine, so anything Flatpak must
# export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f materialgram.tar.zst ] || { echo "missing extra-data: materialgram.tar.zst" >&2; exit 1; }

# org.freedesktop.Platform ships tar + zstd; extract just the binary.
zstd -dc materialgram.tar.zst | tar -xf - usr/bin/materialgram
[ -f usr/bin/materialgram ] || { echo "materialgram binary not found in tarball" >&2; exit 1; }
mv usr/bin/materialgram materialgram
rm -rf usr materialgram.tar.zst
chmod +x materialgram
