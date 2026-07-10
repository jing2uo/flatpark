#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The upstream Debian
# package is a plain FHS tree whose payload is a single Tauri binary at
# usr/bin/open-dronelog (the React frontend and DuckDB are both linked into the
# executable); the rest is the .desktop file and one icon. We stage the binary
# at a stable path the wrapper expects: /app/extra/open-dronelog/bin. The
# desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f open-dronelog.deb ] || { echo "missing extra-data: open-dronelog.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb
# ar container directly; pipe its data member into a second bsdtar to unpack the
# FHS tree (the inner data.tar compression is auto-detected).
rm -rf stage open-dronelog
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf open-dronelog.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -f stage/usr/bin/open-dronelog ] || { echo "open-dronelog not found in .deb" >&2; exit 1; }

mkdir -p open-dronelog/bin
mv stage/usr/bin/open-dronelog open-dronelog/bin/open-dronelog
rm -rf stage open-dronelog.deb
chmod +x open-dronelog/bin/open-dronelog
