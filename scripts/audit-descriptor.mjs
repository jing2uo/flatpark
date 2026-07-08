#!/usr/bin/env node
// Audit a FlatPark registry descriptor + its manifest against the review-bar
// guardrails (see docs/pr-review.md). Dependency-free: the PR gate runs `node`
// before any `npm ci`, so this uses the same manual line-scan style as
// read-descriptor.mjs rather than a YAML library.
//
//   node scripts/audit-descriptor.mjs <flatpark.yml>
//
// Exit 0 = no hard failures (warnings allowed); exit 1 = hard failure(s).
// Hard failures print `FAIL: ...`; advisory findings print `WARN: ...`.
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';

const file = process.argv[2];
if (!file) {
  process.stderr.write('usage: audit-descriptor.mjs <flatpark.yml>\n');
  process.exit(2);
}

const fails = [];
const warns = [];
const fail = (m) => fails.push(m);
const warn = (m) => warns.push(m);

const readText = (p) => readFileSync(p, 'utf8').replace(/\r/g, '');
const indentOf = (l) => l.length - l.replace(/^\s+/, '').length;
function unquote(v) {
  v = v.trim();
  if (v === '' || v === '~' || v === 'null') return '';
  const c = v[0];
  if ((c === '"' || c === "'") && v[v.length - 1] === c) return v.slice(1, -1);
  return v;
}

// --- descriptor: build.manifest, update.command, policy.{proprietary,dangerous_permissions}
let descText;
try {
  descText = readText(file);
} catch (e) {
  process.stderr.write(`FAIL: cannot read ${file}: ${e.message || e}\n`);
  process.exit(1);
}

