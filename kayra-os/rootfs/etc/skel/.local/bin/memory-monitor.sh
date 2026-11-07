#!/usr/bin/env bash
#
# memory-monitor.sh - Waybar custom module for available-memory monitoring.
#
# Prints Waybar JSON ({text, tooltip}) on stdout. The module stays silent while
# available memory is healthy; once the available-memory ratio drops to or below
# THRESHOLD, an alert icon is shown and the tooltip lists the top 3 processes by
# memory usage.
#
# How it works:
#   * Reads MemTotal/MemAvailable from /proc/meminfo with awk to get the
#     available-memory percentage.
#   * Aggregates per-process RSS with ps + awk and keeps the top 3.
#   * Emits the Waybar JSON with jq.
#   * Runs continuously; single_instance prevents duplicate instances.
#
# Commands used: awk, ps, sort, head, jq, printf, sleep.
#
# Usage: memory-monitor.sh   (invoked by Waybar's custom/memory module)

export LC_ALL=C.UTF-8

source "$HOME/.local/bin/single-instance.sh"
single_instance

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_MEMORY_MONITOR

OUT_TEXT="$(LC_ALL=C.UTF-8 printf '%b' '\U000F7A3')"
THRESHOLD=15

while true; do
    RATIO=$(awk '/^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2} END {printf "%.0f", (a/t)*100}' /proc/meminfo)
    TIP="$(i18n_template "${MSG[MEMORY_AVAILABLE]}" RATIO="$RATIO")"

    if (( RATIO > THRESHOLD )); then
        TEXT=""
    else
        TEXT="$OUT_TEXT"
        TOP="$(ps -eo rss=,args= | awk '
            {
                name = $2
                sub(".*/", "", name)
                mem[name] += $1
            }
            END {
                for (n in mem) printf "%.0f %s\n", mem[n]/1024, n
            }' | sort -rn | head -n 3 | awk '{printf "%s: %s MB\n", $2, $1}')"
        TIP="$TIP"$'\n'"$TOP"
    fi

    jq -c -n --arg text "$TEXT" --arg tip "$TIP" \
        '{text: $text, tooltip: $tip}'

    sleep 3
done
