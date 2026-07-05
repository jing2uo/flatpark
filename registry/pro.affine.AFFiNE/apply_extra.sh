#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# AFFiNE as an electron-builder .deb: a plain FHS tree with the whole app under
# /usr/lib/affine (the AFFiNE Chromium binary, app.asar, libffmpeg.so, ANGLE and
# SwiftShader libs) plus a /usr/bin/affine symlink, an icon and a .desktop.
# Unpack the .deb's data member and keep just the app directory at a stable path
# the wrapper execs: /app/extra/affine. The desktop file, icon and AppStream
# metainfo are shipped by the manifest at *build* time — extra-data is fetched
# later on the user's machine, so anything Flatpak must export cannot come here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f affine.deb ] || { echo "missing extra-data: affine.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage affine
mkdir stage
bsdtar -xOf affine.deb 'data.tar*' | bsdtar -xf - -C stage
[ -x stage/usr/lib/affine/AFFiNE ] || { echo "AFFiNE binary not found in .deb" >&2; exit 1; }
mv stage/usr/lib/affine affine
rm -rf stage affine.deb
[ -x affine/AFFiNE ] || { echo "AFFiNE binary missing after stage" >&2; exit 1; }
