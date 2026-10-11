#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
test_binary="$test_root/duo-tests"
bash scripts/swift-compile.sh native/SeatCore.swift tests/CoreTests.swift -o "$test_binary"
"$test_binary"
node --test tests/*.test.cjs
if [ "${DUO_TEST_BRAVE:-0}" = "1" ]; then
  bash scripts/build-native.sh
  brave_binary="$test_root/duo-brave-smoke"
  bash scripts/swift-compile.sh native/SeatCore.swift native/BrowserPanel.swift native/BraveConnection.swift tests/BraveSmoke.swift -o "$brave_binary" -framework AppKit -framework WebKit
  "$brave_binary"
fi
if [ "${DUO_TEST_UI:-0}" = "1" ]; then
  native_binary="$test_root/duo-native-smoke"
  bash scripts/swift-compile.sh native/SeatCore.swift native/BrowserPanel.swift tests/NativeSmoke.swift -o "$native_binary" -framework AppKit -framework WebKit
  "$native_binary"
fi
if [ "${DUO_TEST_HID:-0}" = "1" ]; then
  bash scripts/build-native.sh
  probe_binary="$test_root/duo-exclusive-probe"
  bash scripts/swift-compile.sh tests/ExclusiveProbe.swift -parse-as-library -o "$probe_binary" -framework IOKit
  DUO_EXCLUSIVE_PROBE="$probe_binary" python3 tests/capture-smoke.py
fi
