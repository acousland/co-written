#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/signing.sh
identity=$(signing_identity)
[[ $identity != - ]] || { echo "Developer ID signing is required" >&2; exit 1; }
app="dist/Co-written.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
work=$(mktemp -d "${TMPDIR:-/tmp}/co-written-notary.XXXXXX")
trap 'rm -rf "$work"' EXIT
case ${1:-} in
  app) ditto -c -k --keepParent "$app" "$work/Co-written.zip"; archive="$work/Co-written.zip" ;;
  dmg) archive="dist/Co-written-$version.dmg"; codesign --force --timestamp --sign "$identity" "$archive" ;;
  *) echo "Usage: scripts/notarize.sh app|dmg" >&2; exit 1 ;;
esac
# Submit once and poll on separate invocations; no long blocking --wait.
xcrun notarytool submit "$archive" --keychain-profile "$notary_profile" --output-format json > "$work/submission.json"
id=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["id"])' "$work/submission.json")
echo "Notarisation submission: $id"
for attempt in $(seq 1 90); do
  xcrun notarytool info "$id" --keychain-profile "$notary_profile" --output-format json > "$work/status.json"
  status=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["status"])' "$work/status.json")
  case $status in
    Accepted) break ;;
    Invalid|Rejected) xcrun notarytool log "$id" --keychain-profile "$notary_profile"; exit 1 ;;
  esac
  sleep 10
done
[[ $status == Accepted ]] || { echo "Notarisation pending: $id. Check with notarytool info." >&2; exit 1; }
if [[ $1 == app ]]; then
  xcrun stapler staple "$app"
  spctl --assess --type execute --verbose "$app"
else
  xcrun stapler staple "$archive"
  spctl --assess --type open --context context:primary-signature --verbose "$archive"
  (cd dist && shasum -a 256 "Co-written-$version.dmg" > "Co-written-$version.dmg.sha256")
fi
