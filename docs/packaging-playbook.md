# FlatPark packaging playbook — end-to-end spec

The **canonical process** for taking an app from *"found a candidate"* to *"packaged,
tested, listed, and upstream informed."* **Every packaging run follows this.** It ties
together the pieces that already have their own docs and adds the parts that don't:

- **Discovery detail** (crawl queries, gates) → [`discovery-pipeline.md`](discovery-pipeline.md)
- **Descriptor / manifest schema, local build & test, auto-update resolver** →
  [contributing guide](https://flatpark.org/contributing/)
  (source: [`site/src/content/pages/contributing.md`](../site/src/content/pages/contributing.md))
- **The review bar a PR is graded against** → [`pr-review.md`](pr-review.md)

This file is the **spine**; those are the deep dives. Where they conflict, **this file wins**
and the other should be updated to match.

---

## 0. Golden rules (read every time)

1. **Repackage the official binary, unmodified.** extra-data only — fetch the vendor's
   own release, unpack it, wrap it. Never patch or recompile the payload. Adapting it to
   the sandbox from the *outside* — wrapper env, extra modules for missing libs, `PATH`
   shims — is fine; the bytes that run must still be the vendor's.
2. **Rank by fit, not stars.** Not-on-Flathub + clean sandbox/extra-data + maintained +
   genuinely useful. >~200 stars is already "popular enough."
3. **Describe only what *our* package does.** Do **not** claim upstream is broken, needs a
   workaround, or that we "fix"/"sidestep"/"avoid" their bug — in manifest comments, PRs,
   **or** upstream messages. See §7.1; this is a hard rule (we've already had to walk one
   back publicly).
4. **The review gate — two outward-facing actions require an explicit human OK first:**
   **(a) opening a PR to this repo, (b) posting anything to an upstream repo.** Prepare
   everything, **present the draft, then wait.** Internal steps (branch, commit, push,
   local build/test) don't need the gate.
5. **Never open a PR for an app you haven't run.** Build it, `flatpak install` it into the
   isolated test installation, launch it, exercise the core feature (§4). A manifest that
   only validates is not tested.
6. **Never post upstream until the package is live and smoke-tested.** A 404 install link
   or a crash-on-launch is worse than staying silent — especially with maintainers already
   sensitive about AI-assisted work.
7. **Never self-merge.** Open the PR; leave the merge to the maintainer.
8. **De-list on request, no argument.** If an upstream says "please don't," remove it right
   away and don't re-post.

---

## 1. Discover — two channels

Full crawl queries live in [`discovery-pipeline.md`](discovery-pipeline.md) §1–2. In short:

- **Community (high-star, not on Flathub).** Apps shipping an official Linux GUI binary,
  searched by GitHub topics (`topic:linux topic:electron/tauri/gtk/qt/...`). Weaker demand
  signal, but real products.
- **Flathub `AI Slop`-labelled PRs.** Rejected on policy grounds (AI-authored manifest,
  "must build from source") — often *real* apps in exactly FlatPark's niche. Higher demand
  signal (someone already tried to submit it).
  `gh api search/issues -f q='repo:flathub/flathub is:pr label:"AI Slop" created:>=<date>'`

**Per candidate, record demand + prior art** (drives go/no-go and the §7 comment):
- Upstream tracker: search their own issues for Flatpak/Flathub requests + the **maintainer's
  stance** (their concerns reveal real blockers).
- Prior Flathub PRs for this app and **why they closed**.

Re-run these crawls on a **periodic cadence** — the point is catching newly-released apps and
freshly-rejected Flathub PRs, not a one-off sweep.

## 2. Gate — feasibility (apply BEFORE packaging)

The hard gates (detail in [`discovery-pipeline.md`](discovery-pipeline.md) §3):

1. **Not on Flathub.** Verify by **name** via Flathub search **and** `/api/v2/appstream/<id>`
   404 — don't trust a guessed app-id (PixiEditor slipped through once by only checking the
   `com.` variant).
