#!/bin/sh
set -eu

# Runs offline at install time. Upstream ships BrowserOS as a Debian package;
# unpack its self-contained Chromium/Cobalt application into a stable path that
# cobalt.ini can reference.
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f browseros.deb ] || { echo "missing extra-data: browseros.deb" >&2; exit 1; }

rm -rf stage browseros
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf browseros.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/usr/lib/browseros/browseros ] || { echo "browseros binary not found in .deb" >&2; exit 1; }
mv stage/usr/lib/browseros browseros

# cobalt expects a sandbox helper at the browser path. The stub makes Chromium
# fall back to the zypak/no-setuid path provided by the Chromium base app.
install -Dm755 /app/share/browseros/stub_sandbox.sh browseros/chrome-sandbox

rm -rf stage browseros.deb
[ -x browseros/browseros ] || { echo "browseros binary missing after stage" >&2; exit 1; }
