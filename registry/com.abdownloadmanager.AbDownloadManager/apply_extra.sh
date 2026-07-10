#!/bin/sh
set -eu

# Runs offline at install time. The upstream artifact is the official Linux
# jpackage app-image tarball: fully self-contained (native launcher + bundled
# JRE + app jars + libskiko). Unpack it and keep the whole app-image directory
# at a stable path the wrapper execs; only X11, libGL, fontconfig and libstdc++
# are resolved from the runtime. The desktop file, icon and AppStream metainfo
# are shipped by the manifest at *build* time (extra-data is fetched later on the
# user's machine, so anything Flatpak must export cannot come from here).

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f abdm.tar.gz ] || { echo "missing extra-data: abdm.tar.gz" >&2; exit 1; }

# org.freedesktop.Platform ships tar + gzip; the archive holds one top-level
# directory, ABDownloadManager/.
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
tar --no-same-owner -xzf abdm.tar.gz
[ -x ABDownloadManager/bin/ABDownloadManager ] || { echo "launcher not found in tarball" >&2; exit 1; }

rm -f abdm.tar.gz
