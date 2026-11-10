#!/usr/bin/env bash
#
# memory-monitor.sh - Waybar custom module for available-memory monitoring.
#
# Prints Waybar JSON ({text, tooltip}) on stdout. The module stays silent
# while available memory is healthy; once the available-memory ratio drops to or
# below THRESHOLD, an alert icon is shown, the tooltip lists the top 3 processes
# by memory usage and a warning notification is sent. The notification is sent
# only on the healthy -> alert transition, so it does not repeat every tick.
#
# How it works:
#   * Reads MemTotal/MemAvailable from /proc/meminfo with awk to get the
#     available-memory percentage. On a read/parse failure the ratio falls back
#     to 100 (healthy) to avoid false alerts.
#   * Aggregates per-process RSS with ps + awk and keeps the top 3. Zero-RSS
#     entries (kernel threads) are skipped and the executable path is reduced to
#     its basename, so an app's helper processes are merged under one name.
#   * Emits the Waybar JSON with jq, and only when the output actually changed.
#   * Logs with klog.sh, redirected to stderr: log() also echoes to stdout,
#     which would corrupt the Waybar JSON stream.
#   * Sends the alert with notify.sh on the transition into the alert state.
#   * Runs continuously; single_instance prevents duplicate instances.
#
# Used libraries: single-instance.sh, klog.sh, i18n.sh, notify.sh.
# Commands used: awk, ps, sort, head, jq, printf, sleep.
#
# Usage: memory-monitor.sh   (invoked by Waybar's custom/memory module)

export LC_ALL=C.UTF-8
set -uo pipefail

source "$HOME/.local/bin/single-instance.sh"
single_instance

source "$(dirname "$0")/klog.sh"
source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_MEMORY_MONITOR

# Material Symbols codepoint shown as the alert glyph.
ALERT_ICON=$(printf '%b' '\U000F7A3')   # memory

# Notifications reuse the same Material glyph (notify.sh renders it).
export NOTIFY_ICON="$ALERT_ICON"
source "$(dirname "$0")/notify.sh"

command -v jq >/dev/null 2>&1 || { echo "jq not found" >&2; exit 1; }

THRESHOLD=15        # alert when available memory is <= this percentage
POLL_INTERVAL=3     # seconds between samples

ALERT=0             # previous state: 0 healthy, 1 alert
last_json=""        # last emitted Waybar JSON line

while true; do
    # Available-memory percentage; empty output (MemTotal missing) -> healthy.
    RATIO=$(awk '/^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2} END {if (t>0) printf "%.0f", (a/t)*100}' /proc/meminfo)
    [[ "$RATIO" =~ ^[0-9]+$ ]] || RATIO=100

    TIP=$(i18n_template "${MSG[MEMORY_AVAILABLE]}" RATIO="$RATIO")

    if (( RATIO > THRESHOLD )); then
        TEXT=""
        if (( ALERT == 1 )); then
            log INFO "Available memory is healthy again: ${RATIO}%" >&2
            ALERT=0
        fi
    else
        TEXT="$ALERT_ICON"
        TOP=$(ps -eo rss=,args= | awk '
            $1 == 0 { next }
            {
                name = $2
                sub("^.*/", "", name)
                mem[name] += $1
            }
            END {
                for (n in mem) printf "%.0f %s\n", mem[n]/1024, n
            }' | sort -rn | head -n 3 | awk '{printf "%s: %s MB\n", $2, $1}')
        TIP="$TIP"$'\n'"${MSG[TOP_PROCESSES]}"$'\n'"$TOP"

        if (( ALERT == 0 )); then
            log WARN "Available memory low: ${RATIO}%" >&2
            notify_warn "${MSG[NOTIFY_TITLE]}" \
                "$(i18n_template "${MSG[NOTIFY_LOW_MEMORY]}" RATIO="$RATIO")"
            ALERT=1
        fi
    fi

    json=$(jq -c -n --arg text "$TEXT" --arg tip "$TIP" \
        '{text: $text, tooltip: $tip}')

    if [[ "$json" != "$last_json" ]]; then
        printf '%s\n' "$json"
        last_json="$json"
    fi

    sleep "$POLL_INTERVAL"
done
