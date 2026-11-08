#!/bin/bash
#
# system-menu.sh - Kayra OS system menu.
#
# Launches the different system tools from a fuzzel dmenu: appearance, language,
# keyboard, display, devices, services and the software update check.
#
# The menu labels come from the system_menu array in the language file
# (lang/en.sh, lang/tr.sh). The icons and the commands are hard coded here and
# are matched to the labels by their key (APPEARANCE_THEME, LANGUAGE, ...).
#
# Usage: system-menu.sh [fuzzel parameters...]

set -euo pipefail
export LC_ALL=C.UTF-8

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_SYSTEM_MENU

# Display order of the menu entries
declare -a ORDER=(
    APPEARANCE_THEME
    LANGUAGE
    KEYBOARD
    DISPLAY
    DEVICES
    SERVICES
    SETTINGS
    UPDATES
)

# Material Design Nerd Font icons per menu key
declare -A ICONS=(
    [APPEARANCE_THEME]="E40A"
    [LANGUAGE]="E894"
    [KEYBOARD]="E312"
    [DISPLAY]="E30C"
    [DEVICES]="E1B1"
    [SERVICES]="E726"
    [SETTINGS]="F560"
    [UPDATES]="E923"
)

# Check if system_menu array exists
if [ -z "${system_menu[*]:-}" ]; then
    echo "$(i18n_template "${MSG[MSG_NO_ITEMS]}")" >&2
    exit 1
fi

# Build the icon lines
declare -a LINES=()
for key in "${ORDER[@]}"; do
    if [ -z "${system_menu[$key]:-}" ]; then
        echo "$(i18n_template "${MSG[MSG_NO_ITEMS]}")" >&2
        exit 1
    fi
    LINES+=("$(printf '%b' "\U000${ICONS[$key]}") ${system_menu[$key]}")
done

# Close any existing fuzzel processes
pkill -x fuzzel 2>/dev/null || true

# Window width of the longest menu entry (icon counted as 3 characters)
MAX_WIDTH=$(printf '%s\n' "${LINES[@]}" | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')

# Get selection from fuzzel dmenu
SELECTED=$(printf '%s\n' "${LINES[@]}" | fuzzel --dmenu --anchor=top-right --log-no-syslog --minimal-lines --lines="${#LINES[@]}" --width="$MAX_WIDTH" --hide-prompt "$@") || true

[ -z "$SELECTED" ] && exit 0

# Run the command of the selected text
case "${SELECTED#* }" in
    "${system_menu[APPEARANCE_THEME]}")
        "$HOME/.local/bin/appearance-settings.sh" &
        ;;
    "${system_menu[LANGUAGE]}")
        "$HOME/.local/bin/language-settings.sh" &
        ;;
    "${system_menu[KEYBOARD]}")
        "$HOME/.local/bin/keyboard-settings.sh" &
        ;;
    "${system_menu[DISPLAY]}")
        "$HOME/.local/bin/display-settings.sh" &
        ;;
    "${system_menu[DEVICES]}")
        "$HOME/.local/bin/show-devices.sh" &
        ;;
    "${system_menu[SERVICES]}")
        "$HOME/.local/bin/show-services.sh" &
        ;;
    "${system_menu[SETTINGS]}")
        # Boolean settings submenu (automatic theme / updates).
        "$HOME/.local/bin/settings-menu.sh" &
        ;;
    "${system_menu[UPDATES]}")
        # Hand the manual update request over to the update flow.
        "$HOME/.local/bin/kayra-xbps-update.sh" &
        ;;
esac
