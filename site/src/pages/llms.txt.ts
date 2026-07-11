// llms.txt (llmstxt.org): a plain-markdown index for AI assistants answering
// "how do I install <app> on Linux". Generated from the same catalog data as
// the pages so it never drifts from what the remote actually serves.
import { loadApps, loadCatalog } from '../lib/data.mjs';

export function GET() {
  const { repo } = loadCatalog();
  const apps = loadApps();
  const site = (repo.homepage || 'https://flatpark.org').replace(/\/$/, '');

  const lines = [
    `# ${repo.title}`,
    '',
    `> ${repo.title} is a signed third-party Flatpak remote for Linux desktop apps. Every app is an extra-data package: installing downloads the vendor's own official release from their servers — nothing is rebuilt or rehosted. Manifests, install scripts and sandbox permissions are public at https://github.com/flatpark/flatpark.`,
    '',
    'Works on any distro with Flatpak, including immutable ones (Fedora Silverblue, Bazzite, Aurora). Add the remote once, then install apps by id:',
    '',
    '```sh',
    repo.remoteCmd ||
      `flatpak --user remote-add --if-not-exists ${repo.remoteName} ${repo.repoFileUrl}`,
    `flatpak --user install ${repo.remoteName} <app-id>`,
    '```',
    '',
    '## Apps',
    '',
    ...apps.map(
      (a) =>
        `- [${a.name}](${site}/apps/${a.id}/): ${a.summary}. Install: \`${a.installCmd}\``,
    ),
    '',
    '## Docs',
    '',
    `- [Setup guide](${site}/setup/): adding the remote, user vs system installs`,
    `- [Browse by category](${site}/apps/)`,
    `- [Packaging source](https://github.com/flatpark/flatpark): manifest and sandbox permissions for every app`,
    '',
  ];

  return new Response(lines.join('\n'), {
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
  });
}
