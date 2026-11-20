#!/usr/bin/env bash
# Archive the app and upload it to App Store Connect, where it shows up
# under TestFlight and can be picked for a release. The version is
# MARKETING_VERSION in project.yml; the build number is the time of the run.
#
# Needs an App Store Connect API key (Users and Access → Integrations) that
# may manage certificates:
#   ASC_KEY_ID      the key's id
#   ASC_ISSUER_ID   the issuer id shown above the keys
#   ASC_KEY_PATH    the .p8 file; default ~/.appstoreconnect/private_keys/AuthKey_<id>.p8
set -euo pipefail
cd "$(dirname "$0")/.."

: "${ASC_KEY_ID:?set ASC_KEY_ID}" "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}"
KEY="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8}"
[[ -f "$KEY" ]] || { echo "No API key at $KEY" >&2; exit 1; }
auth=(-allowProvisioningUpdates -authenticationKeyPath "$KEY"
      -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")

scripts/core.sh
scripts/project.sh

archive=build/Magnetite.xcarchive
rm -rf "$archive"
xcodebuild -project Magnetite.xcodeproj -scheme Magnetite \
  -destination 'generic/platform=iOS' -archivePath "$archive" \
  CURRENT_PROJECT_VERSION="$(date -u +%Y%m%d%H%M)" "${auth[@]}" archive
xcodebuild -exportArchive -archivePath "$archive" \
  -exportOptionsPlist scripts/export-options.plist -exportPath build/export "${auth[@]}"
