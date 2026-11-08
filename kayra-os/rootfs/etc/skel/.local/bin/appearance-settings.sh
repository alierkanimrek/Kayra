#!/bin/bash
#
# Appearance & Theme Settings menu helper script.
#
# The menu labels come from the appearance_menu array in the language file.
# The icons and the commands are hard coded here and are matched to the
# labels by their key (FONT, FONT_SIZE, ...).
#
# Usage: appearance-settings.sh [fuzzel parameters...]
#
# Used commands: fuzzel, pkill, awk, printf, notify-send (via notify.sh)

set -euo pipefail
export LC_ALL=C.UTF-8

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_APPEARANCE_MENU

source "$(dirname "$0")/klog.sh"
source "$(dirname "$0")/notify.sh"

# Display order of the menu entries
declare -a ORDER=(
    FONT
    FONT_SIZE
    CHANGE_THEME
    WALLPAPER
)

# Material Design Nerd Font icons per menu key
declare -A ICONS=(
    [FONT]="E262"
    [FONT_SIZE]="E245"
    [CHANGE_THEME]="E3B7"
    [WALLPAPER]="E1BC"
)

# Check if appearance_menu array exists
if [ -z "${appearance_menu[*]:-}" ]; then
    echo "$(i18n_template "${MSG[MSG_NO_ITEMS]}")" >&2
    exit 1
fi

# Build the icon lines
declare -a LINES=()
for key in "${ORDER[@]}"; do
    if [ -z "${appearance_menu[$key]:-}" ]; then
        echo "$(i18n_template "${MSG[MSG_NO_ITEMS]}")" >&2
        exit 1
    fi
    LINES+=("$(printf '%b' "\U000${ICONS[$key]}") ${appearance_menu[$key]}")
done

# Close any existing fuzzel processes
pkill -x fuzzel 2>/dev/null || true

# Window width of the longest menu entry (icon counted as 3 characters)
MAX_WIDTH=$(printf '%s\n' "${LINES[@]}" | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')

# Get selection from fuzzel dmenu
SELECTED=$(printf '%s\n' "${LINES[@]}" | fuzzel --dmenu --anchor=top-right --log-no-syslog --minimal-lines --lines="${#LINES[@]}" --width="$MAX_WIDTH" --hide-prompt "$@") || true

[ -z "$SELECTED" ] && exit 0

# Run the command of the selected text
SELECTED_LABEL="${SELECTED#* }"
TARGET_COMMAND=""

case "$SELECTED_LABEL" in
    "${appearance_menu[FONT]}")
        TARGET_COMMAND="$HOME/.local/bin/font-settings.sh"
        ;;
    "${appearance_menu[FONT_SIZE]}")
        TARGET_COMMAND="$HOME/.local/bin/font-size-settings.sh"
        ;;
    "${appearance_menu[CHANGE_THEME]}")
        TARGET_COMMAND="/usr/bin/nwg-look"
        ;;
    "${appearance_menu[WALLPAPER]}")
        TARGET_COMMAND="$HOME/.local/bin/change-wallpaper.sh"
        ;;
esac

[ -z "$TARGET_COMMAND" ] && exit 0

if [ ! -x "$TARGET_COMMAND" ]; then
    log ERROR "Menu command is missing: $TARGET_COMMAND"
    notify_error "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MSG_SCRIPT_MISSING]}" SCRIPT="$TARGET_COMMAND")"
    exit 1
fi

log INFO "Starting menu command: $TARGET_COMMAND"

"$TARGET_COMMAND" &
