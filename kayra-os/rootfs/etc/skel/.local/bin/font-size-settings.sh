#!/usr/bin/env bash
#
# Font Size Settings - Display available font sizes and apply selection
# Integrates with settings.conf and change-font-size.sh

set -euo pipefail
export LC_ALL=C

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_FONT_SETTINGS

SETTINGS_FILE="$HOME/.config/kayra/settings.conf"

# Verify settings file exists
if [[ ! -f "$SETTINGS_FILE" ]]; then
    notify-send -u critical "Error" "Settings file not found: $SETTINGS_FILE"
    exit 1
fi

# Get current font size from settings
source "$SETTINGS_FILE"
CURRENT_SIZE="${font_size:-14}"

# Generate font size list (8-48)
SIZE_LIST=$(seq 8 48)

# Close any existing fuzzel processes
pkill -x fuzzel 2>/dev/null || true

# Show fuzzel menu with current size marked with *
SELECTED=$(
  (printf '* %s\n' "$CURRENT_SIZE"
   printf '%s\n' "$SIZE_LIST" | grep -v "^${CURRENT_SIZE}$" 2>/dev/null || true) | \
  fuzzel --dmenu --log-no-syslog --prompt="Select: " --anchor=top-right
) || exit 0

# Exit if user cancelled
[[ -z "$SELECTED" ]] && exit 0

# Remove the marker if present
SELECTED_SIZE="${SELECTED#\* }"

# Check if selected size is same as current
if [[ "$SELECTED_SIZE" == "$CURRENT_SIZE" ]]; then
    notify-send "${MSG[NOTIFY_TITLE]}" "Font size $SELECTED_SIZE is already selected"
    exit 0
fi

# Apply font size change using change-font-size.sh
if ~/.local/bin/change-font-size.sh "$SELECTED_SIZE" > /dev/null 2>&1; then
    notify-send "${MSG[NOTIFY_TITLE]}" "Font size changed to ${SELECTED_SIZE}px"
else
    notify-send -u critical "${MSG[NOTIFY_TITLE]}" "Failed to change font size to ${SELECTED_SIZE}px"
    exit 1
fi
