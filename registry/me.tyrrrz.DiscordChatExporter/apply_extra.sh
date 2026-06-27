#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. The upstream
# artifact is the official self-contained .NET / Avalonia desktop build: a flat
# zip (no top-level dir) holding the native apphost launcher
# (DiscordChatExporter), its bundled CoreCLR and SkiaSharp .so, and the managed
# .dll assemblies. We unpack it to a stable path the wrapper execs:
# /app/extra/dce. The desktop file, icon and AppStream metainfo are shipped by
# the manifest at *build* time — extra-data is fetched later on the user's
# machine, so anything Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f dce.zip ] || { echo "missing extra-data: dce.zip" >&2; exit 1; }

# The Platform runtime has no unzip, but bsdtar (libarchive) reads zip directly.
rm -rf dce
mkdir dce
bsdtar -xf dce.zip -C dce
[ -f dce/DiscordChatExporter.dll ] || { echo "DiscordChatExporter.dll not found in zip" >&2; exit 1; }

# The publish zip does not carry the unix executable bit; the apphost launcher
# (and the createdump helper next to it) must be made executable.
chmod +x dce/DiscordChatExporter dce/createdump 2>/dev/null || chmod +x dce/DiscordChatExporter
rm -f dce.zip
