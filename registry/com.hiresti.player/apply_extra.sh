#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The upstream Debian
# package payload is a plain FHS tree whose app lives entirely under
# usr/share/hiresti/ — the Python sources, the vendored deps in libs/, the
# bundled Rust .so under src_rust/, and the app's own icon theme. We keep that
# whole directory at a stable path the wrapper execs: /app/extra/hiresti. The
# desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f hiresti.deb ] || { echo "missing extra-data: hiresti.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb
# ar container directly; pipe its data member into a second bsdtar to unpack
# just the app tree (inner data.tar compression is auto-detected).
rm -rf stage hiresti
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf hiresti.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage ./usr/share/hiresti
[ -f stage/usr/share/hiresti/main.py ] || { echo "main.py not found in .deb" >&2; exit 1; }
mv stage/usr/share/hiresti hiresti
rm -rf stage hiresti.deb
