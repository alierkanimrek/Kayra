#!/usr/bin/env bash
#
# Change Font Script - Replace font names in configuration files.
#
# Usage: ./change-font.sh "new font name"
#
# Replaces the old font name (stored in ~/.config/kayra/settings.conf) with the new one
# in a hardcoded list of configuration files. If replacement succeeds in all files,
# the new font name is saved to ~/.config/kayra/settings.conf.

set -euo pipefail
export LC_ALL=C

source "$(dirname "$0")/klog.sh"

# Configuration files to modify (add your own file paths here)
FILES=(
    "$HOME/.config/waybar/theme.css"
    "$HOME/.config/alacritty/alacritty.toml"
    "$HOME/.config/fuzzel/fuzzel.ini"
    "$HOME/.config/swaync/style.css"
)

SETTINGS_FILE="$HOME/.config/kayra/settings.conf"

# Parameter check
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 \"new text\"" >&2
    exit 1
fi

NEW_TEXT="$1"

# Check that settings.conf exists
if [[ ! -f "$SETTINGS_FILE" ]]; then
    log "ERROR" "$SETTINGS_FILE not found." 
    exit 1
fi

# Source settings file and get current font value
source "$SETTINGS_FILE" || {
    log "ERROR" "$SETTINGS_FILE not found." 
    exit 1
}

OLD_TEXT="$font"

if [[ -z "$OLD_TEXT" ]]; then
    log "ERROR" "Error: no text to replace found in $SETTINGS_FILE."
    exit 1
fi

if [[ "$OLD_TEXT" == "$NEW_TEXT" ]]; then
    log "INFO" "Old font and new font are identical, nothing to do."
    exit 0
fi

echo "Old font: $OLD_TEXT"
echo "New font: $NEW_TEXT"

FAILED=0

for file in "${FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        log "WARN" " '$file' not found, skipping."
        continue
    fi

    if ! grep -qF -- "$OLD_TEXT" "$file"; then
        log "INFO" "Font '$OLD_TEXT' not found in '$file', skipping."
        continue
    fi

    # Escape special characters for safe sed replacement
    OLD_ESC=$(printf '%s' "$OLD_TEXT" | sed -e 's/[\/&]/\\&/g')
    NEW_ESC=$(printf '%s' "$NEW_TEXT" | sed -e 's/[\/&]/\\&/g')

    if sed -i "s/${OLD_ESC}/${NEW_ESC}/g" "$file"; then
        log "DEBUG" "Updated: $file"
    else
        log "ERROR" "Failed to update '$file'."
        FAILED=1
    fi
done

if [[ "$FAILED" -eq 0 ]]; then
    # Escape special characters for safe sed replacement
    NEW_ESC=$(printf '%s' "$NEW_TEXT" | sed -e 's/[\/&]/\\&/g')
    sed -i "s/^font=.*/font=\"${NEW_ESC}\"/" "$SETTINGS_FILE"
    log "INFO" "$NEW_TEXT font succesfuly applied."
else
    log "ERROR" "Some files failed to update, $SETTINGS_FILE was not changed."
    exit 1
fi
