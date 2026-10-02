#!/bin/bash
# home-usage.sh - Calculate $HOME disk usage and send notification.
# Clicking the notification option opens baobab.

set -euo pipefail

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_HOME_USAGE

# Calculate $HOME size (human-readable format)
HOME_SIZE=$(du -sh "$HOME" 2>/dev/null | awk '{print $1}')

# Send notification and wait for action (-w waits, -A adds action)
ACTION=$(notify-send \
    -w \
    -i drive-harddisk \
    -A "open=${MSG[NOTIFY_BUTTON]}" \
    "${MSG[NOTIFY_TITLE]}" \
    "$(i18n_template "${MSG[NOTIFY_MSG]}" HOME="$HOME" USAGE="$HOME_SIZE")")

# If user clicked "Open Baobab", launch it
if [ "$ACTION" = "open" ]; then
    baobab "$HOME" &
    disown
fi
