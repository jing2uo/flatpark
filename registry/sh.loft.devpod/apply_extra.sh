#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Upstream ships DevPod
# as a .deb containing a Tauri/WebKitGTK desktop binary and a static Go CLI. Keep
# both under a stable path. The GUI looks for devpod-cli next to the desktop
# binary, so keep the upstream CLI as devpod-bin and put our host-spawn wrapper
# in its place.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f devpod.deb ] || { echo "missing extra-data: devpod.deb" >&2; exit 1; }

rm -rf stage devpod
mkdir stage
bsdtar -xOf devpod.deb 'data.tar*' | bsdtar -xf - -C stage
[ -x "stage/usr/bin/DevPod Desktop" ] || { echo "DevPod desktop binary not found in .deb" >&2; exit 1; }
[ -x stage/usr/bin/devpod-cli ] || { echo "devpod-cli binary not found in .deb" >&2; exit 1; }

mkdir devpod
mv "stage/usr/bin/DevPod Desktop" "devpod/DevPod Desktop"
mv stage/usr/bin/devpod-cli devpod/devpod-bin
wrapper="${DEVPOD_CLI_WRAPPER:-/app/bin/devpod-cli}"
[ -x "$wrapper" ] || { echo "devpod-cli wrapper not found: $wrapper" >&2; exit 1; }
cp "$wrapper" devpod/devpod-cli
rm -rf stage devpod.deb
chmod +x "devpod/DevPod Desktop" devpod/devpod-bin devpod/devpod-cli
