#!/usr/bin/env bash
# Generate Magnetite.xcodeproj from project.yml (needs xcodegen).
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -d Core/MagnetiteCoreFFI.xcframework ]] || scripts/core.sh
xcodegen generate --quiet
