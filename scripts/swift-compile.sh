#!/bin/bash
set -euo pipefail
legacy_sdk=/Library/Developer/CommandLineTools/SDKs/MacOSX14.5.sdk
if [ "${DUO_USE_SYSTEM_SDK:-0}" = "1" ] || [ ! -d "$legacy_sdk" ]; then
  exec swiftc -sdk "$(xcrun --sdk macosx --show-sdk-path)" -target "$(uname -m)-apple-macos14.0" "$@"
fi
overlay_root=$(mktemp -d)
trap 'rm -rf "$overlay_root"' EXIT
touch "$overlay_root/empty.modulemap"
# CLT in this Mac has two modulemaps defining SwiftBridging. Mask the legacy
# copy only for this compiler invocation; never modify the installed toolchain.
cat > "$overlay_root/overlay.json" <<EOF
{"version":0,"roots":[{"type":"file","name":"/Library/Developer/CommandLineTools/usr/include/swift/module.modulemap","external-contents":"$overlay_root/empty.modulemap"}]}
EOF
swiftc -sdk "$legacy_sdk" -target "$(uname -m)-apple-macos14.0" -vfsoverlay "$overlay_root/overlay.json" -Xcc -ivfsoverlay -Xcc "$overlay_root/overlay.json" "$@"
