#!/usr/bin/env bash
#
# home-usage.sh - Show the disk usage of $HOME in a notification.
#
# The notification has a button that opens the home directory with baobab.
# The button is handled with notify_action from notify.sh.
#
# Dependencies:
#   - libnotify   (for notify-send, xbps-install -S libnotify)
#   - baobab      (optional, xbps-install -S baobab)
#
# Used commands: du, awk, notify-send, baobab
#
set -uo pipefail
export LC_ALL=C.UTF-8

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_HOME_USAGE

source "$(dirname "$0")/klog.sh"
source "$(dirname "$0")/notify.sh"

# Icon shown on the notification (Material Symbols codepoint).
ICON_STORAGE=$(printf '%b' '\U000F3DC')   # storage
NOTIFY_ICON="$ICON_STORAGE"

# Calculate the $HOME size in human readable format.
HOME_SIZE="$(du -sh "$HOME" 2>/dev/null | awk '{print $1}')"

if [[ -z "$HOME_SIZE" ]]; then
    log ERROR "Failed to calculate the disk usage of $HOME"
    notify_error "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[NOTIFY_MSG]}" HOME="$HOME" USAGE="?")"
    exit 1
fi

log INFO "Home directory usage: $HOME_SIZE"

# Send the notification and wait for the button click.
ACTION="$(notify_action "${MSG[NOTIFY_TITLE]}" \
    "$(i18n_template "${MSG[NOTIFY_MSG]}" HOME="$HOME" USAGE="$HOME_SIZE")" \
    "open=${MSG[NOTIFY_BUTTON]}")"

# If the user clicked the "Open Baobab" button, launch it.
if [[ "$ACTION" == "open" ]]; then
    if command -v baobab >/dev/null 2>&1; then
        log INFO "Opening $HOME with baobab"
        baobab "$HOME" &
        disown
    else
        log WARN "baobab is not installed, opening $HOME with xdg-open"
        xdg-open "$HOME" &
        disown
    fi
else
    log INFO "No action selected for the home usage notification"
fi
