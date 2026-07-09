---
title: Listing policies
description: What FlatPark accepts, the review bar, and the de-listing process.
group: Project
order: 2
---

FlatPark hosts apps that ship a public, stable release URL and can be packaged as
[extra-data](/trust/). These are the rules for getting listed and staying
listed.

## What we host

Any app with an official, prebuilt download at a stable public URL — an
installer, `.deb`, `.rpm`, or tarball. FlatPark fetches it at build, pins it by
checksum, and signs the result. It never builds the app itself from source and
never re-hosts the binary. (AppImage is not accepted.) A package may build
supporting libraries the runtime lacks from pinned source — the application is
always the vendor's own binary.

Toolkit and license don't gate a listing. **Electron and Tauri apps are welcome**
— the registry already ships both — and so are **closed-source apps**. If
upstream publishes a `.deb`, `.rpm`, tarball, zip, or official installer, it can
be packaged here.

## Requirements

- A **stable, public release URL** for the official build (not behind a login).
- An **AppStream metainfo** file (`<id>.metainfo.xml`) with id, name, summary,
  license, and at least one description paragraph.
- The **id matches reverse-DNS** and the registry directory name.
- The **current runtime major**, matching the rest of the catalog. Pinning an
  older major to work around a build break is not accepted — one straggler makes
  every user keep a second runtime on disk.
- The **tightest `finish-args`** that still work. Optional capabilities are **not
  granted by default**: leave them out and document the `flatpak override`
  command that enables them in the app's description, so each user decides. A
  permission the app truly needs to function stays in `finish-args` and is
  justified in the PR.
- **Tested locally before the PR** — the submitter has built the app, installed
  it with `flatpak install`, launched it, and confirmed the core feature works.
- A stated **license** for the app.

## Vibe-coded apps

Apps built with AI assistance ("vibe coding") are welcome. They are judged on the
same bar as any other app: development history, upstream activity, and observed
quality — not on how they were written.

## Review

Every submission is reviewed (AI-assisted) against a published
[review runbook](https://github.com/flatpark/flatpark/blob/main/docs/pr-review.md).
The trust question is **where the bytes you run come from**, not the license:

- FlatPark either verifies source-built packages against their public source, or
  repackages an **official upstream prebuilt unmodified** — the bytes you run are
  the vendor's own.
- Official prebuilts must come from the real upstream/vendor release channel. A
  binary hosted on a submitter's personal account or a mirror, or one rebuilt or
  patched during packaging, is rejected.
- Every download is pinned by `sha256` (and size), and any git source by an
  immutable commit, so a build cannot silently swap it.
- Sandbox-escape permissions (host filesystem, the Flatpak control bus) are
  rejected; broad grants must be justified.
- **Non-FOSS is allowed** — openness is not the bar. We reject on purpose, not
  license: piracy, malware, trademark impersonation, or anything illegal to
  distribute.

We don't claim every open-source prebuilt is byte-for-byte source-verified — only
that it is an official upstream build, pinned and unmodified.

## De-listing

An app can be removed from FlatPark when:

- its official download URL disappears or stops being maintained;
- upstream is abandoned, or a release turns out to be malicious;
- it requests dangerous permissions that cannot be justified; or
- the vendor asks us to remove it.

The process is public: an issue is opened describing the reason, a maintainer
reviews it, and on removal the app's directory is deleted from the registry and
its ref is dropped from the repo. Already-installed copies keep working until the
user uninstalls them.
