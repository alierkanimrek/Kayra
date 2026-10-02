#!/bin/sh
#
# Syslog Boot Report Script
# Shows error log entries accumulated since system boot in a single notification.
# Designed to run once at session startup; independent from the persistent syslog-notify.sh.

set -euo pipefail

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_SYSLOG_BOOT_REPORT

LOGFILE="/var/log/socklog/errors/current"
NOTIFY_TIMEOUT=0

# Log file timestamps are in UTC ISO 8601 format ("YYYY-MM-DDTHH:MM:SS.ffffff ...").
# We generate boot time in the same format and filter using plain string comparison.
BOOT_EPOCH=$(awk '/^btime /{print $2}' /proc/stat 2>/dev/null)

if [ -n "$BOOT_EPOCH" ]; then
    BOOT_TS=$(date -u -d "@$BOOT_EPOCH" +'%Y-%m-%dT%H:%M:%S.000000')
    NEW=$(awk -v last="$BOOT_TS" '$1 > last' "$LOGFILE")
else
    # If btime cannot be read, show entire file
    NEW=$(cat "$LOGFILE")
fi

[ -z "$NEW" ] && exit 0

COUNT=$(printf '%s\n' "$NEW" | grep -c .)

if [ "$COUNT" -gt 1 ]; then
    TITLE="$(i18n_template "${MSG[TITLE_MULTIPLE]}" COUNT="$COUNT")"
else
    TITLE="${MSG[TITLE_SINGLE]}"
fi

ACTION=$(notify-send -w -t "$NOTIFY_TIMEOUT" -u normal -a "${MSG[NOTIFY_APP]}" \
    -A "open_log=${MSG[BUTTON_OPEN_LOG]}" \
    "$TITLE" "$NEW")

if [ "$ACTION" = "open_log" ]; then
    mousepad "$LOGFILE" &
fi
