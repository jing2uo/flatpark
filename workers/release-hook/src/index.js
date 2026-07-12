// hooks.flatpark.org — turns an unauthenticated "app X released tag Y" ping
// from upstream CI (flatpark/publish-action) into an authenticated
// repository_dispatch on flatpark/flatpark, which runs update-check.yml.
//
// Upstream CI holds no FlatPark secrets, so the request itself proves nothing.
// Trust comes from cross-checking public state instead:
//   1. app_id must exist in our published catalog (apps/<id>.json),
//   2. the upstream repo is taken from OUR catalog's sourceUrl — never from
//      the request — so a caller can't point us at an arbitrary repo,
//   3. the tag must actually exist as a release on that repo.
// Worst case for an abusive caller: they re-trigger the same update check the
// daily cron runs anyway, whose only output is a PR a human merges.

const APP_ID_RE = /^[A-Za-z][A-Za-z0-9_-]*(\.[A-Za-z0-9_-]+){2,}$/; // reverse-DNS flatpak id
const TAG_RE = /^[A-Za-z0-9][A-Za-z0-9._+-]{0,99}$/;
const GH_SOURCE_RE = /^https:\/\/github\.com\/([^/\s]+)\/([^/\s]+?)(?:\.git)?\/?$/;

const json = (status, body) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

const ghHeaders = (token) => ({
  accept: "application/vnd.github+json",
  "user-agent": "flatpark-release-hook",
  ...(token ? { authorization: `Bearer ${token}` } : {}),
});

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    try {
      if (url.pathname !== "/release") {
        return json(404, { error: "not found; POST /release" });
      }
      if (request.method !== "POST") {
        return json(405, { error: "method not allowed" });
      }

      // Rate limit before any parsing or GitHub calls. IP check first so a
      // single noisy source is cut off without draining the shared bucket.
      const ip = request.headers.get("cf-connecting-ip") || "unknown";
      if (!(await env.IP_LIMITER.limit({ key: ip })).success) {
        return json(429, { error: "rate limited; retry later" });
      }
      if (!(await env.GLOBAL_LIMITER.limit({ key: "all" })).success) {
        console.log(JSON.stringify({ msg: "global rate limit hit", ip }));
        return json(429, { error: "rate limited; retry later" });
      }

      const len = Number(request.headers.get("content-length") || "0");
      if (!len || len > 4096) {
        return json(400, { error: "body must be small JSON with content-length" });
      }

      let body;
      try {
        body = await request.json();
      } catch {
        return json(400, { error: "invalid JSON" });
      }
      const appId = String(body.app_id || "");
      const tag = String(body.tag || "");
      const claimedRepo = body.repository ? String(body.repository) : null;
      if (!APP_ID_RE.test(appId)) return json(400, { error: "invalid app_id" });
      if (!TAG_RE.test(tag)) return json(400, { error: "invalid tag" });

      // 1. app must be in the catalog (the per-app apps/<id>.json files are
      // stripped from the published site, so the light catalog carries
      // sourceUrl for exactly this lookup)
      const catRes = await fetch(`${env.SITE_ORIGIN}/catalog.json`, {
        headers: { "user-agent": "flatpark-release-hook" },
        cf: { cacheTtl: 300, cacheEverything: true },
      });
      if (!catRes.ok) return json(502, { error: "catalog lookup failed" });
      const catalog = await catRes.json();
      const app = (catalog.apps || []).find((a) => a.id === appId);
      if (!app) return json(404, { error: "unknown app_id" });

      // 2. upstream repo comes from our catalog, not the request
      const m = GH_SOURCE_RE.exec(app.sourceUrl || "");
      if (!m) return json(422, { error: "app has no GitHub sourceUrl; not push-updatable" });
      const upstream = `${m[1]}/${m[2]}`;
      if (claimedRepo && claimedRepo.toLowerCase() !== upstream.toLowerCase()) {
        // Catches a copy-pasted wrong app-id in someone's workflow.
        return json(403, {
          error: `app_id ${appId} is registered to ${upstream}, not ${claimedRepo}`,
        });
      }

      // 3. the release must really exist upstream
      const relRes = await fetch(
        `https://api.github.com/repos/${upstream}/releases/tags/${encodeURIComponent(tag)}`,
        { headers: ghHeaders(env.DISPATCH_TOKEN) },
      );
      if (relRes.status === 404) {
        return json(400, { error: `no release ${tag} on ${upstream}` });
      }
      if (!relRes.ok) return json(502, { error: "upstream release check failed" });

      // All checks passed — dispatch with our token.
      const dispatchRes = await fetch(
        `https://api.github.com/repos/${env.DISPATCH_REPO}/dispatches`,
        {
          method: "POST",
          headers: { ...ghHeaders(env.DISPATCH_TOKEN), "content-type": "application/json" },
          body: JSON.stringify({
            event_type: "app-release",
            client_payload: { app_id: appId, tag, repo: upstream },
          }),
        },
      );
      if (dispatchRes.status !== 204) {
        console.log(JSON.stringify({
          msg: "dispatch failed",
          status: dispatchRes.status,
          app_id: appId,
        }));
        return json(502, { error: "dispatch failed" });
      }

      console.log(JSON.stringify({ msg: "dispatched", app_id: appId, tag, repo: upstream }));
      return json(200, { ok: true, app_id: appId, tag });
    } catch (err) {
      console.log(JSON.stringify({ msg: "unhandled error", error: String(err) }));
      return json(500, { error: "internal error" });
    }
  },
};
