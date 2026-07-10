#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# Tabby as an electron-builder .deb: a plain FHS tree with the whole app under
# /opt/Tabby (the tabby Chromium binary, app.asar, libffmpeg.so, ANGLE and
# SwiftShader libs) plus icons and a .desktop. Unpack the .deb's data member and
# keep just the app directory at a stable path the wrapper execs:
# /app/extra/tabby. The desktop file, icon and AppStream metainfo are shipped by
# the manifest at *build* time — extra-data is fetched later on the user's
# machine, so anything Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f tabby.deb ] || { echo "missing extra-data: tabby.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage tabby
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf tabby.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/opt/Tabby/tabby ] || { echo "tabby binary not found in .deb" >&2; exit 1; }
mv stage/opt/Tabby tabby
rm -rf stage tabby.deb
[ -x tabby/tabby ] || { echo "tabby binary missing after stage" >&2; exit 1; }
