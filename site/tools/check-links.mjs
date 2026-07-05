// Batch-check the external URLs the site hotlinks (screenshots, homepage,
// help, license, source). Reads enriched apps/<id>.json from the data dir.
// Human summary by default, --json for machine output. Exits 1 if any link
// is broken so CI / a remediation job can act on it.
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const dataDir = process.env.FLATPARK_DATA_DIR || 'public';
const appsDir = join(dataDir, 'apps');
const asJson = process.argv.includes('--json');
const CONCURRENCY = Number(process.env.LINK_CHECK_CONCURRENCY || 8);
const TIMEOUT = Number(process.env.LINK_CHECK_TIMEOUT_MS || 10000);

// Errors that prove the host is live and reachable in a real browser, but that
// Node's stricter fetch/OpenSSL policy refuses. These reach TLS handshake with a
// running server (a down host fails earlier with ENOTFOUND/ECONNREFUSED/timeout),
// so they are warnings, not broken links. Legacy renegotiation is the known case
// (some vendor sites, e.g. gtht.com, still require it; browsers allow it).
const SOFT_OK_CODES = new Set(['ERR_SSL_UNSAFE_LEGACY_RENEGOTIATION_DISABLED']);

function collect() {
  const urls = [];
  if (!existsSync(appsDir)) return urls;
  for (const f of readdirSync(appsDir).filter((n) => n.endsWith('.json'))) {
    const app = JSON.parse(readFileSync(join(appsDir, f), 'utf8'));
    const add = (type, url) => {
      if (typeof url === 'string' && /^https?:\/\//.test(url)) urls.push({ app: app.id, type, url });
    };
    for (const s of app.screenshots || []) add('screenshot', s.remoteUrl || s.url);
    add('website', app.website);
    for (const [k, v] of Object.entries(app.urls || {})) add(`url:${k}`, v);
    if (app.license?.url) add('license', app.license.url);
    add('source', app.sourceUrl);
  }
  const seen = new Set();
  return urls.filter((u) => {
    const k = `${u.app}|${u.type}|${u.url}`;
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  });
}

async function request(method, url) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), TIMEOUT);
  try {
    return await fetch(url, { method, redirect: 'follow', signal: ctrl.signal });
  } finally {
    clearTimeout(timer);
  }
}

async function check(entry) {
  try {
    // Prefer HEAD; many servers reject/ignore it (or block hotlinking), so on
    // any HEAD failure or 403/405/501 fall back to GET before declaring it dead.
    let res = await request('HEAD', entry.url).catch(() => null);
    if (!res || [403, 405, 501].includes(res.status)) {
      res = await request('GET', entry.url);
    }
    const out = { ...entry, status: res.status, ok: res.ok };
    try { await res.body?.cancel(); } catch {}
    return out;
  } catch (e) {
    const error = e.name === 'AbortError' ? 'timeout' : (e.cause?.code || e.message);
    if (SOFT_OK_CODES.has(error)) return { ...entry, status: error, ok: true, warn: true };
    return { ...entry, status: 0, ok: false, error };
  }
}

async function pool(items, n, fn) {
  const out = [];
  let i = 0;
  await Promise.all(
    Array.from({ length: Math.min(n, items.length) || 1 }, async () => {
      while (i < items.length) {
        const idx = i++;
        out[idx] = await fn(items[idx]);
      }
    }),
  );
  return out;
}

const entries = collect();
const results = await pool(entries, CONCURRENCY, check);
const broken = results.filter((r) => !r.ok);
const warned = results.filter((r) => r.warn);

if (asJson) {
  console.log(JSON.stringify({ checked: results.length, broken: broken.length, warned: warned.length, results }, null, 2));
} else {
  console.log(`[check-links] checked ${results.length} link(s)`);
  if (warned.length > 0) {
    console.log(`[check-links] ${warned.length} reachable but skipped (client TLS policy, OK in browsers):`);
    for (const w of warned) console.log(`  ~ ${w.app}  [${w.type}]  ${w.status}  ${w.url}`);
  }
  if (broken.length === 0) {
    console.log('[check-links] all links OK');
  } else {
    console.log(`[check-links] ${broken.length} broken:`);
    for (const b of broken) {
      console.log(`  x ${b.app}  [${b.type}]  ${b.status || b.error}  ${b.url}`);
    }
  }
}

process.exit(broken.length > 0 ? 1 : 0);
