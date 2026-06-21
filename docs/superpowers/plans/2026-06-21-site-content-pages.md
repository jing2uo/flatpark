# FlatPark site content pages — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a flat set of footer-linked content pages (about, policies, trust, publishing guide, user guide, conduct, legal) to the FlatPark site, rendered from an Astro Content Layer markdown collection.

**Architecture:** One Astro content collection (`pages`) holds markdown files; a single catch-all route `[...slug].astro` renders each page in a shared prose layout; a `Footer.astro` component builds grouped footer links from the collection at build time and is mounted globally in `Base.astro`. Filling in each page after the system exists is just adding one markdown file.

**Tech Stack:** Astro 5.7 (Content Layer / `glob` loader), Tailwind CSS 4 (hand-rolled `.prose` via `@apply`, no typography plugin), static output. Tests are shell scripts that build the site and `grep` the HTML (existing `tests/test_gen_site.sh` pattern + `tests/lib/assert.sh`).

## Global Constraints

- **Language:** all page content in English (matches existing site/README/CONTRIBUTING).
- **No new runtime dependencies** — prose styling is hand-rolled CSS, not `@tailwindcss/typography`.
- **No new client-side JavaScript** — pages are static prose.
- **Markdown bodies start at `##`** — the page `<h1>` is rendered by the layout from frontmatter `title`, so bodies must not include their own `#` h1.
- **Footer groups enum:** exactly `Project`, `Docs`, `Community`, `Legal` (frontmatter `group`).
- **Static output unchanged in shape** — `output: 'static'`, build still goes to `SITE_OUT_DIR`.
- **CONTRIBUTING.md** becomes a short pointer; the canonical publishing guide is the site page.
- **Legal is a single `/legal` page** (privacy + terms together).
- **Maintainer GitHub:** `https://github.com/jing2uo/flatpark` (existing Topbar link).

---

### Task 1: Content system + global footer + /about

Builds the whole content pipeline and ships one real page (`/about`) through it end to end. This is the indivisible enabler; every later task only adds a markdown file.

**Files:**
- Create: `site/src/content.config.ts`
- Create: `site/src/content/pages/about.md`
- Create: `site/src/pages/[...slug].astro`
- Create: `site/src/components/Footer.astro`
- Modify: `site/src/layouts/Base.astro` (mount global `<Footer />`)
- Modify: `site/src/pages/apps/[id].astro` (remove inline `<footer>` to avoid a duplicate)
- Modify: `site/src/styles/global.css` (add `.prose` block)
- Test: `tests/test_gen_site.sh` (add content-page + footer assertions)

**Interfaces:**
- Produces — content collection `pages` with frontmatter `{ title: string, description: string, group: 'Project'|'Docs'|'Community'|'Legal', order: number, hideFromFooter: boolean }`. Each entry's `id` is its filename slug (`about.md` → `about` → route `/about/`).
- Produces — `Footer.astro` (no props; reads the `pages` collection itself).
- Consumes — `loadCatalog()` from `site/src/lib/data.mjs` (existing) for `repo` (Topbar needs it).

- [ ] **Step 1: Add the failing assertions to the site test**

In `tests/test_gen_site.sh`, immediately before the final `echo "test_gen_site: PASS"` line, insert:

```bash
# Content pages (Astro content collection) + global footer.
about="$tmp/site/about/index.html"
assert_file "$about"
assert_contains "$about" "About FlatPark"
# The global footer renders on every page — check it on the catalog index.
assert_contains "$index" "/about/"
assert_contains "$index" "community Flatpak hub"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/test_gen_site.sh`
Expected: FAIL with `assert_file: missing .../about/index.html` (or SKIP if offline/no npm — if it SKIPs, you cannot TDD here; ensure `site/node_modules` is installed first with `cd site && npm install`, then re-run).

- [ ] **Step 3: Create the content collection config**

Create `site/src/content.config.ts`:

