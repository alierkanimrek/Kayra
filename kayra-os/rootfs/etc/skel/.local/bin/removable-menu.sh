#!/usr/bin/env bash
#
# removable-menu.sh - Left-click menu for the "custom/removable-monitor" module.
#
# Lists the removable (rm=true) partitions in a fuzzel menu. A filled marker
# means the partition is mounted, an empty marker means it is not. The chosen
# partition is mounted when needed and then opened in the file manager.
#
# Commands used: lsblk, jq, awk, printf, pkill, fuzzel, udisksctl, xdg-open,
#   notify-send.
#
# Usage: removable-menu.sh   (Waybar "custom/removable-monitor" on-click)

set -uo pipefail
export LC_ALL=C.UTF-8

source "$(dirname "$0")/klog.sh"
source "$(dirname "$0")/i18n.sh"
declare -n MSG=I18N_REMOVABLE_MENU

# Material Symbols codepoints for the mount-state markers.
ICON_MOUNTED=$(printf '%b' '\U0000E837')     # radio_button_checked
ICON_UNMOUNTED=$(printf '%b' '\U0000E836')   # radio_button_unchecked

# The notifications use the same Material glyph (notify.sh renders it).
NOTIFY_ICON=$(printf '%b' '\U0000E1DB')      # storage
source "$(dirname "$0")/notify.sh"

mapfile -t LINES < <(lsblk -J -o PATH,TYPE,LABEL,FSTYPE,SIZE,RM,MOUNTPOINTS |
    jq -r --arg on "$ICON_MOUNTED" --arg off "$ICON_UNMOUNTED" '
        .blockdevices[] | recurse(.children[]?)
        | select(.type == "part")
        | select(.rm == true or .rm == 1 or .rm == "1")
        | ([.mountpoints[]? | select(.)] | length > 0) as $m
        | "\(if $m then $on else $off end) \(.path)  \(.label // "-")  \(.fstype // "-")  \(.size)"')

if [ "${#LINES[@]}" -eq 0 ] || [ -z "${LINES[0]}" ]; then
    notify_info "${MSG[MENU_TITLE]}" "${MSG[NO_PARTITIONS]}"
    exit 0
fi

MAX_WIDTH=$(printf '%s\n' "${LINES[@]}" | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')

pkill -x fuzzel 2>/dev/null || true
sel=$(printf '%s\n' "${LINES[@]}" | fuzzel --dmenu --anchor=top-right --log-no-syslog \
        --minimal-lines --lines="${#LINES[@]}" --width="$MAX_WIDTH" \
        --prompt="${MSG[MENU_TITLE]}: ") || exit 0
dev=$(awk '{print $2}' <<<"$sel")
[ -n "$dev" ] || exit 0

mp=$(lsblk -no MOUNTPOINTS "$dev" | grep -m1 .)

if [ -z "$mp" ]; then
    if ! udisksctl mount -b "$dev" >/dev/null 2>&1; then
        log ERROR "Mount failed: $dev" >&2
        notify_error "${MSG[MOUNT_FAILED]}" "$(i18n_template "${MSG[MOUNT_FAILED_MSG]}" DEVICE="$dev")"
        exit 1
    fi
    mp=$(lsblk -no MOUNTPOINTS "$dev" | grep -m1 .)
fi

[ -n "$mp" ] && xdg-open "$mp"
