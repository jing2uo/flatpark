#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The upstream tarball is
# the official portable Linux build: a versioned top directory with the deadbeef
# executable, bundled libraries, plugins, documentation and pixmaps. Rename it to
# a stable path so the wrapper can exec it across updates.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f deadbeef-static.tar.bz2 ] || { echo "missing extra-data: deadbeef-static.tar.bz2" >&2; exit 1; }

tar -xjf deadbeef-static.tar.bz2
app_dir="$(find . -maxdepth 1 -type d -name 'deadbeef-*' | sort | head -n1)"
[ -n "$app_dir" ] || { echo "no deadbeef directory in tarball" >&2; exit 1; }

rm -rf deadbeef
mv "$app_dir" deadbeef

[ -x deadbeef/deadbeef ] || { echo "deadbeef executable not found in tarball" >&2; exit 1; }

rm -f deadbeef-static.tar.bz2
