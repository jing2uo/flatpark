#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The upstream Debian
# package is a plain FHS tree. Its payload is a small Rust launcher at
# usr/bin/aeroftp plus the real application under usr/lib/aeroftp: aeroftp.bin
# (the Tauri GUI), aeroftp-cli, aeroftp-dispatch and two shell helpers. We stage
# the launcher together with its lib/ sibling at a stable path the wrapper
# expects: /app/extra/aeroftp/{bin,lib}. Keeping bin/ and lib/ as siblings
# matters — the launcher resolves the application directory relative to its own
# executable (<exe_dir>/../lib/aeroftp) and refuses to start otherwise.
#
# Deliberately not staged: the polkit action and aeroftp-update-helper (the
# in-app updater installs a .deb/.rpm through pkexec, which cannot work from a
# read-only Flatpak install — Flatpak delivers updates instead), the
# nautilus-python extension (it would have to live in the host's Nautilus), and
# the MIME-type icons for AeroFTP's own file formats. The desktop file, app icon
# and AppStream metainfo are shipped by the manifest at *build* time — extra-data
# is fetched later on the user's machine, so anything Flatpak must export cannot
# come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f aeroftp.deb ] || { echo "missing extra-data: aeroftp.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb
# ar container directly; pipe its data member into a second bsdtar to unpack the
# FHS tree (the inner data.tar compression is auto-detected).
rm -rf stage aeroftp
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf aeroftp.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/usr/bin/aeroftp ] || { echo "aeroftp launcher not found in .deb" >&2; exit 1; }
[ -f stage/usr/lib/aeroftp/aeroftp.bin ] || { echo "aeroftp.bin not found in .deb" >&2; exit 1; }

mkdir -p aeroftp/bin aeroftp/lib
mv stage/usr/bin/aeroftp aeroftp/bin/aeroftp
mv stage/usr/lib/aeroftp aeroftp/lib/aeroftp
rm -f aeroftp/lib/aeroftp/aeroftp-update-helper
rm -rf stage aeroftp.deb
chmod +x aeroftp/bin/aeroftp aeroftp/lib/aeroftp/aeroftp.bin
