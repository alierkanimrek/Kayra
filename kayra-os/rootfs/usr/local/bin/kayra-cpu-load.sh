#!/usr/bin/env bash
#
# kayra-cpu-load.sh - Print the CPU usage percentage every 5 seconds.
#
# Continuous producer for the Waybar custom module: it prints the average CPU
# load of the last 5 seconds as an integer percentage, once per interval.
#
# Usage: kayra-cpu-load.sh
#
# Used libraries: single-instance.sh.
# Used commands: sleep, read
#
set -uo pipefail
export LC_ALL=C.UTF-8

source /usr/local/lib/kayra/single-instance.sh
single_instance

# Initial CPU stats
read -r _ u1 n1 s1 i1 iow1 irq1 soft1 _ < /proc/stat
active1=$((u1 + n1 + s1 + irq1 + soft1))
total1=$((active1 + i1 + iow1))

while true; do
    sleep 5

    # Read CPU stats after 5 seconds
    read -r _ u2 n2 s2 i2 iow2 irq2 soft2 _ < /proc/stat
    active2=$((u2 + n2 + s2 + irq2 + soft2))
    total2=$((active2 + i2 + iow2))

    # Difference of the active and total jiffies
    diff_active=$((active2 - active1))
    diff_total=$((total2 - total1))

    if [ "$diff_total" -gt 0 ]; then
        usage=$(( (diff_active * 100) / diff_total ))
    else
        usage=0
    fi

    # Output usage percentage
    echo "$usage"

    # Keep the last values for the next interval
    active1=$active2
    total1=$total2
done
