#!/usr/bin/env bash
#
# removable-storage-monitor.sh - Waybar custom module for removable storage.
#
# Watches the removable (rm=true) block devices and prints Waybar JSON
# ({text, tooltip, class}) on stdout. When a new partition is plugged in it
# shows a notification with actions to mount and open it.
#
# How it works:
#   * "lsblk -J" prints the block-device tree; jq flattens it and keeps only
#     the disks/partitions whose rm flag is true, keyed by device path.
#   * "udevadm monitor" (block subsystem) and "findmnt --poll" act as change
#     triggers. They only set a flag file, the main loop re-reads the state on
#     every flag, so a burst of events is debounced.
#   * The new state is compared with the previous snapshot: only real changes
#     are emitted to Waybar and only newly added partitions are notified.
#
# Commands used: lsblk, jq, udevadm, findmnt, awk, printf, mkdir, rm, sleep,
#   udisksctl, xdg-open, notify-send, grep.
#
# Usage: removable-storage-monitor.sh   (invoked by Waybar's custom module)

export LC_ALL=C.UTF-8

source "$HOME/.local/bin/single-instance.sh"
single_instance

source "$(dirname "$0")/klog.sh"
source "$(dirname "$0")/i18n.sh"
declare -n MSG=I18N_REMOVABLE_STORAGE_MONITOR

# Material Symbols codepoints used by the module and its notifications.
ICON_STORAGE=$(printf '%b' '\U0000E1DB')   # storage

# The notifications use the same Material glyph (notify.sh renders it).
export NOTIFY_ICON="$ICON_STORAGE"
source "$(dirname "$0")/notify.sh"

RUN_DIR="${XDG_RUNTIME_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}}/removable-storage-monitor"
WATCH_FLAG="$RUN_DIR/event"

mkdir -p "$RUN_DIR"
rm -f "$WATCH_FLAG"

# Snapshot of every removable disk/partition, keyed by device path.
snap() {
    lsblk -J -o PATH,TYPE,LABEL,FSTYPE,SIZE,RM,MOUNTPOINTS |
    jq -c '[.blockdevices[] | recurse(.children[]?)
            | select(.type == "disk" or .type == "part")
            | select(.rm == true or .rm == 1 or .rm == "1")
            | del(.children) | {(.path): .}] | add // {}'
}

# Print the Waybar JSON for the given snapshot.
emit() {
    jq -c --arg icon "$ICON_STORAGE" \
          --arg tip_empty "${MSG[TOOLTIP_EMPTY]}" \
          --arg tip_present "${MSG[TOOLTIP_PRESENT]}" \
          --arg tip_hint "${MSG[TOOLTIP_RIGHT_CLICK_INFO]}" '
        [.[]] | sort_by(.path) as $d
        | if ($d | length) == 0
          then {text: "", tooltip: $tip_empty, class: "empty"}
          else {
              text: $icon,
              class: "present",
              tooltip: ($tip_present + "\n" + ($d | map(
                  "\(.type)  \(.label // "-")  \(.fstype // "-")  \(.size)  \(
                      [.mountpoints[]? | select(.)] | join(",")
                      | if . == "" then "-" else . end)"
                  ) | join("\n")) + "\n\n" + $tip_hint)
          } end' <<<"$1"
}

# Notify about a single new partition and act on the chosen action.
notify_part() {
    local dev=$1 msg=$2 act mp
    act=$(notify_action "${MSG[NEW_STORAGE]}" "$msg" \
          "open=${MSG[ACTION_OPEN]}" "mount=${MSG[ACTION_MOUNT]}")
    case "$act" in
        open)
            udisksctl mount -b "$dev" >/dev/null 2>&1
            mp=$(lsblk -no MOUNTPOINTS "$dev" | head -n1)
            [ -n "$mp" ] && xdg-open "$mp" ;;
        mount)
            udisksctl mount -b "$dev" >/dev/null 2>&1 ;;
    esac
}

# Compare two snapshots and notify about every newly plugged partition.
notify_new() {
    local -a entries
    local entry
    mapfile -t entries < <(jq -nr --argjson o "$1" --argjson n "$2" '
        $n | to_entries[] | select($o[.key] == null) | .value
        | select(.type == "part")
        | "\(.path)\t\(.label // .path) (\(.fstype // "?"), \(.size))"')
    for entry in "${entries[@]}"; do
        [ -n "$entry" ] || continue
        notify_part "${entry%%$'\t'*}" "${entry#*$'\t'}" &
    done
}

# The trigger file only records that something changed; the state is always
# re-read afterwards.
{ udevadm monitor -u -s block | grep --line-buffered '^UDEV' &
  findmnt --poll -n &
  wait; } > "$WATCH_FLAG" &

prev=$(snap)
emit "$prev"
log INFO "Removable storage monitor started" >&2

while true; do
    sleep 0.5
    if [ -s "$WATCH_FLAG" ]; then
        : > "$WATCH_FLAG"
        udevadm settle
        cur=$(snap)
        if [ "$cur" != "$prev" ]; then
            notify_new "$prev" "$cur"
            emit "$cur"
            prev=$cur
        fi
    fi
done
