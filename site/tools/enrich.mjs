// Enrich each base apps/<id>.json (from gen-apps-json.sh) with rich metadata
// parsed from the developer repo's Flatpak manifest, AppStream metainfo, and
// flatpark.yml. Best-effort: a missing or malformed source is skipped, never
// fatal, so the build always proceeds.
import { readFileSync, writeFileSync, readdirSync, existsSync, mkdirSync } from 'node:fs';
import { execSync } from 'node:child_process';
import { join } from 'node:path';
import YAML from 'yaml';
import { XMLParser } from 'fast-xml-parser';
import sharp from 'sharp';

// Curated top-level sections. Raw AppStream/descriptor categories map into this
// fixed set so the catalog filter stays small no matter how many raw categories
// appear; anything unmapped falls back to Utilities.
const SECTION_MAP = {
  Development: 'Development', IDE: 'Development', Building: 'Development',
  Finance: 'Finance',
  Network: 'Communication', Communication: 'Communication', Chat: 'Communication',
  InstantMessaging: 'Communication', Email: 'Communication',
  Science: 'Science', Education: 'Science', Geoscience: 'Science',
  Office: 'Office', Spreadsheet: 'Office',
  Graphics: 'Graphics & Design', Photography: 'Graphics & Design',
  AudioVideo: 'Audio & Video', Audio: 'Audio & Video', Video: 'Audio & Video', Player: 'Audio & Video',
  Game: 'Games',
  System: 'System', Settings: 'System', Security: 'System',
  Utility: 'Utilities', Utilities: 'Utilities',
};
const sectionFor = (cat) => SECTION_MAP[cat] || 'Utilities';

// Last time we touched this app's package, for the "Recently updated" sort.
// Git commit time of the registry dir is universal (no upstream fetch); fall
// back to the latest release date, then empty. Best-effort like everything here.
function gitUpdated(srcDir) {
  if (!srcDir || !existsSync(srcDir)) return '';
  try {
    return execSync('git log -1 --format=%cI -- .', { cwd: srcDir, stdio: ['ignore', 'pipe', 'ignore'] })
      .toString().trim();
  } catch {
    return '';
  }
}

const dataDir = process.env.FLATPARK_DATA_DIR || 'public';
const appsDir = join(dataDir, 'apps');
const shotsDir = join(dataDir, 'screenshots');

// Hotlinked upstream screenshots are slow and frequently time out. Download
// each once, downscale + recompress to webp, and serve locally. Cached by
// filename so reruns are cheap; on any fetch/decode failure we keep the
// original remote URL (best-effort, never fatal).
// ponytail: existsSync cache never refreshes a changed upstream shot — `rm -rf
// public/screenshots` to force a re-pull; add a hash check only if churn bites.
async function cacheScreenshots(id, shots) {
  if (!shots.length) return shots;
  mkdirSync(shotsDir, { recursive: true });
  const out = [];
  for (let i = 0; i < shots.length; i += 1) {
    const s = shots[i];
    const name = `${id}-${i}.webp`;
    const dest = join(shotsDir, name);
    const localUrl = `/screenshots/${name}`;
    if (existsSync(dest)) { out.push({ ...s, url: localUrl }); continue; }
    try {
      const res = await fetch(s.url, { signal: AbortSignal.timeout(20000) });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      await sharp(Buffer.from(await res.arrayBuffer()))
        .resize({ width: 1280, withoutEnlargement: true })
        .webp({ quality: 78 })
        .toFile(dest);
      out.push({ ...s, url: localUrl });
    } catch (e) {
      console.warn(`[enrich] ${id}: screenshot ${i} cache failed (${e.message}); hotlinking`);
      out.push(s);
    }
  }
  return out;
}

const toArray = (x) => (x == null ? [] : Array.isArray(x) ? x : [x]);
const textOf = (x) => (x == null ? '' : typeof x === 'object' ? String(x['#text'] ?? '') : String(x)).trim();

