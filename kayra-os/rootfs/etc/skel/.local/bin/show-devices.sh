#!/usr/bin/env bash
#
# show-devices.sh - Lists PCI and USB devices in a fuzzel menu.
#
# Reads the device list produced by list-devices.sh
#   ($HOME/.local/bin/data/devices.json)
# and shows every device in a fuzzel menu. Selecting a device runs
# show-device-mods.sh with that device.
#
# Usage: show-devices.sh
#
export LC_ALL=C.UTF-8
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "$0")")" && pwd)"
DATA_FILE="$HOME/.local/bin/data/devices.json"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/i18n.sh"
declare -n MSG=i18n_SHOW_DEVICES

$HOME/.local/bin/list-devices.sh

# shellcheck source=/dev/null
[ -f "$SCRIPT_DIR/klog.sh" ] && . "$SCRIPT_DIR/klog.sh"
if ! command -v log >/dev/null 2>&1; then
    log() { printf '%s\n' "$*"; }
fi

command -v fuzzel >/dev/null 2>&1 || { echo "${MSG[MSG_NO_FUZZEL]:-fuzzel is not installed}" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "${MSG[MSG_NO_JQ]:-jq is not installed}" >&2; exit 1; }

# Collect the devices if the data file is missing or unreadable
if [ ! -r "$DATA_FILE" ]; then
    [ -x "$SCRIPT_DIR/list-devices.sh" ] && "$SCRIPT_DIR/list-devices.sh" >/dev/null 2>&1
fi

if [ ! -r "$DATA_FILE" ]; then
    log ERROR "Device list not found: $DATA_FILE"
    echo "${MSG[MSG_NO_DATA]:-No device data found}" >&2
    exit 1
fi

# ------------------------------------------------------------------
# Build the menu entries: "<key><TAB><label>" per line
# ------------------------------------------------------------------
entries=$(jq -r '
    def clean: gsub("^\\s+|\\s+$"; "");
    (
      .pci[]?
      | [ "pci:" + .slot,
          ("PCI " + (.slot | sub("^0000:"; "")) + "  " +
           (.vendor | clean) + " " + (.device | clean) + "  [" + (.class_name | clean) + "]")
        ] | @tsv
    ),
    (
      .usb[]?
      | [ "usb:" + .port_path,
          ("USB " + .port_path + "  " +
           (.vendor | clean) + " " + (.product | clean) +
           (if .driver != "" then "  [" + .driver + "]" else "" end))
        ] | @tsv
    )
' "$DATA_FILE")

if [ -z "$entries" ]; then
    log WARN "No devices found in $DATA_FILE"
    echo "${MSG[MSG_NO_DEVICES]:-No devices found}" >&2
    exit 0
fi

declare -a MENU_LINES=()
declare -a MENU_KEYS=()

while IFS=$'\t' read -r key label; do
    [ -n "$key" ] || continue
    MENU_LINES+=("$label")
    MENU_KEYS+=("$key")
done <<< "$entries"

# ------------------------------------------------------------------
# Show the menu
# ------------------------------------------------------------------
pkill -x fuzzel 2>/dev/null || true

SELECTED=$(printf '%s\n' "${MENU_LINES[@]}" | fuzzel --dmenu --log-no-syslog \
    --width 70 --lines 20 --prompt="${MSG[PROMPT_DEVICE]:-Device: }") || true

[ -z "$SELECTED" ] && exit 0

SELECTED_INDEX=-1
for i in "${!MENU_LINES[@]}"; do
    if [ "${MENU_LINES[$i]}" = "$SELECTED" ]; then
        SELECTED_INDEX=$i
        break
    fi
done

[ "$SELECTED_INDEX" -lt 0 ] && exit 0

DEVICE_KEY="${MENU_KEYS[$SELECTED_INDEX]}"

log INFO "Showing modules for device: $DEVICE_KEY"

exec "$SCRIPT_DIR/show-device-mods.sh" "$DEVICE_KEY"
