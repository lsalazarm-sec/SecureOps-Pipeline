#!/bin/bash
# ==============================================================================
# scripts/gif-creator.sh
# Purpose: Bulk convert .webm screencasts from the docs folder to optimized 
# .gif files with 1.75x speed inside docs/Gifs/.
# ==============================================================================

# Fail-fast on errors
set -e

# Define paths relative to the script location
SRC_DIR="$(dirname "$0")/../docs"
DEST_DIR="$(dirname "$0")/../docs/Gifs"

echo "=== 🎬 Starting Bulk Video Conversion (WebM to GIF) ==="

# 1. Ensure destination directory exists
mkdir -p "$DEST_DIR"

# 2. Process each .webm file found in the docs source directory
echo "[+] Scanning source directory: $SRC_DIR"
for f in "$SRC_DIR"/*.webm; do
    # Check if files actually exist to avoid literal wildcard string processing
    [ -e "$f" ] || continue
    
    filename=$(basename "$f" .webm)
    echo "🔄 Converting: $filename.webm -> docs/Gifs/$filename.gif (1.75x speed)"
    
    ffmpeg -y -i "$f" \
        -filter_complex "[0:v]setpts=0.5714*PTS,fps=15,scale=1024:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
        -loop 0 "$DEST_DIR/$filename.gif" </dev/null
    
    echo "   ✅ Done: $filename.gif"
done

echo ""
echo "=== 🎉 All GIFs generated successfully inside docs/Gifs/! ==="