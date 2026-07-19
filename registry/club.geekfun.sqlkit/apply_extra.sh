#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The upstream Debian
# package is a plain FHS tree whose payload is a single self-contained Tauri
# binary (usr/bin/sqlkit; the frontend assets are embedded in the binary). We
# keep only that binary at a stable path the wrapper expects: /app/extra/sqlkit.
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f sqlkit.deb ] || { echo "missing extra-data: sqlkit.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb
# ar container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage sqlkit
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf sqlkit.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/usr/bin/sqlkit ] || { echo "sqlkit binary not found in .deb" >&2; exit 1; }
mv stage/usr/bin/sqlkit sqlkit
rm -rf stage sqlkit.deb
chmod +x sqlkit
