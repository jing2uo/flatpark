#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# Folia as an electron-builder .deb: a plain FHS tree with the app under
# /opt/Folia plus desktop integration files. Unpack the data member and keep
# just the app directory at /app/extra/folia, the stable path the wrapper execs.
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# build time, because extra-data is fetched later on the user's machine.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f folia-major.deb ] || { echo "missing extra-data: folia-major.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# FHS tree (the inner data.tar compression is auto-detected).
rm -rf stage folia
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf folia-major.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/opt/Folia/folia-major ] || { echo "folia-major binary not found in .deb" >&2; exit 1; }
mv stage/opt/Folia folia
rm -rf stage folia-major.deb
[ -x folia/folia-major ] || { echo "folia-major binary missing after stage" >&2; exit 1; }
