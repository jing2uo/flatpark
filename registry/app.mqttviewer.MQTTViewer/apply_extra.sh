#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The upstream Debian
# package is a plain FHS tree whose payload is a single self-contained Wails
# binary at usr/local/bin/mqtt-viewer (Go, with the web assets embedded); the
# only other members are the .desktop file and the icon. We stage the binary at
# a stable path the wrapper expects: /app/extra/mqtt-viewer/bin/mqtt-viewer.
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f mqtt-viewer.deb ] || { echo "missing extra-data: mqtt-viewer.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb
# ar container directly; pipe its data member into a second bsdtar to unpack the
# FHS tree (the inner data.tar compression is auto-detected).
rm -rf stage mqtt-viewer
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf mqtt-viewer.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -f stage/usr/local/bin/mqtt-viewer ] || { echo "mqtt-viewer not found in .deb" >&2; exit 1; }

mkdir -p mqtt-viewer/bin
mv stage/usr/local/bin/mqtt-viewer mqtt-viewer/bin/mqtt-viewer
rm -rf stage mqtt-viewer.deb
chmod +x mqtt-viewer/bin/mqtt-viewer
