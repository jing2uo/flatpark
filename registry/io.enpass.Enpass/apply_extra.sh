#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# Enpass as a .deb with the application under /opt/enpass.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f enpass.deb ] || { echo "missing extra-data: enpass.deb" >&2; exit 1; }

rm -rf stage enpass
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf enpass.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/opt/enpass/Enpass ] || { echo "Enpass binary not found in .deb" >&2; exit 1; }
mv stage/opt/enpass enpass
rm -rf stage enpass.deb
[ -x enpass/Enpass ] || { echo "Enpass binary missing after stage" >&2; exit 1; }
