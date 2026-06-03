#!/bin/bash
#
# Builds PortBar and assembles a distributable PortBar.app bundle in dist/.
#
# Usage: ./Scripts/build-app.sh [debug|release]   (default: release)
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/PortBar.app"

cd "$ROOT"

echo "==> Building ($CONFIG)…"
swift build -c "$CONFIG"

BIN="$(swift build -c "$CONFIG" --show-bin-path)/PortBar"
if [[ ! -x "$BIN" ]]; then
  echo "error: built binary not found at $BIN" >&2
  exit 1
fi

echo "==> Assembling $APP…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/PortBar"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# Ad-hoc code signature so Launch-at-Login (SMAppService) and Gatekeeper behave.
codesign --force --deep --sign - "$APP" 2>/dev/null || \
  echo "warning: codesign failed (app will still run, but Launch-at-Login may not)"

echo "==> Done: $APP"
echo "    Run it with:  open \"$APP\""
