#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/signing.sh
[[ $(signing_identity) != - ]] || { echo "Release requires Developer ID signing" >&2; exit 1; }
xcrun notarytool history --keychain-profile "$notary_profile" >/dev/null
swift test
PYTHONPATH=server python3 -m unittest discover -s server/tests
scripts/build-app.sh
dist/Co-written.app/Contents/MacOS/CoWrittenMac --ui-check dist/ui
scripts/check-delta.sh
scripts/notarize.sh app
scripts/build-dmg.sh
scripts/notarize.sh dmg
scripts/prepare-appcast.sh
echo "Signed, notarised DMG and update feed are ready in dist/."
