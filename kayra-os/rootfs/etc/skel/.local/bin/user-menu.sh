#!/bin/bash
#
# Fuzzel menu helper script for launching user menu commands.
#
# The menu labels come from the user_menu array in the language file.
# The icons and the commands are hard coded here and are matched to the
# labels by their key (ADD_TO_GROUP, REMOVE_FROM_GROUP, ...).
#
# Usage: user-menu.sh [fuzzel parameters...]

set -euo pipefail
export LC_ALL=C.UTF-8

source "$(dirname "$0")/i18n.sh"

# Display order of the menu entries
declare -a ORDER=(
    ADD_TO_GROUP
    REMOVE_FROM_GROUP
    CHANGE_PASSWORD
    HOME_USAGE
)

# Material Design Nerd Font icons per menu key
declare -A ICONS=(
    [ADD_TO_GROUP]="E7F0"
    [REMOVE_FROM_GROUP]="E7AD"
    [CHANGE_PASSWORD]="E73C"
    [HOME_USAGE]="E88A"
)

# Build the icon lines
declare -a LINES=()
for key in "${ORDER[@]}"; do
    LINES+=("$(printf '%b' "\U000${ICONS[$key]}") ${user_menu[$key]}")
done

# Close any existing fuzzel processes
pkill -x fuzzel 2>/dev/null || true

# Window width of the longest menu entry (icon counted as 3 characters)
MAX_WIDTH=$(printf '%s\n' "${LINES[@]}" | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')

# Get selection from fuzzel dmenu
SELECTED=$(printf '%s\n' "${LINES[@]}" | fuzzel --dmenu --anchor=top-right --log-no-syslog --minimal-lines --width="$MAX_WIDTH" --hide-prompt "$@") || true

[ -z "$SELECTED" ] && exit 0

# Run the command of the selected text
case "${SELECTED#* }" in
    "${user_menu[ADD_TO_GROUP]}")
        "$HOME/.local/bin/group-add.sh"&
        ;;
    "${user_menu[REMOVE_FROM_GROUP]}")
        "$HOME/.local/bin/group-remove.sh"&
        ;;
    "${user_menu[CHANGE_PASSWORD]}")
        "$HOME/.local/bin/change-passwd.sh" &
        ;;
    "${user_menu[HOME_USAGE]}")
        "$HOME/.local/bin/home-usage.sh" &
        ;;
esac
