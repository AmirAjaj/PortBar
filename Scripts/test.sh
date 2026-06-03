#!/bin/bash
#
# Runs the test suite. Swift Testing runs out of the box with full Xcode, but a
# Command Line Tools–only setup needs its Testing.framework added to the search
# and runtime paths — this detects that case and adds the flags.
set -euo pipefail

cd "$(dirname "$0")/.."

DEV_DIR="$(xcode-select -p)"
if [[ "$DEV_DIR" == *CommandLineTools* ]]; then
  FW="$DEV_DIR/Library/Developer/Frameworks"
  LIB="$DEV_DIR/Library/Developer/usr/lib"
  exec swift test \
    -Xswiftc -F -Xswiftc "$FW" \
    -Xlinker -F -Xlinker "$FW" \
    -Xlinker -rpath -Xlinker "$FW" \
    -Xlinker -L -Xlinker "$LIB" \
    -Xlinker -rpath -Xlinker "$LIB" "$@"
else
  exec swift test "$@"
fi
