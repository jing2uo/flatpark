#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The upstream Debian
# package is a plain FHS tree: usr/bin/yaak-app-client plus usr/lib/yaak (the
# vendored protoc, a Node runtime and the bundled plugins) and icons/.desktop/
# metainfo. We stage the binary together with its lib/ sibling at a stable path
# the wrapper expects: /app/extra/yaak/{bin,lib}. Keeping bin/ and lib/ as
# siblings matters — Tauri's resource_dir resolves the vendored tree relative to
# the executable (<exe_dir>/../lib/yaak). The desktop file, icon and AppStream
# metainfo are shipped by the manifest at *build* time — extra-data is fetched
# later on the user's machine, so anything Flatpak must export cannot come here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f yaak.deb ] || { echo "missing extra-data: yaak.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb
# ar container directly; pipe its data member into a second bsdtar to unpack the
# FHS tree (the inner data.tar compression is auto-detected).
rm -rf stage yaak
mkdir stage
bsdtar -xOf yaak.deb 'data.tar*' | bsdtar -xf - -C stage
[ -x stage/usr/bin/yaak-app-client ] || { echo "yaak-app-client not found in .deb" >&2; exit 1; }
mv stage/usr yaak
rm -rf stage yaak.deb
chmod +x yaak/bin/yaak-app-client
