---
title: Publishing guide
description: How to add an app to FlatPark — the descriptor, manifest, and auto-update resolver.
group: Docs
order: 1
---

Any app with a public download is welcome — FlatPark does not host builds. As
long as the app ships an official installer or prebuilt archive at a stable,
public release URL (extra-data style), it can be added here. FlatPark fetches it
at build, pins it, and signs the result.

That means a `.deb`, `.rpm`, `.tar.gz`, zip, or an official installer script is
all upstream needs to provide. **Electron and Tauri apps are welcome**, and so
are **closed-source apps** — the license is not the bar; where the bytes come
from is. Three packages in the registry are worth reading before you write your
own:

- **Electron** —
  [`pro.affine.AFFiNE`](https://github.com/flatpark/flatpark/tree/main/registry/pro.affine.AFFiNE)
  and [`org.electerm.Electerm`](https://github.com/flatpark/flatpark/tree/main/registry/org.electerm.Electerm):
  the Electron base app plus `zypak-wrapper`, so Chromium keeps its internal
  sandbox.
- **Tauri / WebKitGTK** —
  [`com.ccswitch.desktop`](https://github.com/flatpark/flatpark/tree/main/registry/com.ccswitch.desktop):
  the fullest Tauri example. Its wrapper exports
  `WEBKIT_DISABLE_DMABUF_RENDERER=1` (without it WebKitGTK paints a blank
  window under many drivers), and it gets a working system tray by building the
  Ayatana appindicator stack — which the GNOME runtime doesn't ship, and which
  Tauri's `tray-icon` `dlopen`s and panics without — from Flathub's
  `shared-modules` recipe, with every git source pinned to an immutable commit.
  Its `finish-args` are also a good model for scoping: it grants the individual
  CLI config paths it manages rather than `--filesystem=home`.
- **Host-dependent behavior, payload untouched** —
  [`io.enpass.Enpass`](https://github.com/flatpark/flatpark/tree/main/registry/io.enpass.Enpass):
  Enpass validates the browser behind its extension's localhost connection by
  running `lsof` and reading `/proc`, which can't work from inside the sandbox.
  Rather than patch the vendor binary, the package puts small `lsof`/`readlink`/
  `cat` shims on `PATH` that forward to the host via `flatpak-spawn --host`, and
  `LD_PRELOAD`s a tiny `getpid` override. The shipped Enpass binary is still the
  vendor's own, byte for byte. Note what this costs: it needs
  `--talk-name=org.freedesktop.Flatpak`, normally an auto-reject, so the package
  declares it under `policy.dangerous_permissions` and argues for it — expect
  that level of scrutiny if you go this route.

## Add an app

Create one directory under `registry/` named exactly for the app id:

```text
registry/com.example.App/
  flatpark.yml             # the descriptor (below)
  com.example.App.yml      # the Flatpak manifest
  com.example.App.metainfo.xml
  com.example.App.svg
  resolve-update.sh        # optional: upstream update resolver
```

Then validate and build locally:

```sh
node scripts/read-descriptor.mjs registry/com.example.App/flatpark.yml
./scripts/publish.sh --verify com.example.App
```

### Test without polluting your everyday Flatpak

`publish.sh --verify` adds a local `file://` remote named `flatpark` to your
**`--user`** installation and installs the app there. The scratch repo
(`out/repo`) is rebuilt on every run, so its commits drift from whatever you
have installed — and if you _also_ run the real FlatPark remote in that same
installation, `flatpak update` eventually fails with `Update is older than
current version` and leaves orphaned refs. Keep test builds in a separate,
throwaway installation so they never touch your normal Flatpak state:

```sh
# one-time: create an isolated installation named "test"
sudo install -d /etc/flatpak/installations.d
printf '[Installation "test"]\nPath=%s/.local/share/flatpak-test\nDisplayName=FlatPark test\n' \
  "$HOME" | sudo tee /etc/flatpak/installations.d/test.conf >/dev/null

# install the freshly built app into it, then wipe it when done
flatpak --installation=test remote-add --no-gpg-verify flatpark "file://$PWD/out/repo"
flatpak --installation=test install flatpark com.example.App
flatpak --installation=test uninstall --all
```

Open a PR. `pr-checks` validates the descriptor, runs the test suite, checks for
dead links, and builds the changed app — including from a fork, once a maintainer
approves the workflow run (fork builds get no secrets and are signed with a
throwaway key). On merge, `publish` builds and publishes it.

## `flatpark.yml` schema

```yaml
id: com.example.App           # required — must match the directory name
name: Example App             # required
summary: One-line description # required
website: https://example.com/ # optional
source_url: https://github.com/you/packaging  # optional
build:
  manifest: com.example.App.yml  # required — relative to this directory
  branch: stable              # optional (default: stable)
  mode: extra-data            # packaging mode (internal label)
catalog:                      # optional — drives the catalog page
  category: Productivity
  tags:
    - Example
    - Demo
update:                       # optional — enables auto pin-bump PRs
  command: ./resolve-update.sh
policy:                       # optional — informational
  proprietary: true
  extra_data_first: true
  dangerous_permissions: []
```

Only `id`, `name`, `summary`, and `build.manifest` are required.

## Auto-updating (optional)

Version checking is **always a script** — there are no declarative checker types
to learn. Point `update.command` at a `resolve-update.sh` that figures out the
current release however it likes (a JSON/HTML endpoint, the GitHub API, a fixed
URL, whatever) and prints this JSON to stdout (logs go to stderr):

```json
{
  "version": "1.2.3",
  "releaseDate": "2026-06-19",
  "sources": [
    { "filename": "installer.sh", "url": "https://example.com/installer-1.2.3.sh" }
  ]
}
```

The script does **no hashing** — it just resolves the version and the real
download URL(s). FlatPark downloads each source, computes `sha256`/`size`, and
rewrites the manifest's managed block (mark it with these comments so FlatPark
knows what to rewrite):

```yaml
# BEGIN MANAGED EXTRA-DATA
- type: extra-data
  filename: installer.sh
  only-arches:
    - x86_64
  url: https://example.com/installer-1.2.3.sh
  sha256: <computed by FlatPark>
  size: <computed by FlatPark>
# END MANAGED EXTRA-DATA
```

**Where the version lives:** in the AppStream metainfo `<releases>`, not in
extra-data (Flatpak has no version field there). The latest `<release version>`
is the comparison anchor: each day `update-check` runs your resolver, and only
when its `version` differs from the metainfo does it download, re-pin, prepend a
new `<release>`, and open a PR. A maintainer merges it, which rebuilds and
republishes just that app.

### Resolver templates

GitHub releases (pick the right asset):

```sh
#!/usr/bin/env bash
set -euo pipefail
repo="owner/name"
rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
url="$(jq -r '.assets[]|select(.name|test("linux.*x86_64.*\\.tar\\.gz$")).browser_download_url' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v,releaseDate:$d,sources:[{filename:"app.tar.gz",url:$u}]}'
```

A vendor JSON endpoint (version in one field, URL in another):

```sh
#!/usr/bin/env bash
set -euo pipefail
meta="$(curl -fsSL https://vendor.example/latest.json)"
version="$(jq -r '.version' <<<"$meta")"
url="$(jq -r '.assets[]|select(.name|test("linux-x86_64\\.deb$")).url' <<<"$meta")"
date="$(jq -r '.published_at // ""' <<<"$meta" | cut -c1-10)"
jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v,releaseDate:$d,sources:[{filename:"app.deb",url:$u}]}'
```

A fixed URL that simply embeds the version:

```sh
#!/usr/bin/env bash
set -euo pipefail
version="$(curl -fsSL https://vendor.example/latest.txt)"
jq -n --arg v "$version" \
  '{version:$v,sources:[{filename:"app.bin",url:("https://vendor.example/app-"+$v+".bin")}]}'
```

## Sandbox & permissions

Ship the tightest `finish-args` that still let the app's core feature work.
FlatPark surfaces permissions on each app's detail page, and broad grants will be
questioned in review.

**Optional capabilities are not granted by default.** If the app can do more with
a broader permission — reading host SSH keys, serial devices, the whole home
directory — leave it out of `finish-args` and instead document the `flatpak
override` command that turns it on, so each user decides for themselves. Put that
documentation in the app's `metainfo.xml` description (it renders on the app's
page), and explain in the PR body why the capability exists at all. See
[`org.electerm.Electerm`](https://github.com/flatpark/flatpark/tree/main/registry/org.electerm.Electerm)
for the pattern:

```xml
<p>A few optional capabilities are not granted by default; enable the ones you
   need with "flatpak override":</p>
<ul>
  <li>Reuse your existing host SSH keys: <code>flatpak override --user --filesystem=~/.ssh:ro org.electerm.Electerm</code></li>
  <li>Serial-port connections: <code>flatpak override --user --device=all org.electerm.Electerm</code></li>
</ul>
```

If a permission is genuinely required for the app to function at all, keep it in
`finish-args`, list it under `policy.dangerous_permissions` if it is high-risk,
and justify it in the PR. Sandbox-escape permissions (`--filesystem=host`,
`--filesystem=/`, `--talk-name=org.freedesktop.Flatpak`) are rejected by default;
the only way past that is to declare the permission under
`policy.dangerous_permissions` and make the case for it, which earns a human
review rather than an automatic pass (Enpass is the one package that has).

## What we review (and what gets a PR rejected)

Every PR is checked against the full
[review runbook](https://github.com/flatpark/flatpark/blob/main/docs/pr-review.md).
To pre-empt the common rejections, make sure your submission:

- **Has actually been installed and run** — before opening the PR, build it,
  `flatpak install` it into the isolated test installation above, launch the app,
  and confirm the core feature works. A manifest that only passes `--verify` is
  not tested. Record in the PR body what you exercised and what you couldn't
  (GUI rendering on a real session, login flows, hardware paths).
- **Grants no optional permission by default** — broad capabilities are
  documented as opt-in `flatpak override` commands in the metainfo, not baked
  into `finish-args`; anything that stays in `finish-args` is justified in the PR.
- **Pins every remote source** — `extra-data`/`archive` need `sha256` (and
  `extra-data` a non-zero `size`); `git` needs an immutable `commit`. (`type:
  file` packaging files need no pin.)
- **Downloads only from the official channel** — the vendor's own domain or the
  genuine upstream repo, never a personal account or a mirror.
- **Repackages the official build unmodified** — `build-commands` only install
  the wrapper/desktop/metainfo/icon and an `apply_extra` that unpacks the
  download; don't patch, recompile, or change the app's behavior. Adapting the
  app to the sandbox *from the outside* is fine — wrapper env vars, missing
  libraries built as extra modules, `PATH` shims (see cc-switch and Enpass
  above) — as long as the vendor's own bytes are what actually run.
- **Uses a plain resolver** — `update.command` is a simple relative script path
  like `./resolve-update.sh` (it runs in CI).
- **Declares its `policy`** — set `proprietary` honestly and list any high-risk
  permissions in `dangerous_permissions`.
- **Doesn't fetch-and-run arbitrary code** — a vendor's own self-updater writing
  into the app's data directory is fine; downloading and executing unpinned
  third-party code is not.
- **Avoids sandbox-escape permissions** — no `--filesystem=host`,
  `--filesystem=/`, or `--talk-name=org.freedesktop.Flatpak`, unless declared in
  `policy.dangerous_permissions` and argued for.
- **Ships an accepted artifact** — tarball, `.deb`, `.rpm`, zip, or an official
  installer. **AppImage is not accepted.**
- **Has a legitimate purpose** — non-FOSS is fine; piracy, malware, and trademark
  impersonation are not.

Non-FOSS commercial apps (e.g. brokers) are welcome on the same bar: official
source, unmodified, pinned.
