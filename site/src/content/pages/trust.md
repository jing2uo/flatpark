---
title: Trust & safety
description: How FlatPark repackages, pins, signs, and sandboxes the apps it hosts.
group: Project
order: 3
---

FlatPark's whole model is repackaging official downloads — not rebuilding them.
Here is exactly what that means for what you install.

## extra-data only

FlatPark downloads the **vendor's own release** at build time and wraps it as a
Flatpak. The bytes you run are the official binary, not a FlatPark rebuild. If
the vendor's download changes, the next build picks it up.

## Pinned and signed

Each release is pinned by `sha256` and size in the manifest, so a build cannot
silently swap the binary. The published repo is **GPG-signed**, and your client
verifies that signature on install and update.

## Tight sandbox

FlatPark prefers the minimum `finish-args` that still let an app work, and avoids
broad grants like `--filesystem=home`. Every app page lists its exact
permissions with a plain-language risk label, so you can see what an app can
reach before installing it.

## Community package, not endorsement

FlatPark is independent and **not affiliated with the apps it packages**. An
app's presence here is not an endorsement by its vendor unless the app's own
page says so. Each package links to the upstream source and website so you can
check provenance yourself.

## Verifying what you install

- Read the **permissions** panel on the app's page.
- Follow the **Source** and **Website** links to upstream.
- Install via the signed remote (see the [user guide](/guide/)); your client
  checks the signature for you.
