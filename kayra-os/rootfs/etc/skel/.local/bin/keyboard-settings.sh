#!/usr/bin/env bash
#
# Keyboard Settings - Display available layouts and apply selection
# Gets available layouts from generated menu and allows switching

set -euo pipefail
export LC_CTYPE=en_US.UTF-8

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_KEYBOARD_SETTINGS

MENU_FILE="$HOME/.local/bin/data/fuzzel-keyboard-menu"
DATA_FILE="$HOME/.local/bin/data/keyboard-data"
CONFIG_FILE="$HOME/.config/sway/input-keyboard.conf"

# Check if data files exist
if [ ! -f "$MENU_FILE" ] || [ ! -f "$DATA_FILE" ]; then
    notify-send -u critical "${MSG[NOTIFY_TITLE]}" "${MSG[ERROR_DATA_NOT_FOUND]}"
    exit 1
fi

# Get current keyboard layout and variant from config file
CURRENT_LAYOUT=""
CURRENT_VARIANT=""
CURRENT_NAME=""

if [ -f "$CONFIG_FILE" ]; then
    CURRENT_LAYOUT=$(grep 'xkb_layout' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/' | head -1) || true
    CURRENT_VARIANT=$(grep 'xkb_variant' "$CONFIG_FILE" | sed 's/.*"\([^"]*\)".*/\1/' | head -1) || true
fi

# Build current layout name for display
if [ -n "$CURRENT_LAYOUT" ]; then
    if [ -n "$CURRENT_VARIANT" ]; then
        # Find the full name from data file (with variant)
        CURRENT_NAME=$(grep "^  .* - .*|${CURRENT_LAYOUT}|${CURRENT_VARIANT}$" "$DATA_FILE" | cut -d'|' -f1 | sed 's/^[[:space:]]*//g' || true)
        if [ -z "$CURRENT_NAME" ]; then
            # Fallback: show layout code (Default)
            CURRENT_NAME="${CURRENT_LAYOUT} (Default)"
        fi
    else
        # Find the full name from data file (without variant)
        CURRENT_NAME=$(grep "^${CURRENT_LAYOUT} (Default)|${CURRENT_LAYOUT}|$" "$DATA_FILE" | cut -d'|' -f1 || true)
        if [ -z "$CURRENT_NAME" ]; then
            CURRENT_NAME="${CURRENT_LAYOUT} (Default)"
        fi
    fi
fi

# Close any existing fuzzel processes
pkill -x fuzzel 2>/dev/null || true

# Show fuzzel menu with current layout marked with *
SELECTED=$(
  (if [ -n "$CURRENT_NAME" ]; then
     printf '* %s\n' "$CURRENT_NAME"
   fi
   cut -d'|' -f1 "$MENU_FILE" | grep -v "^#" | { grep -v "^${CURRENT_NAME}$" || true; }) | \
  fuzzel --dmenu --log-no-syslog --anchor=top-right -w 60 "$@" --prompt="${MSG[PROMPT_SELECT]}"
) || exit 0

# Exit if user cancelled
[[ -z "$SELECTED" ]] && exit 0

# Remove the marker if present
SELECTED="${SELECTED#\* }"

# Check if selection is same as current
if [[ "$SELECTED" == "$CURRENT_NAME" ]]; then
    notify-send "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_UNCHANGED]}"
    exit 0
fi

# Apply keyboard layout change
if ~/.local/bin/set-keyboard-layout.sh "$SELECTED" 2>&1; then
    notify-send -i input-keyboard "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_CHANGED]}" "LAYOUT=${SELECTED}")" --urgency=low
else
    notify-send -u critical "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_FAILED]}"
    exit 1
fi
