#!/usr/bin/env bash
# Take the App Store pictures into build/screenshots/<device>/: the app on
# the demo chain, on the simulators of the sizes the store asks for, or on
# those named: scripts/screenshots.sh ["<simulator>" ...]
set -euo pipefail
cd "$(dirname "$0")/.."
CORE="${MAGNETITE_MOBILE_CORE:-../magnetite-mobile-core}"
DEVICES=("$@")
[[ $# -gt 0 ]] || DEVICES=("iPhone 17 Pro Max" "iPad Pro 13-inch (M5)")

scripts/project.sh
(cd "$CORE" && exec cargo run --quiet --example demo_server) > /dev/null &
server=$!
trap 'kill $server 2>/dev/null || true' EXIT
until nc -z localhost 8787 2>/dev/null; do sleep 1; done

for device in "${DEVICES[@]}"; do
  out="build/screenshots/$device"
  rm -rf "$out" "$out.xcresult"
  xcrun simctl bootstatus "$device" -b > /dev/null
  # A fresh install, and the status bar the store's pictures usually show.
  xcrun simctl uninstall "$device" org.magnetitebrowser.ios 2>/dev/null || true
  xcrun simctl status_bar "$device" override --time 9:41 \
    --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4
  xcodebuild -project Magnetite.xcodeproj -scheme Magnetite \
    -destination "platform=iOS Simulator,name=$device" -resultBundlePath "$out.xcresult" \
    -only-testing:MagnetiteUITests/StoreScreenshots test > /dev/null
  xcrun simctl shutdown "$device"
  xcrun xcresulttool export attachments --path "$out.xcresult" --output-path "$out" > /dev/null
  # Name each picture as the test did.
  python3 - "$out" <<'PY'
import json, os, sys
out = sys.argv[1]
for test in json.load(open(f"{out}/manifest.json")):
    for a in test["attachments"]:
        name = a["suggestedHumanReadableName"].split("_")[0]
        os.rename(f"{out}/{a['exportedFileName']}", f"{out}/{name}.png")
os.remove(f"{out}/manifest.json")
PY
  rm -rf "$out.xcresult"
  echo "$out"
done