const xml = new XMLParser({ ignoreAttributes: false, attributeNamePrefix: '@_', trimValues: true });
// A second parser that preserves child order, so an AppStream <description>'s
// <p> and <ul>/<ol> blocks keep the order they appear in the document.
// trimValues stays off so the spaces around inline children (e.g. the text
// before a <code>) survive; orderedText collapses whitespace runs at the end.
const xmlOrdered = new XMLParser({ ignoreAttributes: true, preserveOrder: true, trimValues: false });

// Flatten preserveOrder nodes into a string, recursing into inline children so
// the text inside <code>/<em>/... is kept (e.g. a <li>'s flatpak-override
// command). Collapse whitespace runs introduced by source indentation.
const orderedText = (nodes) =>
  toArray(nodes)
    .map((n) => {
      if (n == null) return '';
      if (typeof n !== 'object') return String(n);
      if ('#text' in n) return String(n['#text'] ?? '');
      // preserveOrder element wrapper, e.g. { code: [ ...children ] } — recurse.
      return Object.keys(n)
        .filter((k) => k !== ':@')
        .map((k) => orderedText(n[k]))
        .join('');
    })
    .join('')
    .replace(/\s+/g, ' ')
    .trim();

// Parse an AppStream <description> into ordered blocks the detail page renders:
// { type: 'p', text } for paragraphs and { type: 'list', items } for <ul>/<ol>.
function descriptionBlocks(rawXml) {
  let tree;
  try {
    tree = xmlOrdered.parse(rawXml);
  } catch {
    return [];
  }
  const comp = toArray(tree).find((n) => n && 'component' in n);
  const descNode = comp && toArray(comp.component).find((n) => n && 'description' in n);
  if (!descNode) return [];
  const blocks = [];
  for (const node of toArray(descNode.description)) {
    if (!node || typeof node !== 'object') continue;
    if ('p' in node) {
      const text = orderedText(node.p);
      if (text) blocks.push({ type: 'p', text });
    } else if ('ul' in node || 'ol' in node) {
      const items = toArray(node.ul || node.ol)
        .filter((c) => c && 'li' in c)
        .map((c) => orderedText(c.li))
        .filter(Boolean);
      if (items.length) blocks.push({ type: 'list', items });
    }
  }
  return blocks;
}

function parseManifest(path) {
  const raw = readFileSync(path, 'utf8');
  try {
    return JSON.parse(raw);
  } catch {
    return YAML.parse(raw);
  }
}

function parseLicense(raw) {
  if (!raw) return null;
  // Pull the optional document URL out of a `LicenseRef-<id>=<url>` token. It
  // can stand alone or sit inside a compound SPDX expression (e.g.
  // "MIT AND LicenseRef-proprietary=https://.../LICENSE"); left in the label it
  // is unbreakably long and stretches the app-page layout.
  let url = null;
  const cleaned = raw.replace(/LicenseRef-([^=\s]+)=(\S+)/g, (_, id, u) => {
    url = u;
    return `LicenseRef-${id}`;
  });
  // A bare LicenseRef on its own -> friendly label (drives the Proprietary flag).
  const bare = /^LicenseRef-([^=\s]+)$/.exec(cleaned);
  if (bare) return { label: bare[1] === 'proprietary' ? 'Proprietary' : bare[1], url };
  // Plain or compound SPDX expression: prettify the proprietary ref inline.
  return { label: cleaned.replace(/LicenseRef-proprietary\b/g, 'Proprietary'), url };
}

// Map a single Flatpak finish-arg to a human label + risk level + group.
const NON_PERMISSION_FLAGS = new Set([
  'require-version', 'env', 'extra-languages', 'cwd', 'metadata', 'sdk', 'command', 'runtime', 'version',
]);

