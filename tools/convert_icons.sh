#!/usr/bin/env bash
set -euo pipefail

# Generate app icons from our calc SVG variants.
# Usage: tools/convert.sh [variant]
#   variant: one of express | cute | badge | glasses | pixel | chip (default: express)

VARIANT="${1:-express}"
SRC_SVG="assets/icons/calc_hex_${VARIANT}.svg"

if [[ ! -f "$SRC_SVG" ]]; then
  echo "Error: source SVG not found: $SRC_SVG" >&2
  echo "Available variants:"
  ls assets/icons/calc_hex_*.svg | sed 's/.*calc_hex_\(.*\)\.svg/ - \1/'
  exit 1
fi

# Pick image conversion tool: prefer ImageMagick `magick`, then `convert`.
convert_cmd() {
  if command -v magick >/dev/null 2>&1; then
    echo "magick"
  elif command -v convert >/dev/null 2>&1; then
    echo "convert"
  else
    echo ""  # none
  fi
}

CONVERT_BIN="$(convert_cmd)"
if [[ -z "$CONVERT_BIN" ]]; then
  echo "Error: ImageMagick not found. Please install 'magick' or 'convert'." >&2
  exit 2
fi

mkdir -p assets/icons web/icons

# Base 1024x1024 PNG for flutter_launcher_icons config
OUT_BASE_PNG="assets/icons/app_icon.png"
"$CONVERT_BIN" convert -background none "$SRC_SVG" -resize 1024x1024 "$OUT_BASE_PNG"
echo "Wrote $OUT_BASE_PNG from $SRC_SVG"

# Web icons (used by PWA manifest)
"$CONVERT_BIN" convert -background none "$SRC_SVG" -resize 512x512  web/icons/Icon-512.png
"$CONVERT_BIN" convert -background none "$SRC_SVG" -resize 192x192  web/icons/Icon-192.png
"$CONVERT_BIN" convert -background none "$SRC_SVG" -resize 512x512  web/icons/Icon-maskable-512.png
"$CONVERT_BIN" convert -background none "$SRC_SVG" -resize 192x192  web/icons/Icon-maskable-192.png
echo "Updated web icons in web/icons/"

echo "Done. To regenerate platform launchers, run:"
echo "  flutter pub run flutter_launcher_icons"
