#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# ZenNotes as an electron-builder .deb: a plain FHS tree with the whole app under
# /opt/ZenNotes (Chromium, app.asar, libffmpeg.so) plus icons and a .desktop.
# Unpack the .deb's data member and keep just the app directory at a stable path
# the wrapper execs: /app/extra/zennotes. The desktop file, icon and AppStream
# metainfo are shipped by the manifest at *build* time — extra-data is fetched
# later on the user's machine, so anything Flatpak must export cannot come from
# here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f zennotes.deb ] || { echo "missing extra-data: zennotes.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage zennotes
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf zennotes.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/opt/ZenNotes/ZenNotes ] || { echo "ZenNotes binary not found in .deb" >&2; exit 1; }
mv stage/opt/ZenNotes zennotes
rm -rf stage zennotes.deb
[ -x zennotes/ZenNotes ] || { echo "ZenNotes binary missing after stage" >&2; exit 1; }
