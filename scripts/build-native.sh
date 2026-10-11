#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bundle="native/DuoNative.app/Contents"
mkdir -p "$bundle/MacOS" "$bundle/Resources"
bash scripts/swift-compile.sh native/SeatCore.swift native/MouseCapture.swift native/BrowserPanel.swift native/BraveConnection.swift native/main.swift -o "$bundle/MacOS/DuoNative" -framework AppKit -framework WebKit -framework IOKit
cp native/virtual-input.cjs native/page-input.js "$bundle/Resources/"
cp native/Info.plist "$bundle/Info.plist"
cp native/brave-bridge.cjs "$bundle/Resources/"
mkdir -p "$bundle/Resources/node_modules"
cp -R node_modules/ws "$bundle/Resources/node_modules/"
codesign --force --sign - --identifier com.gestaobem.duobrowser.native native/DuoNative.app
