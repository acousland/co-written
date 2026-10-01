#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/signing.sh
identity=$(signing_identity)
[[ $identity != - ]] || { echo "Delta verification needs the release signing identity" >&2; exit 1; }
work=$(mktemp -d "${TMPDIR:-/tmp}/co-written-delta.XXXXXX")
trap 'rm -rf "$work"' EXIT
ditto dist/Co-written.app "$work/old/Co-written.app"
ditto dist/Co-written.app "$work/new/Co-written.app"
printf '%s\n' 'A test resource added in the next version.' > "$work/new/Co-written.app/Contents/Resources/delta-fixture.txt"
codesign --force --options runtime --timestamp --sign "$identity" "$work/new/Co-written.app"
bin=".build/artifacts/sparkle/Sparkle/bin"
"$bin/BinaryDelta" create --version=4 "$work/old/Co-written.app" "$work/new/Co-written.app" "$work/update.delta"
signature=$("$bin/sign_update" --account co-written -p "$work/update.delta")
"$bin/sign_update" --account co-written --verify "$work/update.delta" "$signature"
mkdir "$work/patched"
"$bin/BinaryDelta" apply "$work/old/Co-written.app" "$work/patched/Co-written.app" "$work/update.delta"
codesign --verify --deep --strict "$work/patched/Co-written.app"
cmp "$work/new/Co-written.app/Contents/Resources/delta-fixture.txt" "$work/patched/Co-written.app/Contents/Resources/delta-fixture.txt"
echo "Delta creation, Ed25519 verification, patch application, and app signature verification passed."
