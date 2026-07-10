#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# Orca as an electron-builder .deb: a plain FHS tree with the whole app under
# /opt/Orca plus icons and a .desktop file. Unpack the .deb data member and keep
# the app directory at /app/extra/Orca, the stable path the wrapper execs.
# Flatpak-exported desktop metadata and the AppStream file are shipped by the
# manifest at build time, because extra-data is fetched later on the user's
# machine.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f orca.deb ] || { echo "missing extra-data: orca.deb" >&2; exit 1; }

# org.freedesktop.Platform has no dpkg, but bsdtar reads the .deb ar container
# directly and auto-detects the inner data.tar compression.
rm -rf stage Orca
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf orca.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/opt/Orca/orca-ide ] || { echo "Orca binary not found in .deb" >&2; exit 1; }
mv stage/opt/Orca Orca
rm -rf stage orca.deb
[ -x Orca/orca-ide ] || { echo "Orca binary missing after stage" >&2; exit 1; }
