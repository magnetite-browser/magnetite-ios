#!/usr/bin/env bash
# Build the shared Rust core into Core/. It lives in its own repository,
# expected beside this one.
set -euo pipefail
cd "$(dirname "$0")/.."
"${MAGNETITE_MOBILE_CORE:-../magnetite-mobile-core}/scripts/ios.sh" "$PWD/Core"
