# publish-action launch checklist

Turns FlatPark's pull-mode updates (daily cron polling upstream) into push
mode: upstream CI notifies us the moment a release is published, and the
update PR opens within minutes.

Three components, in dependency order:

1. **Dispatch workflow** — `.github/workflows/release-dispatch.yml` fires on
   `repository_dispatch` (type `app-release`), recomputes pins for that one
   app, and opens a focused PR on `auto/release-<app-id>` — several apps
   releasing the same day = several small parallel PRs. The daily
   `update-check.yml` full sweep stays the safety net and supersedes any
   per-app PR its batch already covers. Already in this repo; works
   standalone the moment it's merged.
2. **Auth bridge Worker** — `workers/release-hook/`, serves
   `hooks.flatpark.org/release`. Validates unauthenticated pings from
   upstream CI against public state (catalog + real GitHub release), then
   dispatches to this repo with our own token.
3. **[flatpark/publish-action](https://github.com/flatpark/publish-action)** —
   the standalone action repo (Marketplace requires one repo per action),
   pushed with tags `v1.0.0` + rolling `v1`. Upstream adds 5 lines to their
   release workflow.

## A. Dispatch workflow (no external deps — usable today)

Merge `release-dispatch.yml` (+ the `update-check.yml` supersede extension).
Smoke-test by hand:

```sh
gh api repos/flatpark/flatpark/dispatches \
  -f event_type=app-release \
  -f 'client_payload[app_id]=me.tyrrrz.DiscordChatExporter' \
  -f 'client_payload[tag]=2.47.3' \
  -f 'client_payload[repo]=Tyrrrz/DiscordChatExporter'
```

Expected: a release-dispatch run appears in Actions, recomputes pins for that
app only, and exits quietly if nothing moved (e.g. the tag is already pinned).
When something did move it opens `Update <app-id> to <tag>` from
`auto/release-<app-id>`. A ping for a release whose Linux asset isn't uploaded
yet is also a quiet no-op — tomorrow's update-check cron picks it up, and its
supersede step closes any per-app PR the daily batch already covers.

## B. Worker

Prerequisite: `catalog.json` must carry each app's `sourceUrl` — the Worker
validates pings against it (the richer `apps/<id>.json` files are stripped
from the published site). `gen-apps-json.sh` now emits the field; it goes
live with the next site publish, so run one publish before deploying the
Worker. Apps without a GitHub `source_url` in their descriptor simply aren't
push-updatable (the Worker answers 422; the daily cron still covers them).

```sh
cd workers/release-hook
wrangler secret put DISPATCH_TOKEN   # paste the PAT below
wrangler deploy                      # custom_domain route creates the DNS record
```

The PAT: GitHub → Settings → Developer settings → Fine-grained tokens →
scope **only flatpark/flatpark**, permission **Contents: read and write**
(that's what `repository_dispatch` requires), expiration **No expiration**
(fine-grained tokens allow it unless an org policy caps lifetime). Public-repo
read (default) also covers the upstream release-existence check. Two lifecycle
caveats: GitHub deletes PATs unused for a full year (a dispatch-only token on
a quiet catalog could conceivably idle that long), and if the token ever dies
the blast radius is every adopter's release workflow failing our step — which
is why the action README tells upstreams to set `continue-on-error: true`,
and the daily cron delivers the update either way. Long-term the clean fix is
a GitHub App (the Worker mints 1-hour installation tokens on demand; nothing
to rotate or expire).

Smoke-test the deployed Worker:

```sh
# happy path — should 200 and trigger an update-check run
curl -sS -H 'content-type: application/json' \
  -d '{"app_id":"me.tyrrrz.DiscordChatExporter","tag":"2.47.3","repository":"Tyrrrz/DiscordChatExporter"}' \
  https://hooks.flatpark.org/release

# each guard — expect 400/403/404
curl -sS -d '{"app_id":"com.evil.NotListed","tag":"v1"}' -H 'content-type: application/json' https://hooks.flatpark.org/release
curl -sS -d '{"app_id":"me.tyrrrz.DiscordChatExporter","tag":"no-such-tag"}' -H 'content-type: application/json' https://hooks.flatpark.org/release
```

Optional hardening: a Cloudflare rate-limiting rule on `hooks.flatpark.org`
(e.g. 10 req/min per IP). Abuse ceiling without it is just extra update-check
runs; the human-merged PR remains the gate.

## C. Action repository

Done — [flatpark/publish-action](https://github.com/flatpark/publish-action)
exists with `v1.0.0` and the rolling `v1` tag (local clone:
`~/Project/publish-action`). Rolling major tag on every future release:

```sh
git tag -f v1 vX.Y.Z && git push -f origin v1
```

## D. Marketplace listing

Requirements: verified email + 2FA on the publishing account; `action.yml`
at repo root; `name` unique across the Marketplace (currently
"Publish to FlatPark" — GitHub rejects the draft if taken, just rename).

1. On flatpark/publish-action → Releases → Draft a new release for `v1.0.0`.
2. Tick **Publish this Action to the GitHub Marketplace** (first time: accept
   the Marketplace Developer Agreement).
3. Primary category **Publishing**, secondary **Deployment**.
4. Publish. The listing renders the README; search matches
   name/description/README, which already carry "flatpak", "release",
   "publish", "linux", "distribute".

## E. Adoption motion

- Every upstream README/listing PR we send gets the 5-line workflow snippet
  included — merging one PR beats trusting an unknown source
  (see the standing practice of asking upstream to list FlatPark officially).
- The snippet in adopters' workflow files is a permanent referral:
  `uses: flatpark/publish-action@v1` sits in their repo for every reader.
- Expectation check: few upstreams will adopt unprompted. Value #1 is the
  Marketplace search page itself (≈5 results for "flatpak" today); value #2
  is lowering the ask in our upstream PRs.