function describePermission(arg) {
  const eq = arg.indexOf('=');
  const flag = (eq === -1 ? arg : arg.slice(0, eq)).replace(/^--/, '');
  const value = eq === -1 ? '' : arg.slice(eq + 1);
  // These are build/metadata directives, not sandbox holes — don't list them.
  if (NON_PERMISSION_FLAGS.has(flag)) return null;
  const base = (label, level, group, detail) => ({ flag, value, label, level, group, detail: detail || '' });

  switch (flag) {
    case 'share':
      if (value === 'network') return base('Network access', 'caution', 'Network', 'Can reach the internet and local network');
      if (value === 'ipc') return base('Inter-process communication', 'info', 'System', 'Shares the IPC namespace with the host');
      return base(`Share: ${value}`, 'info', 'System');
    case 'socket': {
      const map = {
        x11: ['X11 windowing system', 'caution', 'Display', 'Legacy display protocol; can observe input to other X11 windows'],
        'fallback-x11': ['X11 (fallback)', 'info', 'Display'],
        wayland: ['Wayland display', 'safe', 'Display'],
        pulseaudio: ['Audio (PulseAudio)', 'info', 'Devices'],
        pipewire: ['Audio/video (PipeWire)', 'info', 'Devices'],
        'session-bus': ['Full session bus access', 'warning', 'Services'],
        'system-bus': ['Full system bus access', 'warning', 'Services'],
        'ssh-auth': ['SSH agent', 'info', 'System'],
        cups: ['Printing (CUPS)', 'info', 'System'],
        'gpg-agent': ['GPG agent', 'info', 'System'],
      };
      const m = map[value];
      return m ? base(m[0], m[1], m[2], m[3]) : base(`Socket: ${value}`, 'info', 'System');
    }
    case 'device': {
      const map = {
        dri: ['GPU acceleration', 'safe', 'Devices'],
        all: ['All devices (incl. cameras, USB)', 'warning', 'Devices'],
        kvm: ['Virtualization (KVM)', 'caution', 'Devices'],
        shm: ['Shared memory', 'info', 'Devices'],
        input: ['Input devices', 'caution', 'Devices'],
        usb: ['USB devices', 'caution', 'Devices'],
      };
      const m = map[value];
      return m ? base(m[0], m[1], m[2]) : base(`Device: ${value}`, 'info', 'Devices');
    }
    case 'filesystem': {
      const v = value.replace(/:(ro|rw|create)$/, '');
      const mode = value.endsWith(':ro') ? ' (read-only)' : '';
      const map = {
        host: ['All system files', 'warning', 'Filesystem'],
        'host-os': ['Host OS files', 'warning', 'Filesystem'],
        'host-etc': ['Host /etc', 'warning', 'Filesystem'],
        home: ['Home folder', 'caution', 'Filesystem'],
      };
      const m = map[v];
      if (m) return base(m[0] + mode, m[1], m[2]);
      return base(`Files: ${value}`, 'caution', 'Filesystem');
    }
    case 'talk-name':
      return base(`Talk to ${value}`, 'info', 'Services');
    case 'system-talk-name':
      return base(`System service: ${value}`, 'caution', 'Services');
    case 'own-name':
      return base(`Owns service ${value}`, 'info', 'Services');
    case 'persist':
      return base(`Persistent storage: ${value}`, 'info', 'Filesystem');
    default:
      return base(value ? `${flag}: ${value}` : flag, 'info', 'System');
  }
}

