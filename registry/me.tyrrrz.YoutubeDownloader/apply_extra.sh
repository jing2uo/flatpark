#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. The upstream
# artifact is the official self-contained .NET / Avalonia desktop build: a flat
# zip (no top-level dir) holding the native apphost launcher (YoutubeDownloader),
# its bundled CoreCLR and SkiaSharp .so, and the managed .dll assemblies. We
# unpack it to a stable path the wrapper execs: /app/extra/ytd. The desktop
# file, icon and AppStream metainfo are shipped by the manifest at *build* time
# — extra-data is fetched later on the user's machine, so anything Flatpak must
# export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f ytd.zip ] || { echo "missing extra-data: ytd.zip" >&2; exit 1; }
[ -f ffmpeg.zip ] || { echo "missing extra-data: ffmpeg.zip" >&2; exit 1; }

# The Platform runtime has no unzip, but bsdtar (libarchive) reads zip directly.
rm -rf ytd
mkdir ytd
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar --no-same-owner -xf ytd.zip -C ytd
[ -f ytd/YoutubeDownloader.dll ] || { echo "YoutubeDownloader.dll not found in zip" >&2; exit 1; }

# Stage the ffmpeg binary next to the app so YoutubeDownloader auto-detects it
# (it probes AppContext.BaseDirectory). The archive also carries ffprobe/ffplay,
# which the app never calls — extract only ffmpeg to keep the install lean.
bsdtar --no-same-owner -xf ffmpeg.zip -C ytd ffmpeg
[ -f ytd/ffmpeg ] || { echo "ffmpeg not found in ffmpeg.zip" >&2; exit 1; }

# The publish zip does not carry the unix executable bit; the apphost launcher
# (and the createdump helper next to it) plus ffmpeg must be made executable.
chmod +x ytd/YoutubeDownloader ytd/createdump ytd/ffmpeg 2>/dev/null || \
  chmod +x ytd/YoutubeDownloader ytd/ffmpeg
rm -f ytd.zip ffmpeg.zip