```ts
import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

// Flat content pages (about, policies, trust, guides, conduct, legal).
// Each markdown file's name is its route slug; the Footer is built from this
// collection, so `group` + `order` are what place a page in the footer.
const pages = defineCollection({
  loader: glob({ pattern: '*.md', base: './src/content/pages' }),
  schema: z.object({
    title: z.string(),
    description: z.string(),
    group: z.enum(['Project', 'Docs', 'Community', 'Legal']),
    order: z.number().default(0),
    hideFromFooter: z.boolean().default(false),
  }),
});

export const collections = { pages };
```

- [ ] **Step 4: Create the page renderer route**

Create `site/src/pages/[...slug].astro`:

```astro
---
import { getCollection, render } from 'astro:content';
import Base from '../layouts/Base.astro';
import Topbar from '../components/Topbar.astro';
import { loadCatalog } from '../lib/data.mjs';

export async function getStaticPaths() {
  const pages = await getCollection('pages');
  return pages.map((page) => ({ params: { slug: page.id }, props: { page } }));
}

const { page } = Astro.props;
const { repo } = loadCatalog();
const { Content } = await render(page);
---

<Base title={`${page.data.title} — ${repo.title}`}>
  <Topbar repo={repo} />
  <main class="mx-auto max-w-3xl px-5 py-12">
    <article class="prose">
      <h1>{page.data.title}</h1>
      <Content />
    </article>
  </main>
</Base>
```

- [ ] **Step 5: Create the Footer component**

Create `site/src/components/Footer.astro`:

```astro
---
import { getCollection } from 'astro:content';

const order = ['Project', 'Docs', 'Community', 'Legal'];
const pages = (await getCollection('pages')).filter((p) => !p.data.hideFromFooter);

const groups = order
  .map((name) => ({
    name,
    items: pages
      .filter((p) => p.data.group === name)
      .sort((a, b) => a.data.order - b.data.order)
      .map((p) => ({ href: `/${p.id}/`, label: p.data.title })),
  }))
  .filter((g) => g.items.length);

// External links appended to a group (GitHub lives under Community).
const externals = { Community: [{ href: 'https://github.com/jing2uo/flatpark', label: 'GitHub' }] };
for (const g of groups) if (externals[g.name]) g.items.push(...externals[g.name]);
---

<footer class="border-t border-line">
  <div class="mx-auto max-w-6xl px-5 py-10">
    <div class="grid grid-cols-2 gap-8 sm:grid-cols-4">
      {groups.map((g) => (
        <div>
          <h3 class="text-xs font-bold uppercase tracking-wide text-muted">{g.name}</h3>
          <ul class="mt-3 flex flex-col gap-2 text-sm">
            {g.items.map((it) => (
              <li><a class="text-ink/80 hover:text-brand" href={it.href}>{it.label}</a></li>
            ))}
          </ul>
        </div>
      ))}
    </div>
    <p class="mt-8 text-xs text-muted">
      FlatPark · community Flatpak hub · packaged apps remain their vendors' property
    </p>
  </div>
</footer>
```

- [ ] **Step 6: Mount the footer globally in Base.astro**

In `site/src/layouts/Base.astro`, add the import to the frontmatter (after the `import '../styles/global.css';` line):

```astro
import Footer from '../components/Footer.astro';
```

Then in the `<body>`, change:

```astro
  <body class="min-h-screen">
    <slot />

    <script>
```

to:

```astro
  <body class="min-h-screen">
    <slot />
    <Footer />

    <script>
```

- [ ] **Step 7: Remove the duplicate inline footer from the per-app page**

In `site/src/pages/apps/[id].astro`, delete the entire inline footer block (the global Footer now covers it):

```astro
  <footer class="border-t border-line">
    <div class="mx-auto max-w-5xl px-5 py-7 text-sm text-muted">
      <a class="text-brand" href="/">&larr; Back to {repo.title}</a>
    </div>
  </footer>
```

- [ ] **Step 8: Add prose styles**

Append to `site/src/styles/global.css`:

