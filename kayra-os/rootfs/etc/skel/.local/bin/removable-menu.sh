#!/usr/bin/env bash
# usbmenu: rm=true bölümleri fuzzel'de listeler. ● bağlı, ○ bağlı değil.
# Seçilen bölüm bağlı değilse bağlanır, ardından dosya yöneticisinde açılır.

source "$(dirname "$0")/i18n.sh"
declare -n MSG=I18N_REMOVABLE_MENU

list=$(lsblk -J -o PATH,TYPE,LABEL,FSTYPE,SIZE,RM,MOUNTPOINTS |
    jq -r '.blockdevices[] | recurse(.children[]?)
           | select(.type == "part")
           | select(.rm == true or .rm == 1 or .rm == "1")
           | ([.mountpoints[]? | select(.)] | length > 0) as $m
           | "\(if $m then "●" else "○" end) \(.path)  \(.label // "-")  \(.fstype // "-")  \(.size)"')

if [ -z "$list" ]; then
    notify-send -i drive-removable-media "${MSG[MENU_TITLE]}" "${MSG[NO_PARTITIONS]}"
    exit 0
fi

line_count=$(printf '%s\n' "$list" | grep -c "^...*")

pkill fuzzel 2>/dev/null
sel=$(printf '%s\n' "$list" | fuzzel --dmenu --anchor=top-right --log-no-syslog --width 40  --lines="$line_count" -p "${MSG[MENU_TITLE]}: ") || exit 0
dev=$(awk '{print $2}' <<<"$sel")
[ -n "$dev" ] || exit 0

mp=$(lsblk -no MOUNTPOINTS "$dev" | grep -m1 .)

if [ -z "$mp" ]; then
    if ! udisksctl mount -b "$dev" >/dev/null 2>&1; then
        notify-send -u critical -i dialog-error "${MSG[MOUNT_FAILED]}" "$(i18n_template "${MSG[MOUNT_FAILED_MSG]}" DEVICE="$dev")"
        exit 1
    fi
    mp=$(lsblk -no MOUNTPOINTS "$dev" | grep -m1 .)
fi

[ -n "$mp" ] && xdg-open "$mp"
