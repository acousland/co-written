#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
repo=${COWRITTEN_RELEASE_REPO:-acousland/co-written}
version=$(cat VERSION)
tag="v$version"
[[ -z $(git status --porcelain) ]] || { echo "Commit the source before publishing" >&2; exit 1; }
git fetch origin --tags --quiet
[[ $(git rev-parse HEAD) == $(git rev-parse origin/main) ]] || { echo "Push main before publishing" >&2; exit 1; }
! git rev-parse -q --verify "refs/tags/$tag" >/dev/null || { echo "Tag already exists: $tag" >&2; exit 1; }
scripts/prepare-release.sh
git tag -a "$tag" -m "Co-written $version"
git push origin "$tag"
assets=("dist/Co-written-$version.dmg" "dist/Co-written-$version.dmg.sha256")
for delta in dist/updates/*.delta; do [[ ! -f $delta ]] || assets+=("$delta"); done
gh release create "$tag" "${assets[@]}" --repo "$repo" --title "Co-written $version" --notes-file RELEASE_NOTES.md
# Publish the feed after every referenced current-release asset is downloadable.
python3 scripts/check-downloads.py dist/appcast.xml
cp dist/appcast.xml appcast.xml
git add appcast.xml
git commit -m "Publish update feed for $version"
git push origin main
echo "Published https://github.com/$repo/releases/tag/$tag"
