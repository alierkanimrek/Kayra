#!/usr/bin/env bash
#
# kayra-xbps-updates-monitor.sh - Waybar module: available package updates.
#
# Shows an icon (without a number) when updates are available; the count is in
# the tooltip. The module is hidden when there is nothing to update.
#
# How it works:
#   * Reads the auto_update setting (~/.config/kayra/settings.conf through
#     settings-conf.sh). When it is not "true" the monitor stays asleep: it does
#     not check anything and keeps the module hidden. It wakes as soon as the
#     settings file changes (conf_wait_change) or after CHECK_PERIOD seconds,
#     whichever comes first.
#   * As soon as auto_update is true it runs a fresh check immediately (on
#     startup, whenever the setting turns true and whenever an xbps transaction
#     ends), then every INTERVAL.
#   * The check comes from kayra-xbps-updates.sh: a fresh in-memory repository
#     sync with "xbps-install -un -M" (no root, no write to /var/db/xbps, run
#     under nice). On a failed check (offline) the last known state is kept and
#     the check is retried after RETRY seconds.
#   * JSON is emitted only when the state changes.
#
# Used commands: jq, xbps-install, xbps-checkvers, awk, nice, date, sleep,
#                grep, printf.
#
# Usage: kayra-xbps-updates-monitor.sh   (executed by the waybar custom module)

source "$HOME/.local/bin/single-instance.sh"
single_instance

export LC_ALL=C.UTF-8
set -uo pipefail

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_XBPS_MANAGER

source "$(dirname "$0")/settings-conf.sh"
source "$(dirname "$0")/kayra-xbps-updates.sh"
source "$(dirname "$0")/kayra-xbps-lock.sh"   # for xbps_busy (lock state)

ICON=$(printf '%b' '\U000E923')   # Material Icons "update"
INTERVAL=21600                    # 6 hours between checks
RETRY=300                         # 5 minutes before retrying a failed check
CHECK_PERIOD=5                    # seconds between auto_update lookups while idle

command -v jq >/dev/null || { echo "jq not found" >&2; exit 1; }

# emit <text> <tooltip> <class>
emit() {
    jq -cn --arg text "$1" --arg tooltip "$2" --arg class "$3" \
        '{text: $text, tooltip: $tooltip, class: $class}'
}

# True when the auto_update setting is enabled.
auto_update_enabled() {
    [[ "$(conf_get auto_update | head -n1)" == "true" ]]
}

# Last emitted update count ("" means nothing was shown yet).
last_count=""

# Run a fresh check and emit the new state when it changed. Keeps the previous
# state on failure (returns non-zero).
check_and_emit() {
    local out count
    out=$(xbps_updatable_pkgs) || return 1
    count=$(printf '%s\n' "$out" | grep -c .)

    [[ "$count" == "$last_count" ]] && return 0
    last_count="$count"

    if [[ "$count" -gt 0 ]]; then
        emit "$ICON" "$(i18n_template "${MSG[UPDATES_TITLE]}" COUNT="$count")" "updates"
    else
        emit "" "" "none"
    fi
}

# Hide the module (used while auto_update is off).
hide() {
    [[ -z "$last_count" ]] && return 0
    last_count=""
    emit "" "" "none"
}

# ---- main ------------------------------------------------------------------

enabled_prev=""
next_check=0
was_busy=0

if auto_update_enabled; then
    enabled_prev=true
    if check_and_emit; then
        next_check=$(( $(date +%s) + INTERVAL ))
    else
        next_check=$(( $(date +%s) + RETRY ))
    fi
else
    enabled_prev=false
    emit "" "" "none"
fi

while :; do
    # Wake immediately when settings.conf changes, otherwise after
    # CHECK_PERIOD seconds.
    conf_wait_change "$CHECK_PERIOD" || true

    # Re-check as soon as an xbps transaction ends (ours or one started by the
    # user): while the shared lock is held something is being installed or
    # removed, and the update list is stale right after it finishes.
    if xbps_busy; then
        was_busy=1
    elif [[ "$was_busy" -eq 1 ]]; then
        was_busy=0
        next_check=0
    fi

    if auto_update_enabled; then
        now=$(date +%s)
        # Check immediately when the setting just became true, or when due.
        if [[ "$enabled_prev" != "true" || "$now" -ge "$next_check" ]]; then
            if check_and_emit; then
                next_check=$(( now + INTERVAL ))
            else
                next_check=$(( now + RETRY ))
            fi
        fi
        enabled_prev=true
    else
        [[ "$enabled_prev" != "false" ]] && hide
        enabled_prev=false
        next_check=0
    fi
done
