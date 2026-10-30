# Omarchy News

**Know what changed before and after an Omarchy update.**

A small Omarchy bar plugin for browsing official release notes, tracking unread
updates, and revisiting earlier releases—all without leaving your desktop.

**Early version (0.1.0).** The core feed works; layout and readability are still
being refined. This is an independent community plugin, not an official Omarchy
project.

## Features

- Newspaper icon with a subtle unread dot.
- Available, Installed, History, and Preview views.
- Official upstream notes with formatted headings, lists, and code.
- Search across release titles and full notes.
- Individual and **Mark all as read** actions, saved locally.
- Cached notes for offline reading, with fetch errors shown in the panel.
- A **Source** button for the original notes, screenshots, and linked changes.

The plugin never installs updates or executes commands from release notes.

## Install

Requires Omarchy with its Quickshell-based shell and plugin support, plus Python 3.
There are no third-party Python dependencies or API keys.

```sh
omarchy plugin add https://github.com/yubinex/omarchy-news --enable
```

Click the newspaper icon to open the feed. Right-click it to refresh.

If you already use a local development copy, keep that copy rather than trying
to install a second plugin with the same ID.

## What the statuses mean

| View | Meaning |
| --- | --- |
| Available | A newer published stable release—not a guarantee that your package mirror is ready. |
| Installed | The matching installed release and releases covered by the latest observed upgrade. |
| History | Earlier releases. |
| Previews | Prereleases and releases whose availability cannot be verified for your channel. |

Availability detection currently targets the stable channel. RC and edge support
is limited. The first run establishes your installed-version baseline; it does
not claim that an update just happened. Upgrade tracking starts from that baseline.

Release notes describe upstream changes, not an audit of your local configuration
or all Arch package changes. Wording such as “removed from new installs” is
preserved: that does **not** mean the app was uninstalled from your machine.

## Read status and caching

**Mark all as read** applies to the entire loaded feed, regardless of the current
filter or search. New releases and revised notes become unread again. The bar dot
counts relevant installed/newer notes, not every unread historical release.

The feed loads the latest **50 GitHub release entries** and caches them for
30 minutes. Refresh requests fresh notes. GitHub's unauthenticated API limits
apply; cached notes remain available if a request fails.

- State: `$XDG_STATE_HOME/omarchy-news` (default `~/.local/state/omarchy-news`).
- Cache: `$XDG_CACHE_HOME/omarchy-news` (default `~/.cache/omarchy-news`).

Notes are fetched from the public [Omarchy GitHub releases API](https://github.com/omacom/omarchy/releases).
Embedded remote images and raw HTML are not rendered. Only the Source button
opens a validated official release URL; note content is never executed.

## Local development

```sh
git clone https://github.com/yubinex/omarchy-news
cd omarchy-news
bash tools/install-local.sh
```

The development installer links this working tree into
`~/.config/omarchy/plugins/yubinex.omarchy-news`, backs up `shell.json`, and adds
the bar widget. It refuses to overwrite a different installed copy.

After QML edits, the shell may retain cached components. If rescanning does not
pick them up, reload with:

```sh
omarchy restart shell
```

### Tests

```sh
python3 -m unittest discover -s tests -v
node tests/test_notes.cjs
qmllint -I /usr/share/omarchy/shell BarWidget.qml Panel.qml NewsButton.qml
bash tools/smoke-test.sh
```

Node is needed only for renderer development tests. QML lint and the smoke test
require an installed Omarchy shell; the smoke test briefly opens a fixture panel
on a running Wayland desktop. Backend tests are isolated and do not access the
network or alter your real reading history.

## Next improvements

- More polished spacing, contrast, and long-note readability.
- Better separation of upgrade instructions, highlights, and detailed changes.
- Optional notifications and better channel support.
- Commit-level fallback when official notes are missing.

Feedback and contributions are welcome. Please include your Omarchy version and
screenshots when reporting UI issues. Never paste credentials or private logs.

## License

Plugin code: [MIT](LICENSE). Release-note content belongs to its upstream authors.
