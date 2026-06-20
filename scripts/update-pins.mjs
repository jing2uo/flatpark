#!/usr/bin/env node
// Apply an update resolver's output to an app: refresh the manifest's
// "MANAGED EXTRA-DATA" pins and the metainfo <releases>.
//
//   <resolver JSON on stdin> | update-pins.mjs <manifest> [metainfo]
//
// Resolver JSON: { version, releaseDate, sources: [ { filename, url } ] }
//
// The comparison anchor is the VERSION: the latest <release version="..."> in
// the metainfo is "what we have". If the resolver's version equals it, nothing
// changed (exit 10, no download). On a new version we download every source,
// recompute the extra-data sha256/size FlatPark-side, rewrite the MANAGED block,
// and prepend a <release> to the metainfo. With no version anchor (resolver
// emits no version), we fall back to per-source URL comparison.
//
// Exit 0  = changed (manifest and/or metainfo rewritten); prints the version.
// Exit 10 = nothing changed.
// Exit 1  = error.
import { readFileSync, writeFileSync, existsSync, createReadStream } from 'node:fs';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';

const BEGIN = '# BEGIN MANAGED EXTRA-DATA';
const END = '# END MANAGED EXTRA-DATA';
const die = (m) => { process.stderr.write(`update-pins: ${m}\n`); process.exit(1); };

const manifestPath = process.argv[2];
const metainfoPath = process.argv[3];
if (!manifestPath) die('usage: update-pins.mjs <manifest> [metainfo]');

let resolver;
try { resolver = JSON.parse(readFileSync(0, 'utf8')); }
catch (e) { die(`bad resolver JSON: ${e.message}`); }
if (!resolver || !Array.isArray(resolver.sources)) die('resolver JSON missing sources[]');

const text = readFileSync(manifestPath, 'utf8');
const lines = text.split('\n');
const bi = lines.findIndex((l) => l.includes(BEGIN));
const ei = lines.findIndex((l) => l.includes(END));
if (bi < 0 || ei < 0 || ei < bi) die('manifest has no MANAGED EXTRA-DATA block');
const baseIndent = (lines[bi].match(/^(\s*)/)[1]) || '      ';
const oldBlock = lines.slice(bi + 1, ei);

// Parse the current block: filename -> { url, sha256, size, arches }.
const current = {};
let cur = null;
for (const l of oldBlock) {
  const t = l.trim();
  if (t === '- type: extra-data') { cur = { arches: [] }; continue; }
  if (!cur) continue;
  let m;
  if ((m = t.match(/^filename:\s*(.+)$/))) { cur.filename = m[1].trim(); current[cur.filename] = cur; }
  else if ((m = t.match(/^url:\s*(.+)$/))) cur.url = m[1].trim();
  else if ((m = t.match(/^sha256:\s*(.+)$/))) cur.sha256 = m[1].trim();
  else if ((m = t.match(/^size:\s*(.+)$/))) cur.size = m[1].trim();
  else if ((m = t.match(/^-\s*(\S+)$/)) && !/:/.test(t)) cur.arches.push(m[1].trim());
}

const metainfo = metainfoPath && existsSync(metainfoPath) ? readFileSync(metainfoPath, 'utf8') : null;
const firstReleaseVersion = (xml) => {
  const m = xml && xml.match(/<release\b[^>]*\bversion="([^"]*)"/);
  return m ? m[1] : '';
};
const knownVersion = firstReleaseVersion(metainfo);

// Version gate: cheap short-circuit when upstream hasn't moved (no downloads).
if (resolver.version && knownVersion && resolver.version === knownVersion) process.exit(10);

// A version present here means a real bump (or no anchor yet) -> re-pin fresh.
// Without a version we fall back to URL comparison and only fetch moved sources.
const versionBump = !!resolver.version;

async function pin(url) {
  const hash = createHash('sha256');
  let size = 0;
  if (url.startsWith('file://')) {
    await new Promise((res, rej) => {
      const s = createReadStream(fileURLToPath(url));
      s.on('data', (c) => { hash.update(c); size += c.length; });
      s.on('end', res); s.on('error', rej);
    });
  } else {
    const r = await fetch(url, { redirect: 'follow' });
    if (!r.ok) throw new Error(`HTTP ${r.status} for ${url}`);
    for await (const chunk of r.body) { hash.update(chunk); size += chunk.length; }
  }
  return { sha256: hash.digest('hex'), size: String(size) };
}

const fields = `${baseIndent}  `;
const archItem = `${baseIndent}    `;
const out = [];
for (const src of resolver.sources) {
  if (!src.filename || !src.url) die('each source needs filename + url');
  const prev = current[src.filename];
  const arches = prev && prev.arches.length ? prev.arches : ['x86_64'];
  let sha256, size;
  if (!versionBump && prev && prev.url === src.url && prev.sha256 && prev.size) {
    ({ sha256, size } = prev); // URL unchanged and no version bump -> keep the pin
  } else {
    try { ({ sha256, size } = await pin(src.url)); }
    catch (e) { die(e.message); }
  }
  out.push(`${baseIndent}- type: extra-data`);
  out.push(`${fields}filename: ${src.filename}`);
  out.push(`${fields}only-arches:`);
  for (const a of arches) out.push(`${archItem}- ${a}`);
  out.push(`${fields}url: ${src.url}`);
  out.push(`${fields}sha256: ${sha256}`);
  out.push(`${fields}size: ${size}`);
}

const manifestChanged = out.join('\n') !== oldBlock.join('\n');

// Prepend a <release> to the metainfo when the version moved.
let metainfoChanged = false;
let newMetainfo = metainfo;
if (metainfo && resolver.version && resolver.version !== knownVersion) {
  const date = resolver.releaseDate ? ` date="${resolver.releaseDate}"` : '';
  const rel = `<release version="${resolver.version}"${date} />`;
  if (/<releases\b[^>]*>/.test(metainfo)) {
    newMetainfo = metainfo.replace(/(<releases\b[^>]*>)/, `$1\n    ${rel}`);
  } else if (metainfo.includes('</component>')) {
    newMetainfo = metainfo.replace('</component>', `  <releases>\n    ${rel}\n  </releases>\n</component>`);
  }
  metainfoChanged = newMetainfo !== metainfo;
}

if (!manifestChanged && !metainfoChanged) process.exit(10);
if (manifestChanged) {
  writeFileSync(manifestPath, [...lines.slice(0, bi + 1), ...out, ...lines.slice(ei)].join('\n'));
}
if (metainfoChanged) writeFileSync(metainfoPath, newMetainfo);
process.stdout.write(`${resolver.version || ''}\n`);
