#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
repo=${COWRITTEN_RELEASE_REPO:-acousland/co-written}
app="dist/Co-written.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist")
archives="dist/updates"
mkdir -p "$archives"
# Recover the prior distributions on a fresh checkout so deltas can be generated.
if gh repo view "$repo" >/dev/null 2>&1; then
  gh release list --repo "$repo" --limit 3 --json tagName,isDraft,isPrerelease \
    --jq '.[] | select(.isDraft == false and .isPrerelease == false) | .tagName' > dist/previous-releases.txt
  while IFS= read -r tag; do
    [[ $tag == "v$version" ]] && continue
    gh release download "$tag" --repo "$repo" --pattern 'Co-written-*.dmg' --dir "$archives" --skip-existing
  done < dist/previous-releases.txt
fi
cp "dist/Co-written-$version.dmg" "$archives/"
[[ ! -f appcast.xml ]] || cp appcast.xml "$archives/appcast.xml"
cp RELEASE_NOTES.md "$archives/Co-written-$version.md"
bin=".build/artifacts/sparkle/Sparkle/bin"
[[ $("$bin/generate_keys" --account co-written -p) == $(tr -d '[:space:]' < Assets/update-public-key) ]] \
  || { echo "Sparkle signing key does not match the app's public key" >&2; exit 1; }
"$bin/generate_appcast" --account co-written --versions "$build" --maximum-versions 3 --maximum-deltas 3 \
  --download-url-prefix "https://github.com/$repo/releases/download/v$version/" \
  --embed-release-notes "$archives"
python3 scripts/fix-appcast-urls.py "$archives/appcast.xml" "$repo"
python3 scripts/verify-appcast.py "$archives/appcast.xml" "$version" "$build"
cp "$archives/appcast.xml" dist/appcast.xml
