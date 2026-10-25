#!/bin/bash
#
# Fuzzel menu helper script for launching user menu commands.
# Uses user_menu array from current language file.

set -euo pipefail

source "$(dirname "$0")/i18n.sh"
# i18n_FUZZEL_MENU diye bir dizi lang dosyalarında tanımlı değil;
# bu betik user_menu dizisini kullandığı için i18n_USER_MENU kullanılmalı.
# (Eski ad tanımlı olmadığından set -euo pipefail altında betik hemen ölürdü.)
declare -n MSG=i18n_USER_MENU

# Check if user_menu array exists
if [ -z "${user_menu[*]:-}" ]; then
    echo "$(i18n_template "${MSG[MSG_NO_ITEMS]}")" >&2
    exit 1
fi

# Close any existing fuzzel processes
pkill -x fuzzel 2>/dev/null || true

# Get selection from fuzzel dmenu
SELECTED_KEY=$(printf '%s\n' "${!user_menu[@]}" | tac | fuzzel --dmenu --log-no-syslog "$@" --prompt="${MSG[PROMPT_ACTION]}") || true

[ -z "$SELECTED_KEY" ] && exit 0

# Execute the command
COMMAND="$HOME/.local/bin/${user_menu[$SELECTED_KEY]}"

if [ -n "$COMMAND" ] && [ "$COMMAND" != "null" ]; then
    # eval yerine kelime bölme (menü değeri "betik.sh --arg" biçiminde)
    read -r -a _cmd <<< "$COMMAND"
    "${_cmd[@]}" &
fi