async function enrichOne(file) {
  const path = join(appsDir, file);
  const base = JSON.parse(readFileSync(path, 'utf8'));
  const srcDir = base._srcDir;
  const out = { ...base };
  delete out._srcDir;
  delete out._manifest;

  // defaults so the page can render unconditionally
  out.developer = '';
  out.license = null;
  out.description = [];
  out.screenshots = [];
  out.releases = [];
  out.urls = {};
  out.categories = out.category ? [out.category] : [];
  out.contentRating = [];
  out.runtime = '';
  out.runtimeVersion = '';
  out.command = '';
  out.proprietary = false;
  out.maintainer = null;
  out.permissions = [];

  // 1. Flatpak manifest -> permissions, runtime, proprietary tag
  try {
    if (base._manifest && existsSync(base._manifest)) {
      const m = parseManifest(base._manifest);
      out.runtime = m.runtime || '';
      out.runtimeVersion = m['runtime-version'] ? String(m['runtime-version']) : '';
      out.command = m.command || '';
      out.permissions = toArray(m['finish-args']).map(describePermission).filter(Boolean);
      if (toArray(m.tags).includes('proprietary')) out.proprietary = true;
    }
  } catch (e) {
    console.warn(`[enrich] ${base.id}: manifest parse failed: ${e.message}`);
  }

  // 2. AppStream metainfo -> description, screenshots, releases, developer, license, urls
  try {
    const candidates = [
      join(srcDir || '', `${base.id}.metainfo.xml`),
      join(srcDir || '', `${base.id}.appdata.xml`),
    ];
    const metainfoPath = candidates.find((p) => p && existsSync(p));
    if (metainfoPath) {
      const rawXml = readFileSync(metainfoPath, 'utf8');
      const comp = xml.parse(rawXml).component || {};
      out.description = descriptionBlocks(rawXml);
      out.screenshots = toArray(comp.screenshots?.screenshot).map((s) => {
        const imgs = toArray(s.image);
        const img = imgs.find((i) => (typeof i === 'object' ? i['@_type'] : 'source') === 'source') || imgs[0];
        return { url: textOf(img), caption: textOf(s.caption) };
      }).filter((s) => s.url);
      out.releases = toArray(comp.releases?.release).map((r) => ({
        version: String(r['@_version'] ?? ''),
        date: String(r['@_date'] ?? ''),
      })).filter((r) => r.version);
      out.developer = textOf(comp.developer?.name) || textOf(comp.developer_name) || '';
      const lic = parseLicense(textOf(comp.project_license));
      if (lic) out.license = lic;
      for (const u of toArray(comp.url)) {
        const type = typeof u === 'object' ? u['@_type'] : 'homepage';
        if (type) out.urls[type] = textOf(u);
      }
      const cats = toArray(comp.categories?.category).map(textOf).filter(Boolean);
      if (cats.length) out.categories = cats;
      out.contentRating = toArray(comp.content_rating?.content_attribute).map((a) => ({
        id: typeof a === 'object' ? a['@_id'] : '',
        value: textOf(a),
      })).filter((a) => a.id);
    }
  } catch (e) {
    console.warn(`[enrich] ${base.id}: metainfo parse failed: ${e.message}`);
  }

  // 3. flatpark.yml -> maintainer, website, policy
  try {
    const fyPath = join(srcDir || '', 'flatpark.yml');
    if (existsSync(fyPath)) {
      const fy = YAML.parse(readFileSync(fyPath, 'utf8')) || {};
      if (fy.maintainer) out.maintainer = fy.maintainer;
      if (fy.website) out.website = fy.website;
      if (fy.policy?.proprietary) out.proprietary = true;
      if (fy.build?.mode) out.buildMode = fy.build.mode;
      out.featured = !!fy.catalog?.featured; // opt-in, developer-approved only
    }
  } catch (e) {
    console.warn(`[enrich] ${base.id}: flatpark.yml parse failed: ${e.message}`);
  }

  out.screenshots = await cacheScreenshots(out.id, out.screenshots);

  if (!out.website) out.website = out.urls.homepage || '';
  if (out.license?.label === 'Proprietary') out.proprietary = true;

  // Catalog facets for sort + filter (homepage / browse page).
  out.section = sectionFor(out.category);
  out.featured = out.featured || false;
  // Prefer upstream release date; fall back to registry commit time.
  out.updated = out.releases?.[0]?.date || gitUpdated(srcDir) || '';

  writeFileSync(path, JSON.stringify(out, null, 2) + '\n');
  return out.id;
}

if (!existsSync(appsDir)) {
  console.warn(`[enrich] no apps dir at ${appsDir}; nothing to enrich`);
  process.exit(0);
}
const files = readdirSync(appsDir).filter((f) => f.endsWith('.json'));
let n = 0;
for (const f of files) {
  try {
    await enrichOne(f);
    n += 1;
  } catch (e) {
    console.warn(`[enrich] ${f}: ${e.message}`);
  }
}
console.log(`[enrich] enriched ${n}/${files.length} app file(s) in ${appsDir}`);