2. **Self-contained official Linux binary — `.deb`/`.rpm`/`.tar.gz`/zip/official installer.**
   These unpack offline with the runtime's `bsdtar`/`tar`. **AppImage is not accepted**
   (needs libfuse, not in the runtime); AppImage-only upstream → drop the candidate.
3. **Self-contained for its CORE feature.** Reject if the headline function shells out to a
   host toolchain/daemon not in the sandbox (killed: NetPad→.NET SDK, quickgui→qemu).
4. **No Linux caps `finish-args` can't grant** (`CAP_NET_RAW`/`CAP_NET_ADMIN` → packet
   capture / VPN are structurally impossible).
5. **License / content policy.** Proprietary is fine *with* the `policy.proprietary` flag;
   streaming/downloader/content apps are P2 (ToS/copyright review first).

Neither the toolkit nor the license is a gate: Electron and Tauri apps are welcome
(recipes in §3), as are closed-source ones. Upstream shipping a `.deb`/`.rpm`/tarball/zip/
official installer is what qualifies an app.

## 3. Package

Detail + schema in the [contributing guide](https://flatpark.org/contributing/). The shape:

- **Inspect the artifact.** Extract (`bsdtar` for `.deb`/zip, `tar` for tarball), check
  `readelf -d` NEEDED against the runtime's coverage, locate the icon / `.desktop` / metainfo,
  find the largest icon available.
- **Pick the runtime.** `org.freedesktop.Platform//25.08` by default; `org.gnome.Platform//50`
  for GTK / WebKitGTK / Tauri. **Always the major the rest of the catalog is on** — match what
  the existing manifests pin, never an older major to dodge a build break. A single straggler
  forces every user to keep a second runtime major on disk. If an app genuinely can't run on the
  current major, that's a **flag-and-ask**, not a quiet downgrade.
- **Tech recipes.**
  - **Electron** → `base: org.electronjs.Electron2.BaseApp//<ver>`, run via `zypak-wrapper`
    so Chromium keeps its **internal sandbox through Zypak's default entrypoint** (do **not**
    reach for `--no-sandbox`), plus `--unset-env=ELECTRON_RUN_AS_NODE`. Template:
    [`registry/pro.affine.AFFiNE`](../registry/pro.affine.AFFiNE),
    [`registry/org.electerm.Electerm`](../registry/org.electerm.Electerm).
  - **Tauri / WebKitGTK** → `WEBKIT_DISABLE_DMABUF_RENDERER=1` in the wrapper (else blank
    window). If the app has a **tray icon**, Tauri's `tray-icon` `dlopen`s
    libayatana-appindicator and *panics* when it's absent — the GNOME runtime doesn't ship
    it, so build the Ayatana stack (intltool → libdbusmenu → ayatana-ido →
    libayatana-indicator → libayatana-appindicator) from Flathub's `shared-modules` recipe,
    git sources pinned to commits. Reference:
    [`registry/com.ccswitch.desktop`](../registry/com.ccswitch.desktop).
  - **Host-dependent behavior** (the app shells out to host tools or probes `/proc`) → adapt
    from the *outside*, never by patching the payload: wrapper env, `PATH` shims that
    `flatpak-spawn --host` the tool, an `LD_PRELOAD` shim. Reference:
    [`registry/io.enpass.Enpass`](../registry/io.enpass.Enpass) (`lsof`/`readlink`/`cat`
    shims + a `getpid` override for browser-extension validation). This costs
    `--talk-name=org.freedesktop.Flatpak` — declare it in `policy.dangerous_permissions`,
    justify it, and expect human review; it is otherwise an auto-reject.
  - **Bundled JRE** (JavaFX/Java apps) → [`registry/net.huangyuhui.hmcl`](../registry/net.huangyuhui.hmcl).
  - Version-stamped top dir → rename to a stable path in `apply_extra`.
- **Descriptor set** under `registry/<app-id>/`: `flatpark.yml`, `<id>.yml`, `<id>.metainfo.xml`,
  `<id>.desktop`, `<id>.png`, `apply_extra.sh`, `<app>-wrapper`, `resolve-update.sh`.
