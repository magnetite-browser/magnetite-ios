#!/usr/bin/env bash
# Record the App Store preview videos into build/previews/<device>.mp4: the
# app on the demo chain, walked through by the UI test while the simulator's
# screen is recorded, then sized as the store asks. Simulators as for
# scripts/screenshots.sh. Needs ffmpeg.
set -euo pipefail
cd "$(dirname "$0")/.."
CORE="${MAGNETITE_MOBILE_CORE:-../magnetite-mobile-core}"
DEVICES=("$@")
[[ $# -gt 0 ]] || DEVICES=("iPhone 17 Pro Max" "iPad Pro 13-inch (M5)")

scripts/project.sh
(cd "$CORE" && exec cargo run --quiet --example demo_server) > /dev/null &
server=$!
test="" recorder=""
# On any end, nothing is left running on the simulator.
trap 'kill $server $test $recorder 2>/dev/null || true' EXIT
until nc -z localhost 8787 2>/dev/null; do
  kill -0 $server 2>/dev/null || { echo "The demo server did not start" >&2; exit 1; }
  sleep 1
done

mkdir -p build/previews
for device in "${DEVICES[@]}"; do
  out="build/previews/$device"
  marks="$(mktemp -d)"
  xcrun simctl bootstatus "$device" -b > /dev/null
  xcrun simctl uninstall "$device" org.magnetitebrowser.ios 2>/dev/null || true
  xcrun simctl status_bar "$device" override --time 9:41 \
    --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4
  TEST_RUNNER_PREVIEW_MARKS="$marks" xcodebuild -project Magnetite.xcodeproj -scheme Magnetite \
    -destination "platform=iOS Simulator,name=$device" \
    -only-testing:MagnetiteUITests/StoreScreenshots/testStorePreview test > "$out.log" 2>&1 &
  test=$!
  # The test says when the page it shows is loaded once; then the
  # recording starts, and the test walks through the app.
  until [[ -e "$marks/ready" ]]; do
    kill -0 $test 2>/dev/null || { echo "The test ended early: $out.log" >&2; exit 1; }
    sleep 0.5
  done
  xcrun simctl io "$device" recordVideo --codec=h264 --force "$out.mov" 2> /dev/null &
  recorder=$!
  sleep 1
  touch "$marks/recording"
  until [[ -e "$marks/done" ]]; do
    kill -0 $test 2>/dev/null || { echo "The test ended early: $out.log" >&2; exit 1; }
    sleep 0.2
  done
  kill -INT $recorder
  wait $recorder || true
  wait $test
  test="" recorder=""
  xcrun simctl status_bar "$device" clear
  rm -rf "$marks" "$out.log"

  # The store's size for the device (6.9" iPhone: 886 × 1920, 13" iPad:
  # 1200 × 1600), 30 frames a second, and a silent sound track, which the
  # store wants.
  case "$device" in
    iPad*) size="scale=1200:1600:flags=lanczos" ;;
    *) size="scale=886:-2:flags=lanczos,crop=886:1920" ;;
  esac
  ffmpeg -loglevel error -y -i "$out.mov" -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 \
    -vf "fps=30,$size,setsar=1" -c:v libx264 -profile:v high -level 4.0 -pix_fmt yuv420p \
    -b:v 10M -c:a aac -b:a 256k -shortest -movflags +faststart "$out.mp4"
  rm "$out.mov"
  # The store takes 15 to 30 seconds.
  length=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$out.mp4")
  awk -v l="$length" 'BEGIN { exit !(l >= 15 && l <= 30) }' ||
    { echo "$out.mp4 is $length s long; the store takes 15 to 30" >&2; exit 1; }
  echo "$out.mp4"
done
