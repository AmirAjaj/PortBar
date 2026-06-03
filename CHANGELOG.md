# Changelog

All notable changes to PortBar are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project aims to
follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- The menu bar shows the live dev-server count next to the plug icon, so you can
  see how many are running without opening the popover.
- In-app update check and a Restart action.

### Changed
- Health probing is now gentler: ports are only checked over HTTP when newly
  seen or every ~30s, instead of every scan, to avoid spamming dev server logs.

## [0.1.0] - 2026-06-03

First release.

### Added
- Menu bar list of every listening TCP port, grouped into dev servers, other
  listeners, and (optional) system listeners.
- Project labels derived from each process's working directory.
- Health dot per port (HTTP probe): green = responding, orange = listening but
  not answering.
- Kill actions: graceful stop (SIGTERM) and force quit (SIGKILL), plus "Stop
  all" for dev servers.
- Open in browser (using the default browser's icon), and jump to the project in
  your editor, Terminal, or Finder.
- Apple/OS daemons hidden by default, with a toggle to show them.
- Launch at login, adjustable refresh interval.
- Homebrew cask, generated app icon, CI, and a tagged release workflow.

[Unreleased]: https://github.com/AmirAjaj/PortBar/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/AmirAjaj/PortBar/releases/tag/v0.1.0
