#!/usr/bin/env bash
#
# cups-menu.sh - Left-click menu for the "custom/cups-monitor" module.
#
# Lists the active CUPS print jobs in a fuzzel menu. When a job is picked, an
# actionable notification (notify_action) asks for confirmation before the job
# is canceled with "cancel". An empty queue closes silently, there is no
# notification for that. A failed cancel is logged and reported with an error
# notification, because that is a real error.
#
# The right-click action of the module does not use this script: it opens the
# CUPS web interface directly (xdg-open http://localhost:631).
#
# Commands used: lpstat, awk, sed, printf, pkill, fuzzel, cancel, log, notify.
#
# Usage: cups-menu.sh   (Waybar "custom/cups-monitor" on-click)

set -uo pipefail
export LC_ALL=C.UTF-8

source "$(dirname "$0")/klog.sh"
source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_CUPS_MENU

# The notifications use the same Material glyph as the module (print).
export NOTIFY_ICON=$(printf '%b' '\U0000E8AD')
source "$(dirname "$0")/notify.sh"

command -v fuzzel >/dev/null 2>&1 || { log ERROR "fuzzel not found" >&2; exit 1; }

# One "job-id  owner  size" line per active job.
mapfile -t LINES < <(lpstat -W not-completed -o 2>/dev/null | awk 'NF { print $1 "  " $2 "  " $3 }')

# An empty queue is not an error: close silently.
if [ "${#LINES[@]}" -eq 0 ] || [ -z "${LINES[0]}" ]; then
    exit 0
fi

MAX_WIDTH=$(printf '%s\n' "${LINES[@]}" | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')

pkill -x fuzzel 2>/dev/null || true
sel=$(printf '%s\n' "${LINES[@]}" | fuzzel --dmenu --anchor=top-right --log-no-syslog \
        --minimal-lines --lines="${#LINES[@]}" --width="$MAX_WIDTH" \
        --prompt="${MSG[MENU_PROMPT]}: ") || exit 0

[ -n "$sel" ] || exit 0

job=$(awk '{print $1}' <<<"$sel")
[[ -n "$job" ]] || exit 0
# The queue name is the job id without its "-<number>" suffix.
printer=$(sed 's/-[0-9]*$//' <<<"$job")

action=$(notify_action "${MSG[CANCEL_TITLE]}" \
    "$(i18n_template "${MSG[CANCEL_CONFIRM]}" JOB="$job" PRINTER="$printer")" \
    "yes=${MSG[CANCEL_YES]}" "no=${MSG[CANCEL_NO]}")

[ "$action" = "yes" ] || exit 0

if ! cancel "$job" >/dev/null 2>&1; then
    log ERROR "Failed to cancel job: $job" >&2
    notify_error "${MSG[CANCEL_FAIL_TITLE]}" \
        "$(i18n_template "${MSG[CANCEL_FAIL]}" JOB="$job" PRINTER="$printer")"
    exit 1
fi

log INFO "Canceled print job: $job" >&2
exit 0
