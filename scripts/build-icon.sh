#!/usr/bin/env bash
set -euo pipefail

# Generates AppIcon.icns from macos/icon.svg
# Usage: ./scripts/build-icon.sh [output-dir]
#   output-dir defaults to dist/

OUTPUT_DIR="${1:-dist}"
ICONSET_TMP=$(mktemp -d)
ICONSET="$ICONSET_TMP/AppIcon.iconset"

cleanup() { rm -rf "$ICONSET_TMP"; }
trap cleanup EXIT

if ! command -v rsvg-convert &>/dev/null; then
    echo "Error: rsvg-convert not found. Install it with: brew install librsvg" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
mkdir "$ICONSET"

echo "→ Rendering icon sizes from macos/icon.svg..."
for size in 16 32 128 256 512; do
    rsvg-convert -w "$size" -h "$size" macos/icon.svg \
        > "$ICONSET/icon_${size}x${size}.png"
    double=$((size * 2))
    rsvg-convert -w "$double" -h "$double" macos/icon.svg \
        > "$ICONSET/icon_${size}x${size}@2x.png"
done

echo "→ Running iconutil..."
iconutil -c icns "$ICONSET" -o "$OUTPUT_DIR/AppIcon.icns"

echo "✓ $OUTPUT_DIR/AppIcon.icns ready."