```css
/* Rendered markdown for content pages. Hand-rolled (no typography plugin). */
.prose { @apply max-w-none text-[15px] leading-relaxed text-ink/90; }
.prose h1 { @apply text-3xl font-extrabold tracking-tight text-ink; }
.prose h2 { @apply mt-8 text-xl font-bold text-ink; }
.prose h3 { @apply mt-6 text-lg font-bold text-ink; }
.prose p { @apply mt-4; }
.prose ul { @apply mt-4 list-disc pl-6; }
.prose ol { @apply mt-4 list-decimal pl-6; }
.prose li { @apply mt-1; }
.prose a { @apply text-brand hover:underline; }
.prose strong { @apply font-semibold text-ink; }
.prose code { @apply rounded bg-canvas px-1.5 py-0.5 font-mono text-sm; }
.prose pre { @apply mt-4 overflow-x-auto rounded-lg border border-line bg-[#1d1f24] p-4 text-sm text-[#e9eaed]; }
.prose pre code { @apply bg-transparent p-0; }
```

- [ ] **Step 9: Create the /about page**

Create `site/src/content/pages/about.md`:

```markdown
---
title: About FlatPark
description: What FlatPark is, why it exists, and how it relates to Flatpak and Flathub.
group: Project
order: 1
---

FlatPark is a community Flatpak hub for apps that ship as a definitive download —
an official installer or prebuilt archive at a stable, public release URL.
FlatPark fetches that release at build time, repackages it as a Flatpak
([extra-data](/trust/)), pins it, and signs the result. It never builds apps from
source.

## Why it exists

- **One runtime, always latest.** Every hosted app is continuously upgraded and
  tested against the newest runtime, so you only need a single, latest copy of
  the runtime installed.
- **Sandboxed and out of your home directory.** Flatpak keeps each app
  sandboxed; FlatPark keeps the permissions tight and surfaces them on every
  app page.
- **One place to install and update.** Apps that otherwise ship only a raw
  `.deb`, AppImage, or tarball become installable and auto-updating through one
  remote.

## How it relates to Flatpak and Flathub

FlatPark is built on [Flatpak](https://flatpak.org/) and is **not affiliated
with [Flathub](https://flathub.org/)**. Flathub builds most apps from source;
FlatPark deliberately only repackages official downloads (extra-data). The two
are complementary — if an app is on Flathub, install it there.

## Who runs it

FlatPark is an independent, community-run project. Its own code is MIT-licensed;
the packaged applications remain their vendors' property and are fetched from
official sources at install time.
```

- [ ] **Step 10: Run the test to verify it passes**

Run: `bash tests/test_gen_site.sh`
Expected: `test_gen_site: PASS` (the `/about/` page builds, footer renders on the index).

- [ ] **Step 11: Run the full suite + link check**

Run: `bash tests/run-tests.sh`
Expected: every test prints `ok ...` (or SKIP); no `FAIL`.

- [ ] **Step 12: Commit**

```bash
git add site/src/content.config.ts site/src/content/pages/about.md \
  "site/src/pages/[...slug].astro" site/src/components/Footer.astro \
  site/src/layouts/Base.astro "site/src/pages/apps/[id].astro" \
  site/src/styles/global.css tests/test_gen_site.sh
git commit -m "feat(site): content-page system + global footer + about page"
```

---

### Task 2: /policies + /trust

The two README-promised differentiators. Pure content — the system from Task 1 carries them.

**Files:**
- Create: `site/src/content/pages/policies.md`
- Create: `site/src/content/pages/trust.md`
- Test: `tests/test_gen_site.sh` (add assertions)

**Interfaces:**
- Consumes — the `pages` collection schema and `[...slug].astro` route from Task 1.

- [ ] **Step 1: Add failing assertions**

In `tests/test_gen_site.sh`, before `echo "test_gen_site: PASS"`, add:

