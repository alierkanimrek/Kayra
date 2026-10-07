#!/bin/bash
#
# Syslog Notify Script
# Persistent log monitor that watches socklog "errors" directory and sends
# notifications for new error entries at regular intervals.
#
# The socklog "errors" directory already contains only err/crit/alert/emerg
# level messages (filtered by svlogd).
#
# NOTE: Lines in the "current" file already have human-readable ISO 8601
# timestamps at the start (YYYY-MM-DDTHH:MM:SS.ffffff format), not raw tai64n.
# Therefore, tai64nlocal is not needed; these ISO 8601 timestamps compare
# correctly in chronological order via plain string comparison.
#
# Design: check the log file every INTERVAL seconds; collect new lines that
# appeared after the last seen timestamp; send all new entries in a single notification.

set -euo pipefail

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_SYSLOG_NOTIFY

if pgrep -u "$(id -u)" -f "syslog-notify.sh" | grep -qv "^$$\$"; then
    exit 0
fi

LOGFILE="/var/log/socklog/errors/current"

# How often to check the log file (in seconds).
# This period is also the accumulation window for new lines in a single notification.
INTERVAL=3

# Initialize the checkpoint: start from system boot time, so the first scan
# includes any error logs accumulated since boot (even if this script wasn't running).
#
# Log file timestamps are in UTC ISO 8601 format ("YYYY-MM-DDTHH:MM:SS.ffffff ...").
# We generate boot time in the same format and filter using plain string comparison.
BOOT_EPOCH=$(awk '/^btime /{print $2}' /proc/stat 2>/dev/null)

if [ -n "$BOOT_EPOCH" ]; then
    LAST_TS=$(date -u -d "@$BOOT_EPOCH" +'%Y-%m-%dT%H:%M:%S.000000')
else
    # If /proc/stat is unreadable, fall back: only show logs from script startup onwards.
    LAST_TS=$(tail -n1 "$LOGFILE" 2>/dev/null | awk '{print $1}')
fi

while true; do
    sleep "$INTERVAL"

    if [ -n "$LAST_TS" ]; then
        NEW=$(awk -v last="$LAST_TS" '$1 > last' "$LOGFILE")
    else
        NEW=$(cat "$LOGFILE")
    fi

    [ -z "$NEW" ] && continue

    # Update checkpoint for next iteration
    LAST_TS=$(printf '%s\n' "$NEW" | tail -n1 | awk '{print $1}')

    MSG_CONTENT="$NEW"
    COUNT=$(printf '%s\n' "$NEW" | grep -c .)

    if [ "$COUNT" -gt 1 ]; then
        TITLE="$(i18n_template "${MSG[TITLE_MULTIPLE]}" COUNT="$COUNT")"
    else
        TITLE="${MSG[TITLE_SINGLE]}"
    fi

    # Show notification in background: -w waits for user action, but we
    # background it with "&" to prevent blocking the main monitoring loop
    # (so new log entries aren't delayed by user interaction).
    (
        ACTION=$(notify-send -w -u low -a "${MSG[NOTIFY_APP]}" \
            -A "open_log=${MSG[BUTTON_OPEN_LOG]}" \
            "$TITLE" "$MSG_CONTENT")
        if [ "$ACTION" = "open_log" ]; then
            mousepad "$LOGFILE" &
        fi
    ) &
done
