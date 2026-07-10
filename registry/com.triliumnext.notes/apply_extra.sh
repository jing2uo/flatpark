#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# Trilium as an electron-builder .deb: a plain FHS tree with the whole app under
# /usr/lib/trilium (the Trilium/Chromium binary, resources/app.asar, the
# better-sqlite3 native module, libffmpeg.so, ANGLE and SwiftShader libs) plus a
# /usr/bin/trilium symlink, an icon and a .desktop. Unpack the .deb's data
# member and keep just the app directory at a stable path the wrapper execs:
# /app/extra/trilium. The desktop file, icon and AppStream metainfo are shipped
# by the manifest at *build* time — extra-data is fetched later on the user's
# machine, so anything Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f trilium.deb ] || { echo "missing extra-data: trilium.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage trilium
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf trilium.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/usr/lib/trilium/trilium ] || { echo "trilium binary not found in .deb" >&2; exit 1; }
mv stage/usr/lib/trilium trilium
rm -rf stage trilium.deb
[ -x trilium/trilium ] || { echo "trilium binary missing after stage" >&2; exit 1; }
