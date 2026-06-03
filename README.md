# PortBar

[![CI](https://github.com/AmirAjaj/PortBar/actions/workflows/ci.yml/badge.svg)](https://github.com/AmirAjaj/PortBar/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Platform](https://img.shields.io/badge/macOS-14%2B-blue)

A tiny native macOS menu bar app that shows every dev server listening on your
machine — what it is, which project it belongs to, and a one-click way to kill
it.

If you've ever stared at `EADDRINUSE: port 3000 already in use` and had no idea
*which* of your half-dozen running servers grabbed it, PortBar is for you.

> **Status:** v0.1 — early days. Built from scratch in Swift with no third-party
> dependencies. Contributions welcome.

## Features

- 🔌 **Live port list in your menu bar** — the icon shows how many dev servers
  are currently listening.
- 🧠 **Knows what each port is** — process name plus the project directory it's
  running from (e.g. `3000 — node (my-app)`), so you can tell your servers apart
  at a glance.
- ✋ **One-click kill** — graceful `SIGTERM` or forceful `SIGKILL`, right from
  the dropdown. The list refreshes immediately after.
- 🌐 **Open in browser** — jump to `localhost:<port>` without retyping it.
- 🙈 **No system noise** — Apple/OS daemons (rapportd, Control Center, …) are
  detected by their executable path and hidden by default. Toggle them on if you
  want to see everything.
- 🪶 **Native & lightweight** — pure SwiftUI `MenuBarExtra`, no Electron, no
  background bloat. It just shells out to `lsof`.

## Requirements

- macOS 14 (Sonoma) or later
- Swift 6 toolchain (Xcode or Command Line Tools) to build from source

## Install

### Homebrew

```bash
brew tap amirajaj/portbar https://github.com/AmirAjaj/PortBar
brew install --cask portbar
```

PortBar is ad-hoc signed (not yet notarized), so on first launch macOS may block
it. If so: **System Settings → Privacy & Security → Open Anyway**, or run
`xattr -dr com.apple.quarantine "/Applications/PortBar.app"`.

### Manual

Grab `PortBar.zip` from the [latest release](https://github.com/AmirAjaj/PortBar/releases/latest),
unzip, and drag `PortBar.app` to `~/Applications`.

## Build & run

```bash
git clone https://github.com/AmirAjaj/PortBar.git
cd PortBar

# Run it straight away during development:
make run

# …or build a proper PortBar.app and install it to ~/Applications:
make install
```

Then look for the 🔌 icon in your menu bar.

## How it works

PortBar avoids private APIs entirely. Every few seconds it runs:

```
lsof -nP -iTCP -sTCP:LISTEN
```

to find listening TCP sockets, then enriches each one:

- `ps -p <pid> -o comm=` → the process's executable path (used to spot and hide
  system daemons living under `/System`, `/usr/bin`, etc.).
- `lsof -a -p <pid> -d cwd -Fn` → the process's working directory, used to label
  the port with its project name.

A port is treated as a **dev server** if its command matches a known dev tool
(`node`, `vite`, `python`, `cargo`, …) *or* it's running out of a directory
under your home folder. Everything else that isn't a system daemon lands under
"Other listeners."

## Project layout

```
Sources/PortBar/
  PortBarApp.swift      — @main app + MenuBarExtra, hides the Dock icon
  MenuContentView.swift — the dropdown UI (sections, rows, settings)
  PortScanner.swift     — periodic scan, parsing, classification
  ListeningPort.swift   — the port model + dev/system heuristics
  ProcessKiller.swift   — SIGTERM / SIGKILL via kill(2)
  LaunchAtLogin.swift   — SMAppService wrapper for "Launch at login"
  Shell.swift           — minimal helper for running lsof/ps
```

## Roadmap

- [ ] App icon + menu bar icon polish
- [ ] Filter/search box for when lots of ports are open
- [ ] "Copy `kill` command" and "Reveal project in Finder" actions
- [ ] Remember per-port labels the user assigns
- [ ] Notarized release + Homebrew cask

## Contributing

Issues and PRs are very welcome — this is a young project with plenty of low-
hanging fruit (see the roadmap). Keep changes dependency-free and native where
possible.

## License

[MIT](LICENSE) © 2026 Amir Ajaj
