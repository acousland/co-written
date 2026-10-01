#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app="dist/Co-written.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
work=$(mktemp -d "${TMPDIR:-/tmp}/co-written-dmg.XXXXXX")
trap 'rm -rf "$work"' EXIT
ditto "$app" "$work/Co-written.app"
ln -s /Applications "$work/Applications"
cp docs/Getting-started.txt "$work/Start here.txt"
hdiutil create -volname "Co-written $version" -srcfolder "$work" -ov -format UDZO -imagekey zlib-level=9 "dist/Co-written-$version.dmg"
hdiutil verify "dist/Co-written-$version.dmg"
(cd dist && shasum -a 256 "Co-written-$version.dmg" > "Co-written-$version.dmg.sha256")
