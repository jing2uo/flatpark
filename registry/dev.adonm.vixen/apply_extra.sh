#!/bin/sh
set -eu

extra_root="${EXTRA_ROOT:-/app/extra}"
archive="$extra_root/vixen-linux-x86_64.tar.gz"

[ -f "$archive" ] || { echo "missing extra-data: $archive" >&2; exit 1; }
cd "$extra_root"
rm -rf vixen
bsdtar --no-same-owner -xzf "$archive"
[ -x vixen/vixen_shell ] || { echo "Vixen runner missing from release archive" >&2; exit 1; }
[ -f vixen/lib/libapp.so ] || { echo "Vixen AOT library missing from release archive" >&2; exit 1; }
[ -f vixen/lib/libflutter_linux_gtk.so ] || { echo "Flutter engine missing from release archive" >&2; exit 1; }
[ -f vixen/lib/libvixen_ffi.so ] || { echo "BrowserCore bridge missing from release archive" >&2; exit 1; }
rm -f "$archive"
