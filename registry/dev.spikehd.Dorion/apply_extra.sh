#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The upstream Debian
# package is a plain FHS tree: the Tauri binary at usr/bin/Dorion plus a resource
# tree at usr/lib/Dorion (the WebKitGTK web extension, the shelter client-mod
# script, icons).
#
# We stage that tree WHOLE, keeping the usr/bin + usr/lib layout intact, because
# the binary finds its own resources by their path relative to itself: Tauri's
# resource dir on Linux is the first of <exe dir>/../lib/<name> (only if it
# exists), $APPDIR/usr/lib/<name>, or /usr/lib/<name>. Staging to
# /app/extra/dorion/usr/bin/Dorion makes the first branch resolve to
# /app/extra/dorion/usr/lib/Dorion, so the web extension is found inside the
# sandbox without setting APPDIR (Tauri panics when APPDIR is set but the
# executable is not an AppImage mount) and without needing to write to the
# runtime's read-only /usr. Flattening the binary out of the tree would leave
# the resource dir pointing at a nonexistent /usr/lib/Dorion, and the app would
# start fine but silently run without the extension.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f dorion.deb ] || { echo "missing extra-data: dorion.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb
# ar container directly; pipe its data member into a second bsdtar to unpack the
# FHS tree (the inner data.tar compression is auto-detected).
rm -rf stage dorion
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf dorion.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/usr/bin/Dorion ] || { echo "Dorion binary not found in .deb" >&2; exit 1; }
[ -d stage/usr/lib/Dorion ] || { echo "resource tree usr/lib/Dorion not found in .deb" >&2; exit 1; }

mkdir dorion
mv stage/usr dorion/usr
rm -rf stage dorion.deb
chmod +x dorion/usr/bin/Dorion
