#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# Legcord as an electron-builder .deb: a plain FHS tree with the whole app under
# /opt/Legcord (Chromium, app.asar, libffmpeg.so and the Venmic native module)
# plus icons and a .desktop. Unpack the .deb's data member and keep just the app
# directory at a stable path the wrapper execs: /app/extra/legcord. The desktop
# file, icon and AppStream metainfo are shipped by the manifest at *build* time —
# extra-data is fetched later on the user's machine, so anything Flatpak must
# export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f legcord.deb ] || { echo "missing extra-data: legcord.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage legcord
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf legcord.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/opt/Legcord/Legcord ] || { echo "Legcord binary not found in .deb" >&2; exit 1; }
mv stage/opt/Legcord legcord
rm -rf stage legcord.deb
[ -x legcord/Legcord ] || { echo "Legcord binary missing after stage" >&2; exit 1; }
