#!/usr/bin/env bash
#
# degistir_font.sh
#
# Usage: ./degistir_font.sh "new text"
#
# Replaces the old text (stored in ~/.config/.wayfont) with the new text
# (given as a parameter) in the hardcoded list of files below.
# If the replacement succeeds in all files, the new text is saved to
# ~/.config/.wayfont.

set -euo pipefail

# --- Files to modify (add your own file paths here) ---
FILES=(
    "$HOME/.config/waybar/style.css"
    "$HOME/.config/alacritty/alacritty.toml"
    "$HOME/.config/fuzzel/fuzzel.ini"
    "$HOME/.config/swaync/style.css"
)

WAYFONT_FILE="$HOME/.config/.wayfont"

# --- Parameter check ---
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 \"new text\"" >&2
    exit 1
fi

NEW_TEXT="$1"

# --- Check that ~/.config/.wayfont exists ---
if [[ ! -f "$WAYFONT_FILE" ]]; then
    echo "Error: $WAYFONT_FILE not found." >&2
    exit 1
fi

OLD_TEXT=$(<"$WAYFONT_FILE")

if [[ -z "$OLD_TEXT" ]]; then
    echo "Error: no text to replace found in $WAYFONT_FILE." >&2
    exit 1
fi

if [[ "$OLD_TEXT" == "$NEW_TEXT" ]]; then
    echo "Old text and new text are identical, nothing to do."
    exit 0
fi

echo "Old font: $OLD_TEXT"
echo "New font: $NEW_TEXT"

FAILED=0

for file in "${FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "Warning: '$file' not found, skipping." >&2
        continue
    fi

    if ! grep -qF -- "$OLD_TEXT" "$file"; then
        echo "Warning: text '$OLD_TEXT' not found in '$file', skipping."
        continue
    fi

    # Escape special characters for safe sed replacement
    OLD_ESC=$(printf '%s' "$OLD_TEXT" | sed -e 's/[\/&]/\\&/g')
    NEW_ESC=$(printf '%s' "$NEW_TEXT" | sed -e 's/[\/&]/\\&/g')

    if sed -i "s/${OLD_ESC}/${NEW_ESC}/g" "$file"; then
        echo "Updated: $file"
    else
        echo "Error: failed to update '$file'." >&2
        FAILED=1
    fi
done

if [[ "$FAILED" -eq 0 ]]; then
    printf '%s' "$NEW_TEXT" > "$WAYFONT_FILE"
    echo "Success: new text saved to $WAYFONT_FILE."
else
    echo "Some files failed to update, $WAYFONT_FILE was not changed." >&2
    exit 1
fi
