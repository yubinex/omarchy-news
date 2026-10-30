# Omarchy News

Local prototype of an Omarchy shell news feed. Official release notes before
and after updating, without running updates or changing system packages.

## Development

This project is tracked in its own Git repository. No remote is required.
Release-note content belongs to its upstream authors; plugin code is MIT licensed.

Runtime dependencies: Omarchy's Quickshell shell and Python 3 (standard library only).

## Try it locally

```sh
bash tools/install-local.sh
```

This links the working tree into `~/.config/omarchy/plugins/yubinex.omarchy-news`,
backs up `shell.json`, and adds **News** to the right-hand bar. No package install,
system update, GitHub repository creation, or push is performed. Right-click News
to refresh; left-click opens the feed. Source edits are local and may require
`omarchy-shell shell rescanPlugins` when using the development symlink.

## First-version behavior

- Official GitHub release notes, not generated summaries; original categories
  and qualifications are preserved. Click **Official notes** for screenshots,
  linked pull requests, and full code comparisons.
- **Available** means a newer published release for your channel; it does not
  guarantee your package mirror offers it yet. Previews are separate on stable.
- **Installed** shows the matching release and releases observed during your
  latest upgrade. The initial launch establishes a baseline, not a fake update.
- **History** includes earlier releases; **All** also includes previews.
- Read status is explicit (**Mark as read**) and persists locally. Changed
  release-note content becomes unread again. Notes remain readable offline
  after the first successful fetch, with a stale/error notice.
- Search filters titles and the full notes. The bar badge counts relevant
  installed/newer notes, not every unread historical release.
- The reader uses selectable plain text, omits embedded images, and never runs
  commands from release notes. It opens only validated official release URLs.
- This is an Omarchy release feed, not an Arch package changelog or an audit of
  every local configuration change. Missing upstream notes cannot be turned
  into a guaranteed exhaustive changelog. Commit-level fallback is future work.

## Verification

```sh
python3 -m unittest discover -s tests -v
python3 news.py feed
qmllint -I /usr/share/omarchy/shell BarWidget.qml Panel.qml
bash tools/smoke-test.sh  # Requires a running Wayland desktop; opens a test panel briefly.
```

No tokens or GitHub credentials are needed. Unauthenticated GitHub API rate
limits apply. Refresh uses a cache to avoid unnecessary network requests.

State lives under `$XDG_STATE_HOME/omarchy-news` (default
`~/.local/state/omarchy-news`); cached release notes live under
`$XDG_CACHE_HOME/omarchy-news` (default `~/.cache/omarchy-news`). The initial
feed is limited to the 50 most recent GitHub release entries. Channel-aware
availability currently targets stable; edge/unknown and unmatched RC releases
remain explicitly unverified previews.

## Local verification (2026-10-30)

- 11 isolated Python tests passed, including stale cache, read revisions,
  upgrade tracking, version ordering, and state writes.
- QML lint passed; a Wayland runtime smoke test exercised release rendering,
  selection, the Installed filter, and opening/closing the panel.
- Live GitHub fetch returned 50 releases. This machine was detected as
  `4.0.6-1` / stable; `v4.0.6` was installed and `v4.5.0-rc1/rc2` were previews.

The UI is intentionally a first draft. Next design candidates: richer section
cards, change-type filters, optional notifications, and commit-level details.
