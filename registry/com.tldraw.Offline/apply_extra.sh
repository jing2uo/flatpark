#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# tldraw offline as an electron-builder .deb: a plain FHS tree with the whole
# app under "/opt/tldraw offline" (the Chromium binary `@tldesktop`, its .pak
# resources, libffmpeg/ANGLE/SwiftShader and the bundled SDK type stubs) plus
# icons, a .desktop and a shared-mime-info file. Unpack the .deb's data member
# and keep just the app directory at a stable, space-free path the wrapper
# execs: /app/extra/tldraw-offline. The directory is renamed but its contents
# are untouched — the binary keeps its upstream name. The desktop file, icons,
# MIME definition and AppStream metainfo are shipped by the manifest at *build*
# time — extra-data is fetched later on the user's machine, so anything Flatpak
# must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f tldraw-offline.deb ] || { echo "missing extra-data: tldraw-offline.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage tldraw-offline
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf tldraw-offline.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x "stage/opt/tldraw offline/@tldesktop" ] || { echo "tldraw offline binary not found in .deb" >&2; exit 1; }
mv "stage/opt/tldraw offline" tldraw-offline
rm -rf stage tldraw-offline.deb
[ -x tldraw-offline/@tldesktop ] || { echo "tldraw offline binary missing after stage" >&2; exit 1; }
