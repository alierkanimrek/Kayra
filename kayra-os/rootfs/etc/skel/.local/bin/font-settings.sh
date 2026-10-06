#!/usr/bin/env bash
#
# Font Settings - Display available monospace fonts and apply selection
# Uses fuzzel dmenu for font selection
# Integrates with settings.conf and change-font.sh

set -euo pipefail
export LC_CTYPE=en_US.UTF-8

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_FONT_SETTINGS

SETTINGS_FILE="$HOME/.config/kayra/settings.conf"

# Verify settings file exists
if [[ ! -f "$SETTINGS_FILE" ]]; then
    notify-send -u critical "Error" "Settings file not found: $SETTINGS_FILE"
    exit 1
fi

# Get current font from settings
source "$SETTINGS_FILE"
CURRENT_FONT="${font:-Noto Sans Mono}"

# Get list of monospace fonts (by name containing "Mono")
# Use ANSI-C quoting to properly interpret \n as newline
FONT_LIST=$(fc-list -f $'%{family}\n' 2>/dev/null | grep -i mono | sort -u || echo "")

if [[ -z "$FONT_LIST" ]]; then
    notify-send -u critical "Error" "No monospace fonts found"
    exit 1
fi

# Close any existing fuzzel processes
pkill -x fuzzel 2>/dev/null || true

# Show fuzzel menu with current font marked with ✓
SELECTED=$(
  (if [ -n "$CURRENT_FONT" ]; then
     printf '* %s\n' "$CURRENT_FONT"
   fi
   printf '%s\n' "$FONT_LIST" | grep -v "^${CURRENT_FONT}$" 2>/dev/null || true) | \
  fuzzel --dmenu --log-no-syslog --prompt="Select: " --anchor=top-right
) || exit 0

# Exit if user cancelled
[[ -z "$SELECTED" ]] && exit 0

# Remove the marker if present
SELECTED_FONT="${SELECTED#\* }"

# Check if selected font is same as current
if [[ "$SELECTED_FONT" == "$CURRENT_FONT" ]]; then
    notify-send "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_FONT_UNCHANGED]}" FONT="$SELECTED_FONT")"
    exit 0
fi

# Apply font change using change-font.sh
if ~/.local/bin/change-font.sh "$SELECTED_FONT" > /dev/null 2>&1; then
    notify-send "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_FONT_CHANGED]}" FONT="$SELECTED_FONT")"
else
    notify-send -u critical "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_FONT_FAILED]}" FONT="$SELECTED_FONT")"
    exit 1
fi
