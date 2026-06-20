// Build-time data access. The data dir holds catalog.json (light, for the
// index + search) and apps/<id>.json (rich, for detail pages). It is
// env-overridable so the publish pipeline and tests can target any location.
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

export const dataDir = process.env.FLATPARK_DATA_DIR || 'public';

export function loadCatalog() {
  return JSON.parse(readFileSync(join(dataDir, 'catalog.json'), 'utf8'));
}

export function loadApps() {
  const dir = join(dataDir, 'apps');
  return readdirSync(dir)
    .filter((f) => f.endsWith('.json'))
    .map((f) => JSON.parse(readFileSync(join(dir, f), 'utf8')))
    .sort((a, b) => a.name.localeCompare(b.name));
}
