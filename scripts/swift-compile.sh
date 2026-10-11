#!/bin/bash
set -euo pipefail
project_root=$(cd "$(dirname "$0")/.." && pwd)
overlay_root=$(mktemp -d)
trap 'rm -rf "$overlay_root"' EXIT
touch "$overlay_root/empty.modulemap"
# CLT in this Mac has two modulemaps defining SwiftBridging. Mask the legacy
# copy only for this compiler invocation; never modify the installed toolchain.
cat > "$overlay_root/overlay.json" <<EOF
{"version":0,"roots":[{"type":"file","name":"/Library/Developer/CommandLineTools/usr/include/swift/module.modulemap","external-contents":"$overlay_root/empty.modulemap"}]}
EOF
swiftc -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX14.5.sdk -target arm64-apple-macos14.0 -vfsoverlay "$overlay_root/overlay.json" -Xcc -ivfsoverlay -Xcc "$overlay_root/overlay.json" "$@"
