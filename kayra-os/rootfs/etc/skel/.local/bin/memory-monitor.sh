#!/usr/bin/env bash

source $HOME/.local/bin/single-instance.sh
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
