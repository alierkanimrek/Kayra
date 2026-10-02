#!/bin/bash
#
# set-keyboard-layout.sh - Switch keyboard layout and variant
# Usage: set-keyboard-layout.sh <layout-name>
# Example: set-keyboard-layout.sh "Turkish - Turkish (F)"

set -euo pipefail
export LC_ALL=C

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_KEYBOARD_SETTINGS

DATA_FILE="$HOME/.local/bin/data/keyboard-data"
CONFIG_FILE="$HOME/.config/sway/input-keyboard.conf"
LOG_DIR="$HOME/.local/var/log"
LOG_FILE="$LOG_DIR/sway.log"

# Create log directory if needed
mkdir -p "$LOG_DIR" 2>/dev/null || true

# Log function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [set-keyboard-layout] [$level] $message" >> "$LOG_FILE"
}

# Get selection from argument or stdin
SELECTION="${1:-}"

if [ -z "$SELECTION" ]; then
    echo "Error: No layout selection provided" >&2
    log "ERROR" "No layout selection provided"
    exit 1
fi

# Check if data file exists
if [ ! -f "$DATA_FILE" ]; then
    notify-send -u critical "${MSG[NOTIFY_TITLE]}" "${MSG[ERROR_DATA_NOT_FOUND]}"
    log "ERROR" "Data file not found: $DATA_FILE"
    exit 1
fi

# Find the layout and variant from data file
# Escape special regex characters
selection_escaped=$(echo "$SELECTION" | sed 's/[]\/$*.^[]/\\&/g')
layout_variant=$(grep "^${selection_escaped}|" "$DATA_FILE" 2>/dev/null || true)

if [ -z "$layout_variant" ]; then
    notify-send -u critical "${MSG[NOTIFY_TITLE]}" "${MSG[ERROR_SELECTION_NOT_FOUND]}"
    log "ERROR" "Selection not found in data file: $SELECTION"
    exit 1
fi

# Parse layout and variant
layout=$(echo "$layout_variant" | cut -d'|' -f2)
variant=$(echo "$layout_variant" | cut -d'|' -f3)

# Validate config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    notify-send -u critical "${MSG[NOTIFY_TITLE]}" "${MSG[ERROR_CONFIG_NOT_FOUND]}"
    log "ERROR" "Config file not found: $CONFIG_FILE"
    exit 1
fi

# Create new config content
if [ -n "$variant" ]; then
  new_config="### Keyboard Input Configuration
#
# Keyboard input settings including language layout and variant
input type:keyboard {
    xkb_layout \"$layout\"
    xkb_variant \"$variant\"
}"
else
  new_config="### Keyboard Input Configuration
#
# Keyboard input settings including language layout and variant
input type:keyboard {
    xkb_layout \"$layout\"
}"
fi

# Update config file
echo "$new_config" > "$CONFIG_FILE"

log "INFO" "Keyboard layout changed to: layout=$layout variant=$variant"

# Show success message with details
msg_line1="$(i18n_template "${MSG[MSG_CHANGED]}" "LAYOUT=$layout")"
if [ -n "$variant" ]; then
    msg_line2="$(i18n_template "${MSG[MSG_VARIANT]}" "VARIANT=$variant")"
    echo -e "$msg_line1\n$msg_line2"
else
    echo "$msg_line1"
fi

# Reload sway configuration
swaymsg reload 2>/dev/null || log "WARN" "Failed to reload sway (swaymsg not available)"
