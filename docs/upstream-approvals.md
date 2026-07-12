# Upstream approval records

Every app with the developer-approved blue shield (`catalog.upstream_approved: true`
in its `flatpark.yml`) must have a row in the Approved table below linking the
issue, PR, or discussion where the upstream maintainer authorized the FlatPark
listing. When flipping the flag, cite the same link in the commit message and add
the row in the same PR. CI enforces the flag→row direction
(`scripts/check-approvals.sh`): a `true` flag with no row here fails `pr-checks`;
a row without the flag only warns (e.g. a withdrawal in progress).

Ruling an app upstream-approved requires an **auditable source** — a link a
reviewer can open and verify, tied to an identity that plausibly speaks for the
project. A private channel (email, Discord, …) is not enough on its own: ask the
maintainer to confirm somewhere public and linkable first. When the upstream
developer publishes the app themselves, have them open the PR first, then put
that PR link in the table — the PR itself is the evidence.

## Approved

| App | ID | Approval | Date |
|-----|----|----------|------|
| GeoLibre | `app.geolibre.GeoLibre` | [opengeos/GeoLibre#696](https://github.com/opengeos/GeoLibre/issues/696) | 2026-06 |
| Tabularis | `dev.tabularis.Tabularis` | [TabularisDB/tabularis#326](https://github.com/TabularisDB/tabularis/issues/326); upstream also merged FlatPark install docs ([tabularis#341](https://github.com/TabularisDB/tabularis/pull/341), [website#7](https://github.com/TabularisDB/website/pull/7)) | 2026-06 |
| DiscordChatExporter | `me.tyrrrz.DiscordChatExporter` | [Tyrrrz/DiscordChatExporter#1562 (comment)](https://github.com/Tyrrrz/DiscordChatExporter/discussions/1562#discussioncomment-17532679) | 2026-06 |
| YoutubeDownloader | `me.tyrrrz.YoutubeDownloader` | Same grant as DiscordChatExporter — [the comment](https://github.com/Tyrrrz/DiscordChatExporter/discussions/1562#discussioncomment-17532679) covers Tyrrrz's Avalonia desktop apps | 2026-06 |
| HiresTI | `com.hiresti.player` | [yelanxin/hiresTI#9 (comment)](https://github.com/yelanxin/hiresTI/issues/9) — "I really appreciate you publishing this project on Flatpark" | 2026-06-28 |
| Yaak | `app.yaak.Yaak` | [yaak.app feedback: Flatpak/Flathub](https://yaak.app/feedback/posts/flatpak-flathub) | 2026-07 |
| Tine | `page.tine.Tine` | [martinkoutecky/tine#65](https://github.com/martinkoutecky/tine/issues/65) — approval covers the package as independently maintained by FlatPark (see commit e41e6f4 for the terms) | 2026-07-10 |
| Open DroneLog | `com.opendronelog.OpenDroneLog` | [arpanghosh8453/open-dronelog#211](https://github.com/arpanghosh8453/open-dronelog/issues/211) | 2026-07-10 |
| Folia | `top.izuna.foliamajor` | [chthollyphile/folia-site#3](https://github.com/chthollyphile/folia-site/issues/3) | 2026-07-10 |
| GSE Profiler | `io.github.todevelopers.GseProfiler` | Approved by construction — submitted and maintained by its own developer ([flatpark#83](https://github.com/flatpark/flatpark/pull/83)) | 2026-07-10 |
| AeroFTP | `com.aeroftp.AeroFTP` | Maintainer co-maintains the package: [flatpark#98](https://github.com/flatpark/flatpark/pull/98) and [axpdev-lab/aeroftp#388](https://github.com/axpdev-lab/aeroftp/issues/388) — "I took the recipe on from our side to co-maintain it" | 2026-07-10 |

## Not approved

Checked but **not** (or not yet) approved — do not flip without new evidence:

| App | ID | Status |
|-----|----|--------|
| Markra | `app.markra.Markra` | Shield withdrawn 2026-07-12: the only record is a [V2EX reply](https://v2ex.com/t/1224360?p=1#r_17821484) that is too ambiguous to count as authorization; explicit confirmation from the developer is pending |
| AB Download Manager | `com.abdownloadmanager.AbDownloadManager` | No reply to the FlatPark comment in [amir1376/ab-download-manager#175](https://github.com/amir1376/ab-download-manager/issues/175); maintainer publicly hesitant about Flatpak (2025-09) |
