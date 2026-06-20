# Yet another Flatpak hub

FlatPark is a Flatpak hub for apps that ship as a definitive download, built to
be driven by AI agents.

## Goals

- **AI-driven by design.** Onboarding, review, publishing, upgrading, and
  cleanup are all meant to be driven by AI agents. Leaning on agents to do this
  work efficiently is a primary goal, not an afterthought.
- **One runtime, always latest.** Every hosted app is continuously upgraded and
  tested against the newest runtime, so you only ever need a single, latest copy
  of the runtime installed.
- **extra-data only, no build hosting.** FlatPark hosts only extra-data apps: it
  downloads official releases and repackages them — it never builds from source.
  That keeps installing and updating the apps you need in one place, while
  Flatpak keeps them sandboxed and out of your home directory.
- **Open to vibe-coded apps, with guardrails.** Apps built with AI ("vibe
  coding") are welcome, under clear rules enforced by AI review that weighs
  development history and app quality — and with an explicit de-listing process.

## Install

```sh
flatpak --user remote-add --if-not-exists flatpark https://dl.flatpark.org/flatpark.flatpakrepo
flatpak --user install flatpark <app-id>
```

`--user` installs into your home (no admin); drop it from both commands for a
system-wide install. Browse the catalog at <https://flatpark.org>.

## Add an app

Onboarding is meant to run through an AI agent. Open this repo in your agent
(e.g. Claude Code) and prompt it:

> I want to publish **\<app or upstream URL\>** to FlatPark. Read
> `CONTRIBUTING.md` and the existing PRs, then write and validate the manifest
> under `registry/<app-id>/`.

It writes the `flatpark.yml` descriptor and Flatpak manifest, validates and
test-builds them, and opens a PR. If it can't get there from the rules and the
existing PRs, open an issue — letting an agent submit, test, and PR end-to-end
is the goal.

## License

FlatPark's own code is [MIT](LICENSE). It does **not** license the packaged
applications themselves — those remain their vendors' property and are fetched
from official sources at install time.
