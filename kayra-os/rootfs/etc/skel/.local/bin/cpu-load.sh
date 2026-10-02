#!/usr/bin/env bash


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

    # Calculate difference and percentage
    diff_active=$((active2 - active1))
    diff_total=$((total2 - total1))

    if [ "$diff_total" -gt 0 ]; then
        usage=$(( (diff_active * 100) / diff_total ))
    else
        usage=0
    fi

    # Output usage percentage
    echo "$usage"

    # Bir sonraki döngü için son okunan değerleri ilk değer olarak ayarla
    active1=$active2
    total1=$total2
done
