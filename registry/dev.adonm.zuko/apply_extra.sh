#!/bin/sh
set -eu

# Runs offline at install time. Upstream's official Linux archive contains one
# complete, relocatable Flutter bundle. Keep that payload byte-for-byte intact
# under /app/extra; the wrapper and exported metadata are installed separately.
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

archive=zuko-linux-x86_64.tar.gz
[ -f "$archive" ] || { echo "missing extra-data: $archive" >&2; exit 1; }

rm -rf bundle
# System-wide installs run this as uid 0 with every capability dropped, so do
# not attempt to restore the archive's numeric owner.
tar --no-same-owner -xzf "$archive"
[ -x bundle/zuko ] || { echo "Zuko executable not found in archive" >&2; exit 1; }
[ -d bundle/data ] || { echo "Flutter data directory not found in archive" >&2; exit 1; }
[ -d bundle/lib ] || { echo "Flutter library directory not found in archive" >&2; exit 1; }

rm -f "$archive"
