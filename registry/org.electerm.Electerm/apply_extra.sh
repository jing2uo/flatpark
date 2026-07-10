#!/bin/sh
set -eu

# Runs offline at install time. Upstream ships the Electron app as a tarball
# whose single top-level directory is version-stamped (electerm-<ver>-linux-x64).
# Unpack it and rename that directory to a stable path the wrapper execs.
# Everything Electron needs (Chromium, ffmpeg, app.asar) is inside; only the
# system GTK3/NSS/CUPS/X11 stack comes from the runtime. The desktop file, icon
# and AppStream metainfo are shipped by the manifest at build time.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f electerm.tar.gz ] || { echo "missing extra-data: electerm.tar.gz" >&2; exit 1; }

# org.freedesktop.Platform ships tar + gzip.
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
tar --no-same-owner -xzf electerm.tar.gz
d="$(echo electerm-*-linux-x64)"
[ -d "$d" ] || { echo "electerm app dir not found in tarball" >&2; exit 1; }
rm -rf electerm
mv "$d" electerm
[ -x electerm/electerm ] || { echo "electerm binary not found" >&2; exit 1; }

rm -f electerm.tar.gz