let manifestName = '';
let updateCommand = '';
let proprietary = null;
const dangerousPerms = [];
{
  let section = null;
  let inDanger = false;
  for (const raw of descText.split('\n')) {
    if (!raw.trim() || /^\s*#/.test(raw)) continue;
    const ind = indentOf(raw);
    const s = raw.trim();
    if (ind === 0) {
      inDanger = false;
      const m = s.match(/^([A-Za-z0-9_]+):\s*(.*)$/);
      section = m && m[2] === '' ? m[1] : null;
      continue;
    }
    if (s.startsWith('- ')) {
      if (section === 'policy' && inDanger) dangerousPerms.push(unquote(s.slice(2)));
      continue;
    }
    const m = s.match(/^([A-Za-z0-9_]+):\s*(.*)$/);
    if (!m) continue;
    const [, k, v] = m;
    if (section === 'build' && k === 'manifest') manifestName = unquote(v);
    else if (section === 'update' && k === 'command') updateCommand = unquote(v);
    else if (section === 'policy') {
      if (k === 'proprietary') proprietary = unquote(v) === 'true';
      else if (k === 'dangerous_permissions') {
        const t = v.trim();
        if (t === '') inDanger = true;
        else if (t !== '[]') t.replace(/^\[|\]$/g, '').split(',').map(unquote).filter(Boolean).forEach((x) => dangerousPerms.push(x));
      }
    }
  }
}

if (!manifestName) fail('descriptor missing build.manifest');

// update.command must be a simple relative script path (it runs in CI).
if (updateCommand && !/^\.\/[A-Za-z0-9._-]+$/.test(updateCommand)) {
  fail(`update.command must be a simple relative script path (e.g. ./resolve-update.sh), got: ${updateCommand}`);
}

// --- manifest: finish-args, sources, build-commands
const dir = dirname(file);
const finishArgs = [];
const sources = []; // [{ type, keys }]
const buildCommands = [];
if (manifestName) {
  let manifestText = '';
  try {
    manifestText = readText(join(dir, manifestName));
  } catch {
    fail(`cannot read manifest ${manifestName}`);
  }
  if (manifestText) {
    let block = null; // 'finish' | 'build' | 'sources'
    let blockIndent = -1;
    let cur = null; // current source
    let curIndent = -1;
    let srcItemIndent = -1; // indent of a `- ` source item within the current sources block
    for (const raw of manifestText.split('\n')) {
      if (!raw.trim() || /^\s*#/.test(raw)) continue;
      const ind = indentOf(raw);
      const s = raw.trim();

      if (block !== null && ind <= blockIndent) { block = null; cur = null; srcItemIndent = -1; }

      const hdr = s.match(/^(finish-args|build-commands|sources):\s*(.*)$/);
      if (hdr && (hdr[2].trim() === '' || hdr[2].trim() === '[]')) {
        block = hdr[1] === 'finish-args' ? 'finish' : hdr[1] === 'build-commands' ? 'build' : 'sources';
        blockIndent = ind;
        cur = null;
        srcItemIndent = -1;
        continue;
      }

      if (block === 'finish' && s.startsWith('- ')) { finishArgs.push(unquote(s.slice(2))); continue; }
      if (block === 'build' && s.startsWith('- ')) { buildCommands.push(unquote(s.slice(2))); continue; }
      if (block === 'sources') {
        if (s.startsWith('- ')) {
          if (srcItemIndent === -1) srcItemIndent = ind;
          // Only a `- ` at the source-item indent starts a new source; a deeper
          // `- ` is a nested list value (e.g. a mirror-urls entry).
          if (ind === srcItemIndent) {
            cur = { type: '', keys: {} };
            curIndent = ind;
            sources.push(cur);
            const li = s.slice(2).match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
            if (li) {
              cur.keys[li[1]] = unquote(li[2]);
              if (li[1] === 'type') cur.type = unquote(li[2]);
            }
          }
          continue;
        }
        if (cur && ind > curIndent) {
          const kv = s.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
          if (kv) {
            cur.keys[kv[1]] = unquote(kv[2]);
            if (kv[1] === 'type') cur.type = unquote(kv[2]);
          }
          continue;
        }
      }
    }
  }
}

// G1 — source pinning, per type.
const LOCAL = new Set(['file', 'script', 'patch', 'dir', 'shell']);
for (const src of sources) {
  const t = src.type;
  if (t === 'git') {
    if (!src.keys.commit) fail(`git source missing immutable commit (${src.keys.url || ''})`);
  } else if (t === 'archive') {
    if (!src.keys.sha256) fail(`archive source missing sha256 (${src.keys.url || ''})`);
  } else if (t === 'extra-data') {
    if (!src.keys.sha256) fail(`extra-data source missing sha256 (${src.keys.url || src.keys.filename || ''})`);
    if (!src.keys.size || src.keys.size === '0') fail(`extra-data source missing/zero size (${src.keys.url || src.keys.filename || ''})`);
  } else if (t === '' || !LOCAL.has(t)) {
    warn(`source type '${t || '?'}' not auto-verified — needs human review`);
  }
}

// G2(a) — sandbox-escape permissions are a hard fail.
const ESCAPE = ['--talk-name=org.freedesktop.Flatpak', '--filesystem=host', '--filesystem=/'];
// G2(b) — broad perms must be declared in policy.dangerous_permissions (warn until schema lands).
const WATCH = ['--device=all', '--filesystem=home'];
for (const fa of finishArgs) {
  if (ESCAPE.includes(fa)) {
    // A declared escape permission is an explicit, reviewed exemption: downgrade
    // the hard fail to a warning so it stays visible without blocking the gate.
    if (dangerousPerms.includes(fa)) warn(`sandbox-escape permission ${fa} (declared in policy.dangerous_permissions)`);
    else fail(`sandbox-escape permission: ${fa}`);
  }
  if (WATCH.includes(fa) && !dangerousPerms.includes(fa)) {
    warn(`dangerous permission ${fa} not declared in policy.dangerous_permissions`);
  }
}

// G3 — runtime fetch-and-exec (warn only; vendor self-updaters surface here too).
const FETCH = [/\bnpm install\b/, /\bpip install\b/, /\bpip3 install\b/, /curl[^\n]*\|\s*sh\b/, /wget[^\n]*\|\s*sh\b/];
const scan = [...buildCommands];
try {
  for (const f of readdirSync(dir)) {
    if (/\.sh$/.test(f) || /wrapper$/.test(f)) {
      try { scan.push(readText(join(dir, f))); } catch { /* ignore */ }
    }
  }
} catch { /* ignore */ }
for (const text of scan) {
  for (const re of FETCH) {
    if (re.test(text)) { warn(`possible runtime fetch-and-exec: ${text.trim().split('\n')[0].slice(0, 80)}`); break; }
  }
}

for (const w of warns) process.stderr.write(`WARN: ${w}\n`);
for (const f of fails) process.stderr.write(`FAIL: ${f}\n`);
process.exit(fails.length ? 1 : 0);
