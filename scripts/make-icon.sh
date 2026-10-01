#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
work=$(mktemp -d "${TMPDIR:-/tmp}/co-written-icon.XXXXXX")
trap 'rm -rf "$work"' EXIT
swift scripts/make-icon.swift "$work/icon.png"
mkdir "$work/CoWritten.iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$work/icon.png" --out "$work/CoWritten.iconset/icon_${size}x${size}.png" >/dev/null
  doubled=$((size * 2))
  sips -z "$doubled" "$doubled" "$work/icon.png" --out "$work/CoWritten.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$work/CoWritten.iconset" -o Assets/CoWritten.icns
