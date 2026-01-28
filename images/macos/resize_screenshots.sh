#!/bin/bash
# Script to resize and rename macOS screenshots for App Store Connect
# Required sizes: 1280×800, 1440×900, 2560×1600, or 2880×1800

cd "$(dirname "$0")"

for f in Screenshot*.png; do
    [ -e "$f" ] || continue

    # Remove extended attributes that might cause issues
    xattr -c "$f" 2>/dev/null || true

    # Get base name without extension
    base=$(basename "$f" .png)

    # Resize to 1440x900 (standard macOS resolution)
    sips -z 900 1440 "$f" --out "resized_$f"

    echo "Resized: $f -> resized_$f (1440x900)"
done

echo ""
echo "Now rename the files to something meaningful:"
echo "  resized_Screenshot_1.png -> macos-subtitle-window.png"
echo "  resized_Screenshot_2.png -> macos-translating-content.png"
echo "  etc."
