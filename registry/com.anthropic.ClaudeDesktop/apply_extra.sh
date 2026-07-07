#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Anthropic ships
# Claude Desktop as a Debian package: a plain FHS tree with the full official
# Electron app under /usr/lib/claude-desktop, plus icons and desktop metadata.
# Keep only the official app tree at the stable path the wrapper executes:
# /app/extra/claude-desktop. The exported desktop file, icon and AppStream
# metainfo are shipped by the manifest at build time because extra-data is
# fetched later on the user's machine.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

deb=""
if [ -f claude-desktop-amd64.deb ]; then
  deb="claude-desktop-amd64.deb"
elif [ -f claude-desktop-arm64.deb ]; then
  deb="claude-desktop-arm64.deb"
else
  echo "missing extra-data: claude-desktop deb" >&2
  exit 1
fi

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree. Keep an ar/tar fallback so the script is easy to verify on Debian hosts.
rm -rf stage claude-desktop
mkdir stage
if command -v bsdtar >/dev/null 2>&1; then
  bsdtar -xOf "$deb" 'data.tar*' | bsdtar -xf - -C stage
else
  member="$(ar t "$deb" | grep '^data.tar' | head -n 1)"
  [ -n "$member" ] || { echo "data.tar member not found in .deb" >&2; exit 1; }
  case "$member" in
    *.tar.xz) ar p "$deb" "$member" | tar -xJ -C stage ;;
    *.tar.gz) ar p "$deb" "$member" | tar -xz -C stage ;;
    *.tar.zst) ar p "$deb" "$member" | tar --zstd -x -C stage ;;
    *.tar) ar p "$deb" "$member" | tar -x -C stage ;;
    *) echo "unsupported data archive: $member" >&2; exit 1 ;;
  esac
fi
[ -x stage/usr/lib/claude-desktop/claude-desktop ] || {
  echo "Claude Desktop binary not found in .deb" >&2
  exit 1
}
mv stage/usr/lib/claude-desktop claude-desktop
rm -rf stage "$deb"
[ -x claude-desktop/claude-desktop ] || {
  echo "Claude Desktop binary missing after stage" >&2
  exit 1
}
