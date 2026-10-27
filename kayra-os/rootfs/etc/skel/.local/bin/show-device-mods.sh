#!/usr/bin/env bash
#
# show-device-mods.sh - Shows the kernel modules of a single device.
#
# The device is selected in show-devices.sh and passed as an argument:
#   pci:<slot>          e.g. pci:0000:00:02.0
#   usb:<port_path>     e.g. usb:2-1
#
# Reads the module data from list-devices.sh
#   ($HOME/.local/bin/data/devices.json)
# and lists:
#   * modules currently in use by the device   (marked with a filled dot)
#   * other modules usable for the device      (marked with an empty dot)
#
# Selecting an unused module runs change-device-module.sh <device> <module>.
#
# Usage: show-device-mods.sh <device-key>
#
export LC_ALL=C.UTF-8
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "$0")")" && pwd)"
DATA_FILE="$HOME/.local/bin/data/devices.json"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/i18n.sh"
declare -n MSG=i18n_SHOW_DEVICE_MODS

# shellcheck source=/dev/null
[ -f "$SCRIPT_DIR/klog.sh" ] && . "$SCRIPT_DIR/klog.sh"
if ! command -v log >/dev/null 2>&1; then
    log() { printf '%s\n' "$*"; }
fi

command -v fuzzel >/dev/null 2>&1 || { echo "${MSG[MSG_NO_FUZZEL]:-fuzzel is not installed}" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "${MSG[MSG_NO_JQ]:-jq is not installed}" >&2; exit 1; }

DEVICE_KEY="${1:-}"
if [ -z "$DEVICE_KEY" ]; then
    echo "${MSG[MSG_USAGE]:-Usage: show-device-mods.sh <device-key>}" >&2
    exit 1
fi

if [ ! -r "$DATA_FILE" ]; then
    [ -x "$SCRIPT_DIR/list-devices.sh" ] && "$SCRIPT_DIR/list-devices.sh" >/dev/null 2>&1
fi

if [ ! -r "$DATA_FILE" ]; then
    log ERROR "Device list not found: $DATA_FILE"
    echo "${MSG[MSG_NO_DATA]:-No device data found}" >&2
    exit 1
fi

# ------------------------------------------------------------------
# Collect modules of the requested device
# ------------------------------------------------------------------
BUS="${DEVICE_KEY%%:*}"
KEY="${DEVICE_KEY#*:}"

case "$BUS" in
    pci)
        DEVICE_JSON=$(jq -c --arg slot "$KEY" '.pci[] | select(.slot == $slot)' "$DATA_FILE")
        ;;
    usb)
        DEVICE_JSON=$(jq -c --arg port "$KEY" '.usb[] | select(.port_path == $port)' "$DATA_FILE")
        ;;
    *)
        echo "${MSG[MSG_BAD_DEVICE]:-Unknown device: } $DEVICE_KEY" >&2
        exit 1
        ;;
esac

if [ -z "$DEVICE_JSON" ] || [ "$DEVICE_JSON" = "null" ]; then
    log WARN "Device not found in device list: $DEVICE_KEY"
    echo "${MSG[MSG_DEVICE_NOT_FOUND]:-Device not found: } $DEVICE_KEY" >&2
    exit 1
fi

# Human readable device title
DEVICE_TITLE=$(printf '%s' "$DEVICE_JSON" | jq -r '
    def clean: gsub("^\\s+|\\s+$"; "");
    if .bus == "pci"
    then ("PCI " + (.slot | sub("^0000:"; "")) + "  " + (.vendor | clean) + " " + (.device | clean))
    else ("USB " + .port_path + "  " + (.vendor | clean) + " " + (.product | clean))
    end
')

# ------------------------------------------------------------------
# Build the menu entries
# ------------------------------------------------------------------
ICON_IN_USE=$(LC_ALL=C.UTF-8 printf '%b' '\U000025CF')     # ● in use
ICON_UNUSED=$(LC_ALL=C.UTF-8 printf '%b' '\U000025CB')     # ○ unused

declare -a MENU_LINES=()
declare -a MENU_MODULES=()
declare -a MENU_STATES=()

# Modules in use by the device
while IFS= read -r mod; do
    [ -n "$mod" ] || continue
    MENU_LINES+=("$ICON_IN_USE $mod")
    MENU_MODULES+=("$mod")
    MENU_STATES+=("in_use")
done < <(printf '%s' "$DEVICE_JSON" | jq -r '.modules_in_use[]?.name')

# Other modules that could be used for this device
while IFS= read -r mod; do
    [ -n "$mod" ] || continue
    MENU_LINES+=("$ICON_UNUSED $mod")
    MENU_MODULES+=("$mod")
    MENU_STATES+=("unused")
done < <(printf '%s' "$DEVICE_JSON" | jq -r '.modules_alternative[]?.name')

if [ "${#MENU_LINES[@]}" -eq 0 ]; then
    log WARN "No modules found for device: $DEVICE_KEY"
    echo "${MSG[MSG_NO_MODULES]:-No modules found for this device}" >&2
    exit 0
fi

# ------------------------------------------------------------------
# Show the menu
# ------------------------------------------------------------------
pkill -x fuzzel 2>/dev/null || true

SELECTED=$(printf '%s\n' "${MENU_LINES[@]}" | fuzzel --dmenu --log-no-syslog --hide-prompt \
    --width 60 --lines 20 --mesg="${MSG[MSG_MESG]:-Modüller}" \
    --prompt="${MSG[PROMPT_MODULE]:-Module: }") || true

[ -z "$SELECTED" ] && exit 0

SELECTED_INDEX=-1
for i in "${!MENU_LINES[@]}"; do
    if [ "${MENU_LINES[$i]}" = "$SELECTED" ]; then
        SELECTED_INDEX=$i
        break
    fi
done

[ "$SELECTED_INDEX" -lt 0 ] && exit 0

MODULE="${MENU_MODULES[$SELECTED_INDEX]}"
STATE="${MENU_STATES[$SELECTED_INDEX]}"

# Modules already in use cannot be changed here
if [ "$STATE" = "in_use" ]; then
    log INFO "Module $MODULE is already in use by $DEVICE_KEY"
    echo "$(i18n_template "${MSG[MSG_ALREADY_IN_USE]}" MODULE="$MODULE")" >&2
    exit 0
fi

log INFO "Selecting module $MODULE for device $DEVICE_KEY"

exec "$SCRIPT_DIR/change-device-module.sh" "$DEVICE_KEY" "$MODULE"