- **Permissions:** tightest `finish-args` that work. Don't pre-grant broad host access;
  document optional caps (`~/.ssh`, `--device=all`, `--filesystem=home`) as opt-in
  `flatpak override` in the **metainfo**, not in `finish-args`.
- **metainfo:** mark it a **community package** ("repackages the official upstream build
  unmodified"), honest `project_license`, screenshot `<image>` URLs pointing **at upstream**
  (never upload to R2). The site's `enrich` step downloads those and serves recompressed webp
  from Pages — a CDN win, and it drops the upstream fetch from page load — falling back to the
  upstream hotlink only if the fetch fails.

## 4. Test / verify — every run, no exceptions

1. `node scripts/read-descriptor.mjs registry/<id>/flatpark.yml` and
   `node scripts/audit-descriptor.mjs registry/<id>/flatpark.yml` (exit 0).
2. Build: `scripts/build-app.sh <id>` (or `flatpak-builder --install` for a quick loop).
   **`appstreamcli compose` must print `Success`.**
3. Install from the signed local repo into an **isolated** `--installation=test` so it never
   pollutes your everyday Flatpak state (recipe in the contributing guide). Installing
   exercises `apply_extra` (the extra-data download + unpack).
4. **Smoke-test the actual launch:** the app must start, and its data must land inside the
   sandbox (`~/.var/app/<id>/…`). Confirm no missing libs (`LD_TRACE_LOADED_OBJECTS=1` → 0
   "not found"). Note in the PR anything you *couldn't* verify (GUI render on a real session,
   login flows, hardware paths) — coverage is always partial and honesty about that matters.

## 5. Branch & commit format

- **Never commit to `main`.** Branch first.
  - New app: **`add/<app-id>`** (e.g. `add/com.triliumnext.notes`).
  - Fix/change: **`fix/<slug>`** or **`docs/<slug>`** (e.g. `fix/trilium-sandbox-note`).
- **Conventional Commits.** Subject: `<type>(<short-name>): <summary> (<app-id>)`.
  - New app → **`feat(<short>): add <App> <one-liner> (<app-id>)`**
    (e.g. `feat(trilium): add Trilium Notes knowledge base (com.triliumnext.notes)`).
  - Fix → **`fix(<short>): <what> `** (e.g. `fix(trilium): correct the zypak/sandbox comments`).
  - Body: *why*, not a file list. If you're correcting an earlier claim, say what was wrong.
- **Trailer** on every commit:
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`
- **Rebase onto `origin/main`** before pushing.

## 6. PR format

- **Title** = the commit subject.
- **Body** — the house "packaging notes" shape:
  - **What** — one line: the app + app-id.
  - **Why this fills a gap** — not-on-Flathub / abandoned Flathub entry / rejected Flathub PR;
    the demand you found in §1.
  - **Packaging** — runtime, extra-data source, recipe (Electron/zypak/etc.), app-id choice.
  - **Sandbox** — the `finish-args` and what's deliberately withheld. Justify anything
    broad you kept; for what you withheld, point at the `flatpak override` lines in the
    metainfo that let a user opt in.
  - **Verification** — the §4 checklist as ticked items (the local `flatpak install` +
    launch is mandatory before the PR), plus what's still unverified.
  - If you walk back a claim later, add a short **Correction** footer pointing at the fix PR.
- **Footer:** `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- **Review gate:** draft the PR body, **present it, open (`gh pr create`) only on approval.**
  **Never self-merge** — the maintainer merges.

## 7. Engage upstream

