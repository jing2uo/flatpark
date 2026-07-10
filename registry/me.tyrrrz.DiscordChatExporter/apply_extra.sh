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

rm -rf dce
mkdir dce
# --no-same-owner is required, not cosmetic. For a system-wide install Flatpak
# runs apply_extra as root with every capability dropped, and the zip records
# uid/gid 1001 in its Info-ZIP extra fields. Under uid 0 bsdtar restores
# ownership by default, so it chowns each member to 1001 and gets EPERM without
# CAP_CHOWN. libarchive counts that as a warning, and a warning still makes
# bsdtar exit 1 — every file extracts, yet set -e aborts the install.
bsdtar --no-same-owner -xf dce.zip -C dce
[ -f dce/DiscordChatExporter.dll ] || { echo "DiscordChatExporter.dll not found in zip" >&2; exit 1; }

# The apphost launcher already carries 0755, but the createdump helper beside it
# does not; make both executable regardless.
chmod +x dce/DiscordChatExporter dce/createdump 2>/dev/null || chmod +x dce/DiscordChatExporter
rm -f dce.zip
