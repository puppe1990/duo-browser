#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_binary=$(mktemp -d)/duo-tests
bash scripts/swift-compile.sh native/SeatCore.swift tests/CoreTests.swift -o "$test_binary"
"$test_binary"
node --test tests/*.test.cjs
native_binary=$(mktemp -d)/duo-native-smoke
bash scripts/swift-compile.sh native/SeatCore.swift native/BrowserPanel.swift tests/NativeSmoke.swift -o "$native_binary" -framework AppKit -framework WebKit
"$native_binary"
if [ "${DUO_TEST_HID:-0}" = "1" ]; then
  bash scripts/build-native.sh
  probe_binary=$(mktemp -d)/duo-exclusive-probe
  bash scripts/swift-compile.sh tests/ExclusiveProbe.swift -parse-as-library -o "$probe_binary" -framework IOKit
  DUO_EXCLUSIVE_PROBE="$probe_binary" python3 tests/capture-smoke.py
fi