Only after the package is **live + smoke-tested** (Golden rule 5). Reuse what §1 found
(demand + the maintainer's stated concerns).

### 7.1 The hard rule: no inaccurate or disparaging claims

Describe **only what our package does**. Before writing any comparison to upstream's own
build, **verify it against current upstream**: is the issue still open? Is a fix already
merged, and by whom? (We once told a maintainer our zypak setup "sidesteps their `--no-sandbox`
launch bug" — the bug had been fixed months earlier *by that same maintainer*. It didn't change
the outcome but it read as ignorant/disparaging and had to be corrected publicly.) When in
doubt, **drop the comparison.** A "packaging note" should *offer help* (a reusable env var,
an override tip), never grade their work.

### 7.2 Where to post

- **Prefer an existing Flatpak/Flathub-request issue** on the app's own tracker (that's where
  the demand already is). Else the context of the closed Flathub PR, or a new issue.
- Issues disabled / no tracker → a low-key DM or public reply on the maintainer's channel,
  explaining *why* you're reaching out there (see the Yaak DM precedent).

### 7.3 Voice & template

Warm, professional, first-person; no slang, no emoji. The proven shape (HiresTI, Tabularis,
DiscordChatExporter, Yaak):

```
Hi @<maintainer> — thanks for <App>, it's great. I maintain **[FlatPark](https://github.com/flatpark/flatpark)**,
a small hub that offers Flatpak installs for apps that aren't on Flathub, and I've packaged <App> there.

It uses Flatpak **extra-data**, so it downloads your **official <artifact> release** unmodified at
install time and tracks new releases automatically from your GitHub releases — I don't rehost or patch
anything. <one line on what it is, e.g. "local-first desktop app, no server needed">.

<Optional: one honest line on why it helps — e.g. the Flathub PR was closed / official Flathub isn't
planned — framed as a stopgap, never as a knock on Flathub or on you.>

Install:
```
flatpak remote-add --if-not-exists flatpark https://dl.flatpark.org/flatpark.flatpakrepo
flatpak install flatpark <app-id>
```
App page: https://flatpark.org/apps/<app-id>

<Optional packaging note that *helps* them — a reusable override/env tip — never a critique.>

I've only smoke-tested it myself, so my coverage is certainly incomplete — if you have time to put it
through real use and see what breaks, I'd genuinely appreciate it, and any issue or PR on the packaging
is very welcome. And if you'd rather I **not** list it, just say so and I'll remove it right away. If
you're happy for it to stay, I'll add a blue "developer-approved" shield to its FlatPark page and
feature it on the homepage. Hope this helps your users in the meantime!
```

The ask, every time, has three parts: **(1) invite testing** and welcome issues/PRs (be upfront that
your own verification is partial); **(2) request developer authorization** → on a yes, add the blue
**"developer-approved" shield** to the app page + a **homepage feature**; **(3) offer the exit** →
de-list on request. `@`-mention the maintainer at the ask.

**Review gate:** draft the comment, **present it, post only on approval.** Don't re-post if they've
said no.

## 8. On the maintainer's response

- **Yes / approves** → add the blue "developer-approved" shield to the app page + feature on the
  homepage.
- **No** → de-list immediately; don't argue, don't re-pitch.
- **Correction / criticism** (e.g. an inaccurate claim) → acknowledge it plainly, **fix the repo**
  (manifest comments, wrapper, PR body — via a `fix/…` branch + PR) **and the offending message**,
  then reply linking the fix. Graciousness > defensiveness; the person correcting you is often the
  one who did the underlying work.

## 9. Cadence & automation

- **Re-crawl (§1) periodically** to catch new releases and freshly-rejected Flathub PRs.
- Each app's `resolve-update.sh` already lets FlatPark re-pin & rebuild on new upstream releases —
  no manual version bumps.
- **Runtime majors are NOT bumped by CI.** `update-check` only re-pins extra-data and the metainfo
  release; `runtime-version` / `base-version` are hand-pinned per manifest. When a new major lands,
  the maintainer kicks off an **AI-led batch update** that bumps and re-tests the whole catalog at
  once — so the catalog never splits across two majors (see §3, "Pick the runtime").
- The §1–§2 crawl + §2 gates are scriptable into a shortlist; §3 packaging is templated per recipe.
  Keep the **review gate** on the two outward-facing actions (§0.4) even as the rest automates.
