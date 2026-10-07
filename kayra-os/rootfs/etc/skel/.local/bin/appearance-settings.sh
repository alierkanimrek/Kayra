#!/usr/bin/env bash
#
# Appearance & Theme Settings menu helper script
# Uses appearance_menu array from current language file

set -euo pipefail

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_SETTINGS_MENU

# Check if appearance_menu array exists
if [ -z "${appearance_menu[*]:-}" ]; then
    echo "$(i18n_template "${MSG[MSG_NO_ITEMS]}")" >&2
    exit 1
fi

line_count=$(printf '%s\n' "${!appearance_menu[@]}" | grep -c "^...*")

# Close any existing fuzzel processes
pkill -x fuzzel 2>/dev/null || true

# Get selection from fuzzel dmenu
SELECTED_KEY=$(printf '%s\n' "${!appearance_menu[@]}" | tac | fuzzel --dmenu --log-no-syslog --anchor=top-right  --lines="$line_count" "$@" --prompt="${MSG[PROMPT_ACTION]}")

[ -z "$SELECTED_KEY" ] && exit 0

# Execute the command
COMMAND="$HOME/.local/bin/${appearance_menu[$SELECTED_KEY]}"

if [ -n "$COMMAND" ] && [ "$COMMAND" != "null" ]; then
    eval "$COMMAND" &
fi
