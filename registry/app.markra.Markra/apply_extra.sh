#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The upstream Debian
# package is a plain FHS tree whose only payload is usr/bin/markra — a single
# self-contained Tauri binary with its web assets embedded (no vendored lib/
# tree). We stage just that binary at a stable path the wrapper expects:
# /app/extra/markra/markra. The desktop file, icon and AppStream metainfo are
# shipped by the manifest at *build* time — extra-data is fetched later on the
# user's machine, so anything Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f markra.deb ] || { echo "missing extra-data: markra.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb
# ar container directly; pipe its data member into a second bsdtar to unpack the
# FHS tree (the inner data.tar compression is auto-detected).
rm -rf stage markra
mkdir stage
bsdtar -xOf markra.deb 'data.tar*' | bsdtar -xf - -C stage
[ -x stage/usr/bin/markra ] || { echo "markra binary not found in .deb" >&2; exit 1; }
mkdir markra
mv stage/usr/bin/markra markra/markra
rm -rf stage markra.deb
chmod +x markra/markra
