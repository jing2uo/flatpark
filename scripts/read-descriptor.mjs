#!/usr/bin/env node
// Read a FlatPark registry descriptor (flatpark.yml) and print shell
// assignments for the fields the publish pipeline needs. Output is single-quoted
// and safe to `eval` in bash.
//
// This is NOT a general YAML parser: the descriptor schema is small and
// controlled, so we extract exactly the known paths (id, name, summary,
// website, source_url, build.{manifest,branch,mode}, catalog.{category,tags},
// update.command). Keeping it dependency-free means the core bash pipeline only
// needs `node`, not an npm install.
import { readFileSync } from 'node:fs';

const file = process.argv[2];
if (!file) {
  process.stderr.write('usage: read-descriptor.mjs <flatpark.yml>\n');
  process.exit(2);
}

let text;
try {
  text = readFileSync(file, 'utf8');
} catch (e) {
  process.stderr.write(`cannot read ${file}: ${e.message || e}\n`);
  process.exit(1);
}

function unquote(v) {
  v = v.trim();
  if (v === '' || v === '~' || v === 'null') return '';
  const c = v[0];
  if ((c === '"' || c === "'") && v[v.length - 1] === c) return v.slice(1, -1);
  return v;
}

const d = { tags: [] };
let section = null; // current top-level block key (build / catalog / ...)
let inTags = false; // collecting catalog.tags block-list items

function topScalar(key, val) {
  if (key === 'id') d.id = val;
  else if (key === 'name') d.name = val;
  else if (key === 'summary') d.summary = val;
  else if (key === 'website') d.website = val;
  else if (key === 'source_url') d.source_url = val;
}

for (const raw of text.split('\n')) {
  const line = raw.replace(/\r$/, '');
  if (!line.trim() || /^\s*#/.test(line)) continue;
  const indent = line.length - line.replace(/^\s+/, '').length;
  const s = line.trim();

  if (indent === 0) {
    inTags = false;
    const m = s.match(/^([A-Za-z0-9_]+):\s*(.*)$/);
    if (!m) { section = null; continue; }
    const [, key, val] = m;
    if (val === '') section = key; // a nested block follows
    else { section = null; topScalar(key, unquote(val)); }
    continue;
  }

  if (s.startsWith('- ')) {
    if (section === 'catalog' && inTags) d.tags.push(unquote(s.slice(2)));
    continue;
  }

  const m = s.match(/^([A-Za-z0-9_]+):\s*(.*)$/);
  if (!m) continue;
  const [, key, val] = m;
  if (section === 'build') {
    if (key === 'manifest') d.manifest = unquote(val);
    else if (key === 'branch') d.branch = unquote(val);
    else if (key === 'mode') d.mode = unquote(val);
  } else if (section === 'catalog') {
    if (key === 'category') d.category = unquote(val);
    else if (key === 'tags') {
      const t = val.trim();
      if (t === '[]') { d.tags = []; inTags = false; }
      else if (t === '') { inTags = true; } // block list items follow
      else { // inline flow list: [a, b, c]
        d.tags = t.replace(/^\[|\]$/g, '').split(',').map(unquote).filter(Boolean);
        inTags = false;
      }
    }
  } else if (section === 'update') {
    if (key === 'command') d.update_command = unquote(val);
  }
  // maintainer / policy blocks are not needed by the build pipeline.
}

function required(v, name) {
  if (!v) {
    process.stderr.write(`descriptor ${file} missing required field: ${name}\n`);
    process.exit(1);
  }
  return v;
}
required(d.id, 'id');
required(d.name, 'name');
required(d.summary, 'summary');
required(d.manifest, 'build.manifest');

function sq(v) {
  return "'" + String(v == null ? '' : v).replace(/'/g, "'\\''") + "'";
}

const out = [
  `_FP_ID=${sq(d.id)}`,
  `_FP_NAME=${sq(d.name)}`,
  `_FP_SUMMARY=${sq(d.summary)}`,
  `_FP_BRANCH=${sq(d.branch || '')}`,
  `_FP_MANIFEST=${sq(d.manifest)}`,
  `_FP_MODE=${sq(d.mode || '')}`,
  `_FP_CATEGORY=${sq(d.category || '')}`,
  `_FP_TAGS=${sq((d.tags || []).join(', '))}`,
  `_FP_WEBSITE=${sq(d.website || '')}`,
  `_FP_SOURCE_URL=${sq(d.source_url || '')}`,
  `_FP_UPDATE_COMMAND=${sq(d.update_command || '')}`,
].join('\n');
process.stdout.write(out + '\n');