```bash
assert_file "$tmp/site/policies/index.html"
assert_contains "$tmp/site/policies/index.html" "De-listing"
assert_file "$tmp/site/trust/index.html"
assert_contains "$tmp/site/trust/index.html" "extra-data"
assert_contains "$index" "/policies/"
assert_contains "$index" "/trust/"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/test_gen_site.sh`
Expected: FAIL with `assert_file: missing .../policies/index.html`.

- [ ] **Step 3: Create /policies**

Create `site/src/content/pages/policies.md`:

```markdown
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
installer, AppImage, `.deb`, `.rpm`, or tarball. FlatPark fetches it at build,
pins it by checksum, and signs the result. It never builds from source and never
re-hosts the binary.

## Requirements

- A **stable, public release URL** for the official build (not behind a login).
- An **AppStream metainfo** file (`<id>.metainfo.xml`) with id, name, summary,
  license, and at least one description paragraph.
- The **id matches reverse-DNS** and the registry directory name.
- The **tightest `finish-args`** that still work — broad grants such as
  `--filesystem=home` are questioned in review.
- A stated **license** for the app.

## Vibe-coded apps

Apps built with AI assistance ("vibe coding") are welcome. They are judged on the
same bar as any other app: development history, upstream activity, and observed
quality — not on how they were written.

## Review

Every submission is reviewed (AI-assisted) weighing provenance, the requested
permissions, and overall quality. The packaging is a small, auditable set of
files per app, which keeps review tractable.

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
```

- [ ] **Step 4: Create /trust**

Create `site/src/content/pages/trust.md`:

```markdown
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
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash tests/test_gen_site.sh`
Expected: `test_gen_site: PASS`.

- [ ] **Step 6: Commit**

```bash
git add site/src/content/pages/policies.md site/src/content/pages/trust.md tests/test_gen_site.sh
git commit -m "feat(site): listing policies + trust & safety pages"
```

---

### Task 3: /contributing (migrate) + slim CONTRIBUTING.md + /guide

Move the publishing guide onto the site and slim the repo file to a pointer; add the user guide.

**Files:**
- Create: `site/src/content/pages/contributing.md`
- Create: `site/src/content/pages/guide.md`
- Modify: `CONTRIBUTING.md` (replace with a short pointer)
- Test: `tests/test_gen_site.sh` (add assertions)

**Interfaces:**
- Consumes — the `pages` collection + route from Task 1.

- [ ] **Step 1: Add failing assertions**

In `tests/test_gen_site.sh`, before `echo "test_gen_site: PASS"`, add:

```bash
assert_file "$tmp/site/contributing/index.html"
assert_contains "$tmp/site/contributing/index.html" "flatpark.yml"
assert_file "$tmp/site/guide/index.html"
assert_contains "$tmp/site/guide/index.html" "remote-add"
assert_contains "$index" "/contributing/"
assert_contains "$index" "/guide/"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/test_gen_site.sh`
Expected: FAIL with `assert_file: missing .../contributing/index.html`.

- [ ] **Step 3: Create /contributing**

Create `site/src/content/pages/contributing.md` with frontmatter, then the body migrated from the current `CONTRIBUTING.md`. The body is the existing CONTRIBUTING.md content **with its top `# Contributing an app to FlatPark` heading removed** (the layout supplies the h1) and the first heading demoted so the body starts at `##`:

```markdown
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

## Add an app

Create one directory under `registry/` named exactly for the app id:

(... migrate the remaining sections of CONTRIBUTING.md verbatim: the directory
layout, validate/build commands, the `flatpark.yml` schema block, the
auto-updating section with the resolver JSON and the three resolver templates,
and the Sandbox & permissions section. Demote nothing else — they are already
`##`/`###` and stay as-is.)
```

Copy the rest of `CONTRIBUTING.md` (everything after its first `# ...` line) unchanged into the body. Do not paraphrase — it is reference material.

- [ ] **Step 4: Slim CONTRIBUTING.md to a pointer**

Replace the entire contents of `CONTRIBUTING.md` with:

