#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bundle="native/DuoNative.app/Contents"
mkdir -p "$bundle/MacOS" "$bundle/Resources"
bash scripts/swift-compile.sh native/SeatCore.swift native/MouseCapture.swift native/BrowserPanel.swift native/main.swift -o "$bundle/MacOS/DuoNative" -framework AppKit -framework WebKit -framework IOKit
cp native/virtual-input.cjs native/page-input.js "$bundle/Resources/"
cp native/Info.plist "$bundle/Info.plist"
codesign --force --sign - --identifier com.gestaobem.duobrowser.native native/DuoNative.app
