#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. TradingView
# ships as an Electron .deb with the complete app under /opt/TradingView.
# Exported desktop metadata is installed by the manifest at build time; extra
# data is fetched later on the user's machine, so it only stages the runtime app.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f tradingview.deb ] || { echo "missing extra-data: tradingview.deb" >&2; exit 1; }

rm -rf stage tradingview
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf tradingview.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/opt/TradingView/tradingview ] || { echo "TradingView binary not found in .deb" >&2; exit 1; }
mv stage/opt/TradingView tradingview
rm -rf stage tradingview.deb
[ -x tradingview/tradingview ] || { echo "TradingView binary missing after stage" >&2; exit 1; }
