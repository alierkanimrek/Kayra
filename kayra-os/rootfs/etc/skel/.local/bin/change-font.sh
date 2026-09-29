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

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_CHANGE_FONT

# Configuration files to modify (add your own file paths here)
FILES=(
    "$HOME/.config/waybar/style.css"
    "$HOME/.config/alacritty/alacritty.toml"
    "$HOME/.config/fuzzel/fuzzel.ini"
    "$HOME/.config/swaync/style.css"
)

SETTINGS_FILE="$HOME/.config/kayra/settings.conf"

# Parameter check
if [[ $# -ne 1 ]]; then
    echo "$(i18n_template "${MSG[USAGE_ERROR]}" SCRIPT="$0")" >&2
    exit 1
fi

NEW_TEXT="$1"

# Check that settings.conf exists
if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo "$(i18n_template "${MSG[ERROR_FILE_NOT_FOUND]}" FILE="$SETTINGS_FILE")" >&2
    exit 1
fi

# Source settings file and get current font value
source "$SETTINGS_FILE" || {
    echo "$(i18n_template "${MSG[ERROR_FILE_NOT_FOUND]}" FILE="$SETTINGS_FILE")" >&2
    exit 1
}

OLD_TEXT="$font"

if [[ -z "$OLD_TEXT" ]]; then
    echo "$(i18n_template "${MSG[ERROR_NO_TEXT]}" FILE="$SETTINGS_FILE")" >&2
    exit 1
fi

if [[ "$OLD_TEXT" == "$NEW_TEXT" ]]; then
    echo "$(i18n_template "${MSG[MSG_IDENTICAL]}")"
    exit 0
fi

echo "$(i18n_template "${MSG[MSG_OLD_FONT]}" FONT="$OLD_TEXT")"
echo "$(i18n_template "${MSG[MSG_NEW_FONT]}" FONT="$NEW_TEXT")"

FAILED=0

for file in "${FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "$(i18n_template "${MSG[WARNING_FILE_NOT_FOUND]}" FILE="$file")" >&2
        continue
    fi

    if ! grep -qF -- "$OLD_TEXT" "$file"; then
        echo "$(i18n_template "${MSG[WARNING_TEXT_NOT_FOUND]}" TEXT="$OLD_TEXT" FILE="$file")"
        continue
    fi

    # Escape special characters for safe sed replacement
    OLD_ESC=$(printf '%s' "$OLD_TEXT" | sed -e 's/[\/&]/\\&/g')
    NEW_ESC=$(printf '%s' "$NEW_TEXT" | sed -e 's/[\/&]/\\&/g')

    if sed -i "s/${OLD_ESC}/${NEW_ESC}/g" "$file"; then
        echo "Updated: $file"
    else
        echo "$(i18n_template "${MSG[ERROR_UPDATE_FAILED]}" FILE="$file")" >&2
        FAILED=1
    fi
done

if [[ "$FAILED" -eq 0 ]]; then
    # Escape special characters for safe sed replacement
    NEW_ESC=$(printf '%s' "$NEW_TEXT" | sed -e 's/[\/&]/\\&/g')
    sed -i "s/^font=.*/font=\"${NEW_ESC}\"/" "$SETTINGS_FILE"
    echo "$(i18n_template "${MSG[SUCCESS_SAVED]}" FILE="$SETTINGS_FILE")"
else
    echo "$(i18n_template "${MSG[ERROR_PARTIAL_FAILED]}" FILE="$SETTINGS_FILE")" >&2
    exit 1
fi
