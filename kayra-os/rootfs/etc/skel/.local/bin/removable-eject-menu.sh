#!/usr/bin/env bash
#
# removable-eject-menu.sh - Right-click menu for the "custom/removable-monitor".
#
# Lists the removable (rm=true) disks that have at least one mounted partition
# in a fuzzel menu. The chosen disk is unmounted and then powered off
# (ejected) with udisksctl.
#
# Commands used: lsblk, jq, awk, printf, mapfile, pkill, fuzzel, udisksctl,
#   sync, notify-send.
#
# Usage: removable-eject-menu.sh   (Waybar "custom/removable-monitor" on-click-right)

set -uo pipefail
export LC_ALL=C.UTF-8

source "$(dirname "$0")/klog.sh"
source "$(dirname "$0")/i18n.sh"
declare -n MSG=I18N_REMOVABLE_EJECT_MENU

# The notifications use the same Material glyph (notify.sh renders it).
NOTIFY_ICON=$(printf '%b' '\U0000E1DB')      # storage
source "$(dirname "$0")/notify.sh"

mapfile -t LINES < <(lsblk -J -o PATH,TYPE,LABEL,SIZE,RM,MODEL,PKNAME,MOUNTPOINTS |
    jq -r '
        [.blockdevices[] | recurse(.children[]?)] as $all
        | $all[]
        | select(.type == "disk")
        | select(.rm == true or .rm == 1 or .rm == "1")
        | .path as $p
        | ($p | sub("^/dev/"; "")) as $name
        | [$all[] | select(.type == "part" and .pkname == $name)] as $parts
        | select([$parts[], .] | map(.mountpoints[]? | select(.)) | length > 0)
        | ([$parts[] | .label // empty] | join(",")) as $l
        | "\($p)  \((.model // "-") | gsub("^\\s+|\\s+$";""))  \(.size)  \(if $l == "" then "-" else $l end)"')

if [ "${#LINES[@]}" -eq 0 ] || [ -z "${LINES[0]}" ]; then
    notify_info "${MSG[EJECT_TITLE]}" "${MSG[NO_DEVICES]}"
    exit 0
fi

MAX_WIDTH=$(printf '%s\n' "${LINES[@]}" | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')

pkill -x fuzzel 2>/dev/null || true
sel=$(printf '%s\n' "${LINES[@]}" | fuzzel --dmenu --anchor=top-right --log-no-syslog \
        --minimal-lines --lines="${#LINES[@]}" --width="$MAX_WIDTH" \
        --prompt="${MSG[EJECT_TITLE]}: ") || exit 0
disk=$(awk '{print $1}' <<<"$sel")
[ -n "$disk" ] || exit 0

# Unmount every mounted partition of the disk.
failed=()
mapfile -t PARTS < <(lsblk -lnpo PATH,TYPE "$disk" | awk '$2=="part"{print $1}')
part=""
for part in "${PARTS[@]}"; do
    [ -n "$part" ] || continue
    if lsblk -no MOUNTPOINTS "$part" | grep -q .; then
        udisksctl unmount -b "$part" >/dev/null 2>&1 || failed+=("$part")
    fi
done

# A partitionless disk that is mounted directly is unmounted too.
if lsblk -dno MOUNTPOINTS "$disk" | grep -q .; then
    udisksctl unmount -b "$disk" >/dev/null 2>&1 || failed+=("$disk")
fi

if [ "${#failed[@]}" -gt 0 ]; then
    log ERROR "Eject failed: ${failed[*]}" >&2
    notify_error "${MSG[EJECT_FAILED]}" "$(i18n_template "${MSG[EJECT_FAILED_MSG]}" DEVICES="${failed[*]}")"
    exit 1
fi

sync
if udisksctl power-off -b "$disk" >/dev/null 2>&1; then
    log INFO "Ejected $disk" >&2
    notify_ok "${MSG[EJECT_TITLE]}" "$(i18n_template "${MSG[EJECT_SUCCESS]}" DEVICE="$disk")"
else
    notify_warn "${MSG[EJECT_TITLE]}" "$(i18n_template "${MSG[EJECT_PARTIAL]}" DEVICE="$disk")"
fi
