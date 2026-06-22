#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The upstream Debian
# package is a Tauri app-image FHS tree: usr/bin/geolibre-desktop (linking the
# runtime's webkit2gtk-4.1 / gtk-3 / libsoup-3 / javascriptcoregtk-4.1) plus an
# optional Python "geolibre_server" backend under usr/lib. The GNOME runtime has
# no ar/dpkg, so use bsdtar (libarchive) to read the .deb ar container and unpack
# its data.tar. Keep the usr/ tree at a stable path the wrapper execs — Tauri
# resolves its bundled resources relative to the binary. The desktop file, icon
# and AppStream metainfo are shipped by the manifest at *build* time.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f geolibre.deb ] || { echo "missing extra-data: geolibre.deb" >&2; exit 1; }

dm="$(bsdtar -tf geolibre.deb | grep '^data\.tar' | head -n1)"
[ -n "$dm" ] || { echo "no data member in geolibre.deb" >&2; exit 1; }
bsdtar -xOf geolibre.deb "$dm" | bsdtar -xf -

[ -x usr/bin/geolibre-desktop ] || { echo "geolibre-desktop not found in .deb" >&2; exit 1; }

rm -rf usr/share/doc usr/share/man
rm -f geolibre.deb
