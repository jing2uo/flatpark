#!/bin/sh
set -eu

# Runs offline at install time. Upstream ships the official Linux build as a
# tarball containing a single frame.app directory with the frame binary, bundled
# ffmpeg/ffprobe, supporting libraries, desktop metadata and icons. Rename it to
# a stable path so the wrapper can exec it across updates.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f frame-linux-x86_64.tar.gz ] || { echo "missing extra-data: frame-linux-x86_64.tar.gz" >&2; exit 1; }

# --no-same-owner: the tarball records uid/gid 1001, and a system-wide install
# runs apply_extra as root with every capability dropped, where restoring that
# owner fails and aborts the unpack even though every member extracted fine.
rm -rf frame.app
tar --no-same-owner -xzf frame-linux-x86_64.tar.gz
[ -d frame.app ] || { echo "frame.app directory not found in tarball" >&2; exit 1; }

rm -rf frame
mv frame.app frame

[ -x frame/bin/frame ] || { echo "frame binary not found in tarball" >&2; exit 1; }
[ -x frame/bin/binaries/ffmpeg-x86_64-unknown-linux-gnu ] || { echo "bundled ffmpeg not found in tarball" >&2; exit 1; }
[ -x frame/bin/binaries/ffprobe-x86_64-unknown-linux-gnu ] || { echo "bundled ffprobe not found in tarball" >&2; exit 1; }

rm -f frame-linux-x86_64.tar.gz
