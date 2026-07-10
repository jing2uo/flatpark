#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# RichEZFast as a .deb with the full application under /opt/apps/RichEZFast.
# The wrapper runs this staged tree directly from /app/extra/richeasy and keeps
# HOME redirected into the writable per-app data directory.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f richeasy.deb ] || { echo "missing extra-data: richeasy.deb" >&2; exit 1; }

rm -rf stage richeasy
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf richeasy.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/opt/apps/RichEZFast/RichEZFast ] || { echo "RichEZFast binary not found in .deb" >&2; exit 1; }
mv stage/opt/apps/RichEZFast richeasy
rm -rf stage richeasy.deb
[ -x richeasy/RichEZFast ] || { echo "RichEZFast binary missing after stage" >&2; exit 1; }

if [ -d richeasy/userdata ]; then
    mv richeasy/userdata richeasy/userdata.dist
fi

for dir in Log cache grpc_flag userdata; do
    rm -rf "richeasy/$dir"
    ln -s "/var/data/RichEZFast/$dir" "richeasy/$dir"
done
