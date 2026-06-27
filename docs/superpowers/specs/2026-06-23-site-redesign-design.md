# FlatPark site redesign — design

Date: 2026-06-23
Goal: make the site prettier, better-structured, and SEO-friendly. Visual base = **Direction C (Adwaita+)**, hero = **Variant 2** (copy left, screenshot-led "Editor's pick" card right).

## Scope

**Phase 1 (this spec — ships now, uses only data we already have):**
visual redesign, page split, curated category taxonomy, `/apps` browse page with sidebar, Featured carousel, sort by Featured/Name/Recently-updated, SEO + the font/caching fixes.

**Later (noted, not built now):** Phase 2 = ★ GitHub stars (build-time fetch, GitHub apps only). Phase 3 = download counts (Cloudflare). Future = Flathub federation. No "Sources" toggle yet.

## Visual direction

- Adwaita-native: GNOME blue `#3584e4`, soft cards, pill controls, light canvas `#f6f5f4`. Keep existing theme tokens; refine spacing/hierarchy.
- **Fix the Inter font** — it's declared in `--font-sans` but never loaded, so the site currently renders in system fonts. Self-host Inter (woff2) + `font-display:swap` + preload the main weight. (No Google Fonts runtime dep.)

## Information architecture (pages)

- **`/` homepage** — Topbar + hero (Variant 2) + Featured carousel (screenshot-led, rotating, developer-approved apps only) + "All apps" grid with a **Sort** dropdown + "Browse by category →" link. No filter rail here.
- **`/apps` browse** — left **sidebar** of curated sections (with counts) + Sort + full grid + search. This is the heavy/scalable page (Pattern A).
- **`/apps/[id]` detail** — keep current structure, restyle to C (InfoPanel, screenshots carousel, permissions).
- **`/setup` + content pages** — restyle to C.

Existing components (`Base`, `Topbar`, `Hero`, `AppCard`, `InfoPanel`, `Screenshots`, `Footer`) are reused/restyled, not rewritten. New: `/apps` page + its sidebar, a `Featured` carousel component.

## Category taxonomy

Build-time mapping from raw AppStream categories → a fixed curated set:
`Development, Finance, Utilities, Communication, Science, Office, Graphics & Design, Audio & Video, Games, System`.
Unmapped → `Utilities`. Mapping is one small table in the build (e.g. in `gen-apps-json` / `enrich`). Each app gets one `section` in `catalog.json`. Sidebar counts derive from it.

## Sorting (Phase 1)

Client-side over `catalog.json` (fits the static model). Modes:
- **Featured** (default) — featured first, then by updated.
- **Name** (A–Z).
- **Recently updated** — `updated` timestamp baked into `catalog.json` at build = git commit time of `registry/<id>/` (`git log -1 --format=%cI -- registry/<id>`), with metainfo `<release>` date as override when present.

Star/install sorts are deferred; don't show controls for them in Phase 1.

## Featured carousel

- Opt-in per app via `catalog.featured: true` in `registry/<id>/flatpark.yml` (only developer-approved apps, e.g. GeoLibre).
- `gen-apps-json` surfaces `featured` into `catalog.json`.
- Carousel shows screenshot + icon + name + one-line + install command, rotating; respects `prefers-reduced-motion`. Empty featured list → hide the carousel.

## SEO + head (Phase 1)

- Per-page `<head>`: canonical, Open Graph + Twitter card (title/description/image), `theme-color`. App detail OG image = app icon (or first screenshot).
- Per-app **JSON-LD** `SoftwareApplication` (name, description, category, operatingSystem: Linux, downloadUrl/installUrl).
- Keep existing sitemap + robots.
- `public/_headers` for Cloudflare Pages: long cache for hashed assets + `/icons/*`, short/revalidate for HTML + `catalog.json`.

## Data / build changes

`catalog.json` per-app gains: `section` (curated), `featured` (bool), `updated` (ISO). Produced in the existing `gen-apps-json` + `enrich` step — no new pipeline. Sorting/filtering is JS in the page over that JSON.

## Out of scope (now)

GitHub stars, download counts, Flathub federation + Sources toggle, dark mode (can add later; not requested).

## Open items

- Final curated section list — confirm the 10 buckets above (add/merge?).
- `/apps` route name (`/apps` vs `/browse`) — default `/apps`.
