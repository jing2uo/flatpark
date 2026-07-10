#!/usr/bin/env node
// Read a flatpak manifest and print the runtime plus the extra-data sources
// that apply to one arch, as tab-separated lines a shell can read:
//
//   runtime<TAB><id><TAB><version>
//   extra<TAB><filename><TAB><url><TAB><sha256>
//
// Like read-descriptor.mjs this is NOT a general YAML parser. Manifests here
// are generated and reviewed against a fixed shape, so we extract the few keys
// check-apply-extra.sh needs and stay dependency-free.
//
// Usage: read-extra-data.mjs <manifest.yml> <arch>
import { readFileSync } from 'node:fs';

const [file, arch] = process.argv.slice(2);
if (!file || !arch) {
  process.stderr.write('usage: read-extra-data.mjs <manifest.yml> <arch>\n');
  process.exit(2);
}

let lines;
try {
  lines = readFileSync(file, 'utf8').split('\n');
} catch (e) {
  process.stderr.write(`cannot read ${file}: ${e.message || e}\n`);
  process.exit(1);
}

const strip = (v) => v.trim().replace(/^["'](.*)["']$/, '$1');

let runtime = '';
let runtimeVersion = '';
const sources = [];
let cur = null;
let inArches = false;

for (const raw of lines) {
  const t = raw.trim();
  if (!t || t.startsWith('#')) continue;

  let m;
  // Top-level keys only: a nested `runtime:` under build-options must not win.
  if (!/^\s/.test(raw)) {
    if ((m = raw.match(/^runtime:\s*(.+)$/))) runtime = strip(m[1]);
    else if ((m = raw.match(/^runtime-version:\s*(.+)$/))) runtimeVersion = strip(m[1]);
  }

  if (t === '- type: extra-data') {
    cur = { arches: [] };
    sources.push(cur);
    inArches = false;
    continue;
  }
  // Any other list entry ends the record we were filling.
  if (t.startsWith('- type:')) {
    cur = null;
    inArches = false;
    continue;
  }
  if (!cur) continue;

  if (t === 'only-arches:') { inArches = true; continue; }
  if (inArches && (m = t.match(/^-\s*(\S+)$/))) { cur.arches.push(strip(m[1])); continue; }
  inArches = false;

  if ((m = t.match(/^filename:\s*(.+)$/))) cur.filename = strip(m[1]);
  else if ((m = t.match(/^url:\s*(.+)$/))) cur.url = strip(m[1]);
  else if ((m = t.match(/^sha256:\s*(.+)$/))) cur.sha256 = strip(m[1]);
}

if (!runtime || !runtimeVersion) {
  process.stderr.write(`${file}: no top-level runtime / runtime-version\n`);
  process.exit(1);
}

const out = [`runtime\t${runtime}\t${runtimeVersion}`];
for (const s of sources) {
  if (s.arches.length && !s.arches.includes(arch)) continue;
  if (!s.filename || !s.url || !s.sha256) {
    process.stderr.write(`${file}: extra-data source missing filename/url/sha256\n`);
    process.exit(1);
  }
  out.push(`extra\t${s.filename}\t${s.url}\t${s.sha256}`);
}
process.stdout.write(out.join('\n') + '\n');
