# FlatPark app discovery & auto-packaging pipeline

A repeatable pipeline — meant to run on a **periodic cadence** and to become
**progressively automated** — for **discovering apps worth listing on FlatPark**
(good apps Flathub doesn't carry) and **packaging them**. Re-run the §1–§2 crawls
regularly to catch new candidates and fresh demand. This file is the **process
only** — the list of which apps were crawled / shipped / rejected is not
maintained here.

> **⚠️ Review gate (must follow).** Never **open a PR to this repo** or **post a
> comment to an upstream repo** without first showing the draft to the maintainer
> and getting an explicit OK. Both are outward-facing. Prepare everything
> (branch, commit, draft PR body / draft comment), **present it, then wait** —
> only act on approval. Internal steps (branch, commit, push, local build/test)
> don't need the gate; the two reviewable actions are **PR creation** and
> **posting upstream**.

## 1. Source candidates — two channels
- **High-star community apps** that ship an official Linux GUI and are **not on
  Flathub** (search GitHub by `topic:linux topic:gtk/qt/electron/tauri/...`).
- **Flathub PRs rejected with the `AI Slop` label.** Many are genuine slop, but
  the net also catches *real* apps rejected on policy grounds (AI-authored
  manifest, "must build from source") — exactly FlatPark's niche.
  Crawl: `gh api search/issues -f q='repo:flathub/flathub is:pr label:"AI Slop" created:>=<date>'`.

## 2. Demand & prior-art check (do per candidate, and record it)
Before investing, gauge whether anyone actually wants it and what's already been
tried — these two crawls show demand directly and surface blockers early:
- **Upstream repo issues** — search the app's own tracker for Flatpak/Flathub
  requests: `gh api search/issues -f q='repo:<owner>/<repo> flatpak in:title,body'`.
  Read them: open requests, +1s, and the **maintainer's stance** (their concerns
  often reveal real blockers — e.g. AB-DM's native-messaging worry).
- **Flathub PRs for this app** — find prior submission attempts and **why they
  closed**: `gh api search/issues -f q='repo:flathub/flathub is:pr <app> in:title'`.
  A stalled/rejected Flathub PR = real demand + FlatPark's opening.

Record the result for the candidate (demand level + known blockers). It drives
the go/no-go decision and the upstream comment in §5.

## 3. Feasibility filter — the hard gates (apply BEFORE packaging)
1. **Not already on Flathub.** Verify: Flathub search + `https://flathub.org/api/v2/appstream/<id>` 404.
2. **Self-contained official Linux binary — prefer `.deb` / `.tar.gz` over AppImage.**
   deb/tar unpack offline with the runtime's `bsdtar`/`tar`; an **AppImage must be
   cracked at install time and its runtime wants libfuse (not in the runtime) —
   this failed for Sniffnet.** AppImage-only → flag and ask first.
3. **Self-contained for its CORE feature.** Reject apps whose headline function
   shells out to a **host toolchain/daemon** not in the sandbox — the GUI merely
   launching is not enough (killed: NetPad→.NET SDK, quickgui→qemu, Guitar→git).
   Check the upstream "Requirements".
4. **No Linux caps that `finish-args` can't grant.** `CAP_NET_RAW` / `CAP_NET_ADMIN`
   have no finish-arg → packet capture / VPN are structurally broken (Sniffnet).
5. **License / content policy.** Proprietary is allowed *with* a `policy.proprietary`
   flag; content/streaming/downloader apps are P2 (ToS/copyright review first).
6. **Rank by fit, not stars.** >~200 stars is "popular enough"; pick by these gates.

## 4. Package & submit
- **Inspect the artifact:** extract (`ar`+`tar`/`bsdtar` for deb, `tar` for tarball,
  `--appimage-extract` for AppImage), `readelf -d` NEEDED vs runtime coverage,
  locate icon/.desktop/metainfo.
- **Pick the runtime:** `org.freedesktop.Platform//25.08` by default (it ships
  GTK3/NSS/CUPS too); `org.gnome.Platform//50` for **GTK / WebKitGTK / Tauri**.
- **Tech recipes:**
  - **Electron** → `base: org.electronjs.Electron2.BaseApp//<ver>` + `zypak-wrapper`
    (keeps Chromium's sandbox, not `--no-sandbox`) + `--unset-env=ELECTRON_RUN_AS_NODE`
    (leaks in from VS Code terminals; the wrapper's own `unset` can't reach zypak children).
  - **Tauri / WebKitGTK** → `WEBKIT_DISABLE_DMABUF_RENDERER=1` (else blank window).
  - Version-stamped top dir → rename to a stable path in `apply_extra`.
  - Missing single lib → supply it as a 2nd extra-data deb pinned on `snapshot.debian.org`
    (Sniffnet's libpcap).
- **Descriptor set** under `registry/<app-id>/`: `flatpark.yml`, `<id>.yml`,
  `<id>.metainfo.xml`, `<id>.desktop`, `<id>.png`, `apply_extra.sh`,
  `<app>-wrapper`, `resolve-update.sh`.
- **Permissions:** tightest `finish-args` that work; don't pre-grant broad host
  access — document optional caps (`~/.ssh`, serial `--device=all`, `--filesystem=home`)
  as opt-in `flatpak override` in the metainfo (electerm).
- **Validate → build → smoke-test:** `read-descriptor.mjs`; `build-app.sh`
  (`appstreamcli compose` must Succeed); install from the signed local repo
  (exercises `apply_extra`); `LD_TRACE_LOADED_OBJECTS=1` → 0 "not found". **The
  build shell is headless** — the GUI render must be confirmed on a real session.
- **Ship:** commit `add: <Name> (<app-id>)` (no `registry` scope) + `Co-Authored-By`
  trailer; **rebase onto `origin/main`**; push. Then **draft the PR (house-style
  "Packaging notes" — numbered sections + collapsible files + validation table)
  and STOP — present it; open it (`gh pr create`) only after approval** (review
  gate). Screenshots hotlinked from upstream (no R2); a GIF/webp is fine
  (appstreamcli accepts it; Flathub wouldn't).

## 5. Engage upstream
- Reuse what §2 found (demand + the maintainer's stated concerns).
- **Draft** a **friendly, non-spammy** comment: community package using *their
  official binary* (unmodified, unaffiliated); install commands + app-page link;
  **address the concerns they already raised**; offer a PR adding Flatpak docs to
  their README; `@`-mention the maintainer at the ask. **STOP — present the draft;
  post only after approval** (review gate; never auto-post). Don't re-post if
  they've said no.

## 6. Cadence & automation
- **Periodic re-crawl** (§1–§2): re-run the two source crawls + per-candidate
  demand checks on a regular schedule to catch newly-released apps and freshly
  AI-slop-rejected Flathub PRs.
- **Already automated:** each app's `resolve-update.sh` lets FlatPark re-pin and
  rebuild on new upstream releases (no manual version bumps).
- **Toward more automation:** the §1–§3 crawl + gate steps are scriptable into a
  candidate shortlist; §4 packaging is templated per runtime/tech recipe. Keep
  the **review gate** (§ top) on the two outward-facing actions even as the rest
  is automated.
