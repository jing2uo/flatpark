#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The upstream Debian
# package is a plain FHS tree: the Tauri GUI binary at usr/bin/Lap, and its
# resources under usr/lib/Lap — the bundled ffmpeg/ffprobe sidecars used for
# video thumbnails and the ONNX models behind local search and face detection.
#
# The two must stay siblings. Tauri resolves its resource directory relative to
# the running executable as <exe_dir>/../lib/<product-name>, so the binary has
# to sit in a bin/ whose parent also holds lib/Lap. Staging them anywhere else —
# flattening to a single binary, or moving the resources under the binary —
# leaves the models and the ffmpeg sidecars unfindable, and the app starts but
# silently loses video thumbnails and every AI feature. We deliberately do not
# set APPDIR/APPIMAGE here: Tauri takes those as a signal it is running from an
# AppImage and resolves resources down a path that does not exist in this
# layout.
#
# Not staged: the .desktop file and the icon. Flatpak has to export those at
# build time, and extra-data is only fetched later on the user's machine, so the
# manifest ships its own copies instead.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f lap.deb ] || { echo "missing extra-data: lap.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb
# ar container directly; pipe its data member into a second bsdtar to unpack the
# FHS tree (the inner data.tar compression is auto-detected).
rm -rf stage lap
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring the archive's recorded uid/gid
# fails and aborts the unpack even though every member extracted fine.
bsdtar -xOf lap.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

[ -x stage/usr/bin/Lap ] || { echo "Lap binary not found in .deb" >&2; exit 1; }
[ -d stage/usr/lib/Lap/models ] || { echo "models not found in .deb" >&2; exit 1; }
[ -d stage/usr/lib/Lap/ffmpeg ] || { echo "ffmpeg sidecars not found in .deb" >&2; exit 1; }

mkdir -p lap/bin lap/lib
mv stage/usr/bin/Lap lap/bin/Lap
mv stage/usr/lib/Lap lap/lib/Lap
rm -rf stage lap.deb

chmod +x lap/bin/Lap
chmod +x lap/lib/Lap/ffmpeg/ffmpeg-x86_64-unknown-linux-gnu \
          lap/lib/Lap/ffmpeg/ffprobe-x86_64-unknown-linux-gnu
