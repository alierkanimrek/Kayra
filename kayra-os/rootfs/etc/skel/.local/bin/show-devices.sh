#!/usr/bin/env bash
#
# show-devices.sh - Lists PCI and USB devices in a fuzzel menu.
#
# Reads the device list produced by list-devices.sh
#   ($HOME/.local/bin/data/devices.json)
# and shows every device in a fuzzel menu. Selecting a device runs
# show-device-mods.sh with that device.
#
# The window width is computed from the longest entry, and the font size is
# taken from the global font_size (settings.conf, via settings-conf.sh) minus
# 2 px so the long PCI/USB labels stay compact. The size is never pushed below
# the project minimum (FONT_MIN=8): at/under the minimum it is left unchanged.
#
# Usage: show-devices.sh
#
# Used commands: jq, awk, printf, fuzzel, pkill, list-devices.sh,
#                settings-conf.sh (conf_get), i18n.sh, klog.sh
#
export LC_ALL=C.UTF-8
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "$0")")" && pwd)"
DATA_FILE="$HOME/.local/bin/data/devices.json"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/i18n.sh"
declare -n MSG=i18n_SHOW_DEVICES

# shellcheck source=/dev/null
source "$SCRIPT_DIR/settings-conf.sh"

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
# Menu font size: two pixels smaller than the global font_size (read from
# settings.conf via settings-conf.sh), keeping the same font family. Never go
# below the project minimum (FONT_MIN): at/under the minimum keep it unchanged.
FONT_MIN=8
FONT_ARGS=()
GLOBAL_FONT_SIZE=$(conf_get font_size)
MENU_FONT_FAMILY=$(conf_get font)
if [[ "$GLOBAL_FONT_SIZE" =~ ^[0-9]+$ ]]; then
    MENU_FONT_SIZE=$(( GLOBAL_FONT_SIZE - 2 ))
    (( MENU_FONT_SIZE < FONT_MIN )) && MENU_FONT_SIZE="$GLOBAL_FONT_SIZE"
    FONT_ARGS=(--font="${MENU_FONT_FAMILY:-monospace}:pixelsize=${MENU_FONT_SIZE}")
fi

# Window width of the longest menu entry, using the shared project formula.
# The device labels carry no icon, but the formula is kept unchanged: the
# extra slack (-1 + 3) stops fuzzel from clipping the longest label.
MAX_WIDTH=$(printf '%s\n' "${MENU_LINES[@]}" | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')

# Close any open fuzzel windows
pkill -x fuzzel 2>/dev/null || true

SELECTED=$(printf '%s\n' "${MENU_LINES[@]}" | fuzzel --dmenu --log-no-syslog \
    --minimal-lines --lines="${#MENU_LINES[@]}" --width="$MAX_WIDTH" \
    ${FONT_ARGS[@]+"${FONT_ARGS[@]}"} \
    --prompt="${MSG[PROMPT_DEVICE]:-Device: }") || true

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
