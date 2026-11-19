#!/bin/bash
#
# kayra-change-wallpaper.sh - Pick an image and set it as the sway wallpaper.
#
# Runs the gjs image picker; when an image is selected it is copied to a fixed
# path under ~/.local/share/backgrounds and the sway background config is
# updated, then swaybg is started with the new wallpaper.
#
# Usage: kayra-change-wallpaper.sh
#
# Used commands: gjs, cp, mkdir, swaybg
#

SELECTED=$(gjs -m "/usr/local/bin/kayra-image-picker.gjs" 2>/dev/null)

# Nothing (or only warning lines) selected: leave.
[ -z "$SELECTED" ] && exit 0

# Take the full path (trim leading/trailing whitespace)
FILE_PATH=$(echo "$SELECTED" | head -n1 | tr -d '\r\n')

# The selected file must exist
[ -f "$FILE_PATH" ] || exit 1

TARGET_DIR="$HOME/.local/share/backgrounds"
mkdir -p "$TARGET_DIR"

# Copy with a fixed name, keeping the original extension
EXT="${FILE_PATH##*.}"
TARGET_FILE="$TARGET_DIR/kayra_desktop.$EXT"
cp "$FILE_PATH" "$TARGET_FILE"

# Update the sway background configuration
CONFIG="$HOME/.config/sway/background.conf"
if [ -f "$CONFIG" ]; then
    echo "exec_always swaybg -i \"$TARGET_FILE\" -m fill" > "$CONFIG"
    swaybg -i "$TARGET_FILE" -m fill
fi
