#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Rowboat Labs
# ships the desktop app as a Debian package: a plain FHS tree with the full
# official Electron app under /usr/lib/rowboat-linux, plus icons and desktop
# metadata. Keep only the official app tree at the stable path the wrapper
# executes: /app/extra/rowboat. The exported desktop file, icon and AppStream
# metainfo are shipped by the manifest at build time because extra-data is
# fetched later on the user's machine.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

deb="rowboat-amd64.deb"
[ -f "$deb" ] || { echo "missing extra-data: $deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree. Keep an ar/tar fallback so the script is easy to verify on Debian hosts.
rm -rf stage rowboat
mkdir stage
if command -v bsdtar >/dev/null 2>&1; then
  # --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
  # every capability dropped, so restoring the archive's recorded uid/gid fails and
  # aborts the unpack even though every member extracted fine.
  bsdtar -xOf "$deb" 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
else
  member="$(ar t "$deb" | grep '^data.tar' | head -n 1)"
  [ -n "$member" ] || { echo "data.tar member not found in .deb" >&2; exit 1; }
  case "$member" in
    *.tar.xz) ar p "$deb" "$member" | tar --no-same-owner -xJ -C stage ;;
    *.tar.gz) ar p "$deb" "$member" | tar --no-same-owner -xz -C stage ;;
    *.tar.zst) ar p "$deb" "$member" | tar --no-same-owner --zstd -x -C stage ;;
    *.tar) ar p "$deb" "$member" | tar --no-same-owner -x -C stage ;;
    *) echo "unsupported data archive: $member" >&2; exit 1 ;;
  esac
fi
[ -x stage/usr/lib/rowboat-linux/rowboat ] || {
  echo "Rowboat binary not found in .deb" >&2
  exit 1
}
mv stage/usr/lib/rowboat-linux rowboat
rm -rf stage "$deb"
[ -x rowboat/rowboat ] || {
  echo "Rowboat binary missing after stage" >&2
  exit 1
}
