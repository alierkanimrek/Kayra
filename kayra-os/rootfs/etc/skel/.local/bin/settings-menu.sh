#!/bin/bash
#
# Settings menu helper script for launching system settings.
# Uses settings_menu array from current language file.

set -euo pipefail

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_SETTINGS_MENU

# Check if settings_menu array exists
if [ -z "${settings_menu[*]:-}" ]; then
    echo "$(i18n_template "${MSG[MSG_NO_ITEMS]}")" >&2
    exit 1
fi

# Close any existing fuzzel processes
pkill -x fuzzel 2>/dev/null || true

# Get selection from fuzzel dmenu
SELECTED_KEY=$(printf '%s\n' "${!settings_menu[@]}" | tac | fuzzel --dmenu --log-no-syslog "$@" --prompt="${MSG[PROMPT_ACTION]}")

[ -z "$SELECTED_KEY" ] && exit 0

# Execute the command
COMMAND="$HOME/.local/bin/${settings_menu[$SELECTED_KEY]}"

if [ -n "$COMMAND" ] && [ "$COMMAND" != "null" ]; then
    eval "$COMMAND" &
fi
