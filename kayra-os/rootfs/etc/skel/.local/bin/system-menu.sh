#!/usr/bin/env bash
#
# System Settings menu helper script
# Uses system_menu array from current language file

set -euo pipefail

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_SETTINGS_MENU

# Check if system_menu array exists
if [ -z "${system_menu[*]:-}" ]; then
    echo "$(i18n_template "${MSG[MSG_NO_ITEMS]}")" >&2
    exit 1
fi

line_count=$(printf '%s\n' "${!system_menu[@]}" | grep -c "^...*")

# Close any existing fuzzel processes
pkill -x fuzzel 2>/dev/null || true

# Get selection from fuzzel dmenu
SELECTED_KEY=$(printf '%s\n' "${!system_menu[@]}" | tac | fuzzel --dmenu --log-no-syslog --anchor=top-right --lines="$line_count" "$@" --prompt="${MSG[PROMPT_ACTION]}") || true

[ -z "$SELECTED_KEY" ] && exit 0

# Execute the command
CMD_VAL="${system_menu[$SELECTED_KEY]}"
if [[ "$CMD_VAL" == /* ]]; then
    COMMAND="$CMD_VAL"
else
    COMMAND="$HOME/.local/bin/$CMD_VAL"
fi

if [ -n "$COMMAND" ] && [ "$COMMAND" != "null" ]; then
    # eval yerine kelime bölme (menü değeri "betik.sh --arg" biçiminde)
    read -r -a _cmd <<< "$COMMAND"
    "${_cmd[@]}" &
fi