```markdown
# Contributing an app to FlatPark

The publishing guide now lives on the site:
**<https://flatpark.org/contributing/>**

Its source is [`site/src/content/pages/contributing.md`](site/src/content/pages/contributing.md).
Edit that file to change the guide.

Onboarding is meant to run through an AI agent — open this repo in your agent
(e.g. Claude Code) and ask it to publish an app, reading the guide above.
```

- [ ] **Step 5: Create /guide**

Create `site/src/content/pages/guide.md`:

```markdown
---
title: User guide
description: Installing, updating, uninstalling, and understanding FlatPark apps.
group: Docs
order: 2
---

## Installing an app

First add the FlatPark remote (once), then install any app:

```sh
flatpak --user remote-add --if-not-exists flatpark https://dl.flatpark.org/flatpark.flatpakrepo
flatpak --user install flatpark <app-id>
```

The [setup page](/setup/) has the full first-time walkthrough, including the
runtime remote.

## User vs system install

`--user` installs into your home directory and needs no admin rights. Drop
`--user` from both commands for a system-wide install (requires root). You can
use either; `--user` is the simplest if you are not sure.

## Updates and the single runtime

FlatPark continuously rebuilds each app against the newest runtime, so a normal
`flatpak update` keeps every app current and you only ever need one, latest copy
of the runtime installed:

```sh
flatpak --user update
```

## Reading an app's permissions

Every app page lists the exact sandbox permissions it requests, with a
plain-language risk label. Check these before installing — see
[Trust & safety](/trust/) for what the model guarantees.

## Uninstalling

```sh
flatpak --user uninstall <app-id>
```

To also remove unused runtimes afterwards:

```sh
flatpak --user uninstall --unused
```

## Troubleshooting

- **App not found:** make sure the remote was added (`flatpak remotes`) and the
  app id is spelled exactly as shown on its page.
- **Signature/GPG errors:** re-add the remote with the command above; it pins the
  signing key.
- **Won't launch:** run it from a terminal (`flatpak run <app-id>`) to see the
  error output.
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `bash tests/test_gen_site.sh`
Expected: `test_gen_site: PASS`.

- [ ] **Step 7: Verify CONTRIBUTING.md no longer duplicates the guide**

Run: `grep -c 'flatpark.yml schema\|resolve-update.sh' CONTRIBUTING.md`
Expected: `0` (the schema/resolver detail now lives only on the site page).

- [ ] **Step 8: Commit**

```bash
git add site/src/content/pages/contributing.md site/src/content/pages/guide.md CONTRIBUTING.md tests/test_gen_site.sh
git commit -m "feat(site): publishing guide + user guide; slim CONTRIBUTING to pointer"
```

---

### Task 4: /conduct

**Files:**
- Create: `site/src/content/pages/conduct.md`
- Test: `tests/test_gen_site.sh` (add assertions)

**Interfaces:**
- Consumes — the `pages` collection + route from Task 1.

- [ ] **Step 1: Add failing assertions**

In `tests/test_gen_site.sh`, before `echo "test_gen_site: PASS"`, add:

```bash
assert_file "$tmp/site/conduct/index.html"
assert_contains "$tmp/site/conduct/index.html" "Code of conduct"
assert_contains "$index" "/conduct/"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/test_gen_site.sh`
Expected: FAIL with `assert_file: missing .../conduct/index.html`.

- [ ] **Step 3: Create /conduct**

Create `site/src/content/pages/conduct.md`:

```markdown
---
title: Code of conduct
description: How we expect people to behave in FlatPark's issues and pull requests, and how to report problems.
group: Community
order: 1
---

FlatPark is a small community project. The rules are short.

## Be respectful

Treat everyone with respect. Harassment, personal attacks, discrimination, and
deliberately disruptive behaviour are not welcome — in issues, pull requests,
commit messages, or any other project space.

## Scope

This applies to all participation in the FlatPark repository: issues, pull
requests, reviews, and discussions.

## Reporting

If you experience or witness unacceptable behaviour, open an issue (mark it
clearly) or contact the maintainer privately via the email on their GitHub
profile. Reports are handled confidentially.

