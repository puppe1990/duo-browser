#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift_formatter=$(command -v swift-format || true)
if [ -z "$swift_formatter" ]; then
  swift_formatter=$(xcrun --find swift-format)
fi
"$swift_formatter" lint --strict native/*.swift tests/*.swift
cargo fmt --manifest-path src-tauri/Cargo.toml --check
# Tauri's resource validation requires the helper bundle to exist.
bash scripts/build-native.sh
cargo clippy --manifest-path src-tauri/Cargo.toml --locked --all-targets -- -D warnings
