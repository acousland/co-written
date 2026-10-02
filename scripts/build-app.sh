#!/bin/bash
set -euo pipefail
project_dir=$(cd "$(dirname "$0")/.." && pwd)
cd "$project_dir"
version=${COWRITTEN_VERSION:-$(cat VERSION)}
build_number=${COWRITTEN_BUILD_NUMBER:-$(date +%s)}
configuration=${COWRITTEN_CONFIGURATION:-release}
feed=${COWRITTEN_FEED_URL:-https://raw.githubusercontent.com/acousland/co-written/main/appcast.xml}
if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ || ! $build_number =~ ^[0-9]+$ ]]; then
  echo "Version must be major.minor.patch and build number must be numeric" >&2; exit 1
fi
source scripts/signing.sh
identity=$(signing_identity)
# Universal distribution: Apple Silicon and Intel, macOS 14+.
swift build -c "$configuration" --arch arm64 --arch x86_64
bin_dir=$(swift build -c "$configuration" --arch arm64 --arch x86_64 --show-bin-path)
app="$project_dir/dist/Co-written.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/Frameworks"
cp "$bin_dir/CoWrittenMac" "$app/Contents/MacOS/CoWrittenMac"
# SwiftPM's universal Xcode path can record the deployment target as the SDK version.
# Preserve macOS 14 compatibility while declaring the actual SDK used to compile the app.
sdk_version=$(xcrun --sdk macosx --show-sdk-version)
xcrun vtool -set-build-version macos 14.0 "$sdk_version" -replace \
  -output "$app/Contents/MacOS/CoWrittenMac" "$app/Contents/MacOS/CoWrittenMac"
ditto "$bin_dir/Sparkle.framework" "$app/Contents/Frameworks/Sparkle.framework"
[[ -f Assets/CoWritten.icns ]] || scripts/make-icon.sh
cp Assets/CoWritten.icns "$app/Contents/Resources/CoWritten.icns"
ditto "$bin_dir/CoWritten_CoWrittenCore.bundle" "$app/Contents/Resources/CoWritten_CoWrittenCore.bundle"
cp ThirdParty/humanizer/LICENSE "$app/Contents/Resources/Humanizer-Licence.txt"
cp LICENSE "$app/Contents/Resources/Co-written-Licence.txt"
cp .build/checkouts/Sparkle/LICENSE "$app/Contents/Resources/Sparkle-Licence.txt"
chmod 644 "$app/Contents/Resources/"*Licence.txt
python3 scripts/write-plist.py "$app/Contents/Info.plist" "$version" "$build_number" "$feed"
chmod 755 "$app/Contents/MacOS/CoWrittenMac"
if [[ $identity == - ]]; then
  codesign --force --deep --entitlements Assets/CoWritten.entitlements --sign - "$app"
  echo "Development build: ad hoc signed" >&2
else
  if [[ $(signing_team "$identity") != $(tr -d '[:space:]' < Assets/signing-team) ]]; then
    echo "Developer ID signing team does not match Assets/signing-team" >&2; exit 1
  fi
  sign=(codesign --force --options runtime --timestamp --sign "$identity")
  sparkle="$app/Contents/Frameworks/Sparkle.framework/Versions/B"
  "${sign[@]}" "$sparkle/XPCServices/Installer.xpc"
  "${sign[@]}" --preserve-metadata=entitlements "$sparkle/XPCServices/Downloader.xpc"
  "${sign[@]}" "$sparkle/Autoupdate"
  "${sign[@]}" "$sparkle/Updater.app"
  "${sign[@]}" "$app/Contents/Frameworks/Sparkle.framework"
  "${sign[@]}" --entitlements Assets/CoWritten.entitlements "$app"
fi
codesign --verify --deep --strict "$app"
lipo -info "$app/Contents/MacOS/CoWrittenMac"
echo "$app"