## Enforcement

Maintainers may edit, hide, or remove contributions that violate this code, and
may block repeat or serious offenders from the project.
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/test_gen_site.sh`
Expected: `test_gen_site: PASS`.

- [ ] **Step 5: Commit**

```bash
git add site/src/content/pages/conduct.md tests/test_gen_site.sh
git commit -m "feat(site): code of conduct page"
```

---

### Task 5: /legal (privacy + terms)

**Files:**
- Create: `site/src/content/pages/legal.md`
- Test: `tests/test_gen_site.sh` (add assertions)

**Interfaces:**
- Consumes — the `pages` collection + route from Task 1.

- [ ] **Step 1: Add failing assertions**

In `tests/test_gen_site.sh`, before `echo "test_gen_site: PASS"`, add:

```bash
assert_file "$tmp/site/legal/index.html"
assert_contains "$tmp/site/legal/index.html" "no accounts"
assert_contains "$index" "/legal/"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/test_gen_site.sh`
Expected: FAIL with `assert_file: missing .../legal/index.html`.

- [ ] **Step 3: Create /legal**

Create `site/src/content/pages/legal.md`:

```markdown
---
title: Privacy & terms
description: What FlatPark collects (almost nothing) and the terms for the packaged apps.
group: Legal
order: 1
---

## Privacy

FlatPark's website is a static site. It sets **no cookies**, runs **no
analytics**, and has **no accounts** — there is nothing to sign in to and nothing
we track about you.

App downloads are served from a content delivery network (Cloudflare
Pages / R2). Like any web server, the CDN may keep standard, short-lived access
logs (IP address, timestamp, requested file) for abuse prevention; FlatPark does
not use them to profile users.

## Terms

FlatPark's own code is provided **as is, without warranty of any kind**. FlatPark
only repackages official downloads — it does **not** license the packaged
applications. Each application remains the property of its vendor, is governed by
that vendor's own license, and is fetched from the vendor's official source at
install time.

Trademarks and brand names belong to their respective owners; their use here is
for identification only and does not imply endorsement. If you believe an app is
listed in error, see the [de-listing process](/policies/) or open an issue.
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/test_gen_site.sh`
Expected: `test_gen_site: PASS`.

- [ ] **Step 5: Final full suite**

Run: `bash tests/run-tests.sh`
Expected: every test `ok` (or SKIP); no `FAIL`.

- [ ] **Step 6: Commit**

```bash
git add site/src/content/pages/legal.md tests/test_gen_site.sh
git commit -m "feat(site): privacy & terms page"
```

---

## Self-Review

**Spec coverage:**
- Content system (collection + route + footer + prose) → Task 1. ✓
- Footer groups Project/Docs/Community/Legal → Footer.astro + per-page `group`. ✓
- Page set (policies, trust, contributing, guide, about, conduct, legal) → Tasks 1–5. ✓
- CONTRIBUTING.md slimmed to pointer → Task 3 Step 4. ✓
- `/setup` linked, not duplicated → guide.md links `/setup/`. ✓
- Single `/legal` → Task 5. ✓
- Per-app inline footer replaced by shared footer → Task 1 Step 7. ✓
- Rollout order Step 0→4 → Task order 1→5. ✓
- Out-of-scope items (stats/badges/etc.) → not present in any task. ✓

**Placeholder scan:** the only deferred-content marker is Task 3 Step 3's
instruction to copy the remaining `CONTRIBUTING.md` sections verbatim — this is a
deliberate "migrate existing reference text unchanged" instruction, not an
invented placeholder, and the source text already exists in the repo. All other
page bodies are complete.

**Type consistency:** frontmatter keys (`title`, `description`, `group`, `order`,
`hideFromFooter`) are identical across the schema (Task 1) and every page.
Footer group strings match the `z.enum` exactly. Route slug = filename (about,
policies, trust, contributing, guide, conduct, legal) matches every footer href
and test assertion.
```
