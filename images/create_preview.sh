#!/bin/bash

YOUTUBE_VIDEO="fateh_1.png"
IPHONE_SCREEN="iPhoneScreen3.png"
APP_CONTENT="IMG_2879.PNG"
OUTPUT="app_preview_landscape.png"

WIDTH=2778
HEIGHT=1284

IPHONE_HEIGHT=500
YOUTUBE_HEIGHT=1200  # 50% of 1284

# First composite the app content onto the iPhone screen
magick "$IPHONE_SCREEN" \
  \( "$APP_CONTENT" -resize 1000x \) \
  -gravity center -composite \
  iphone_with_content.png

# Then create the final preview
magick -size ${WIDTH}x${HEIGHT} xc:green \
  \( "$YOUTUBE_VIDEO" -resize ${WIDTH}x${YOUTUBE_HEIGHT}! \) \
  -gravity north -composite \
  \( iphone_with_content.png -resize x${IPHONE_HEIGHT} \) \
  -gravity south -composite \
  "$OUTPUT"

rm iphone_with_content.png

echo "Preview created: $OUTPUT"
