#!/usr/bin/env bash
#
# xbps-lock-monitor.sh - Waybar module for the shared XBPS lock.
#
# Emits one JSON line describing the state of the XBPS lock:
#   * Lock held by the Kayra manager: shows the status text published in
#     XBPS_MSG_FILE (/tmp/kayra-xbps.msg).
#   * Lock held by a command the user started by hand (xbps-install, ...): no
#     status file exists, so it shows the holder's command line read from
#     /proc/<pid>/cmdline.
#   * Lock free: empty text, so waybar hides the module (hide-empty-text).
#
# The lock file /var/db/xbps/lock is the very same file libxbps flocks for its
# transactions, so any xbps command run by the user is visible here too. See
# kayra-xbps-lock.sh for the locking model.
#
# How it works: a dynamic poll. While the lock is free the monitor sleeps
# IDLE_INTERVAL; as soon as an operation holds the lock it switches to
# BUSY_INTERVAL for a snappier reaction. Each tick runs a cheap non-blocking
# flock probe; the heavier reads (lslocks, /proc) happen only while the lock is
# held. JSON is produced with jq and emitted only when the state changed.
#
# Used commands: jq, lslocks, awk, basename, sleep, printf, cat.
#
# Usage: xbps-lock-monitor.sh   (executed by the waybar custom module)

source "$HOME/.local/bin/single-instance.sh"
single_instance

export LC_ALL=C.UTF-8
set -uo pipefail

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_XBPS_MANAGER

source "$(dirname "$0")/kayra-xbps-lock.sh"

ICON=$(printf '%b' '\U000E897')   # Material Symbols lock
IDLE_INTERVAL=2                   # poll period while the lock is free
BUSY_INTERVAL=1                   # poll period while an operation is running

command -v jq >/dev/null || { echo "jq not found" >&2; exit 1; }

# emit <text> <tooltip> <class>
emit() {
    jq -cn --arg text "$1" --arg tooltip "$2" --arg class "$3" \
        '{text: $text, tooltip: $tooltip, class: $class}'
}

# PID of the process currently holding the XBPS lock (empty when free).
lock_holder_pid() {
    lslocks -n -o PID,PATH 2>/dev/null |
        awk -v f="$XBPS_NATIVE_LOCK" '$2 == f { print $1; exit }'
}

# Build "<class>\t<text>\t<tooltip>" for the current state.
current_state() {
    local msg="" pid="" cmd=""
    local -a args=()

    if ! xbps_busy; then
        printf 'absent\t\t'
        return
    fi

    # The manager publishes its status text; prefer it when present.
    if [[ -r "$XBPS_MSG_FILE" ]]; then
        msg=$(<"$XBPS_MSG_FILE")
    fi

    # No status text: a command started by the user holds the lock, show it.
    if [[ -z "$msg" ]]; then
        pid=$(lock_holder_pid)
        if [[ -n "$pid" && -r "/proc/$pid/cmdline" ]]; then
            mapfile -d '' -t args < "/proc/$pid/cmdline"
            cmd="${args[*]}"
        fi
        msg="${cmd:-${MSG[LOCK_MSG]}}"
    fi

    printf 'present\t%s\t%s' "$ICON" "$msg"
}

# Publish the initial state immediately.
last_state=$(current_state)
IFS=$'\t' read -r class text tooltip <<< "$last_state"
emit "$text" "$tooltip" "$class"

# Poll with a dynamic period: faster while the lock is held, slower when idle.
# Emit only when the state changes.
while :; do
    case "$last_state" in
        present*) sleep "$BUSY_INTERVAL" ;;
        *)        sleep "$IDLE_INTERVAL" ;;
    esac

    state=$(current_state)
    [[ "$state" == "$last_state" ]] && continue
    last_state="$state"
    IFS=$'\t' read -r class text tooltip <<< "$state"
    emit "$text" "$tooltip" "$class"
done
