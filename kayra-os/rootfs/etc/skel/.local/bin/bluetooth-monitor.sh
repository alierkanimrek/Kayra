#!/usr/bin/env bash
#
# Bluetooth Monitor - Waybar status producer for the "custom/bluetooth" module.
#
# Commands used:
#   bash, bluetoothctl, rfkill, awk, sed, jq, sleep, mkdir, rm, timeout
#
# Behavior (kept intentionally simple):
#   - No Bluetooth adapter: empty output with the "hidden" class.
#   - Adapter present but off (rfkill soft-blocked or Powered: no): the
#     "off" class with the bluetooth_disabled icon.
#   - Adapter on, no connected device: the "disconnected" class with the
#     plain bluetooth icon.
#   - Adapter on, one or more devices connected: the "connected" class with
#     the bluetooth_connected icon. The tooltip lists the connected device
#     names. The icon never shows a count.
#
# Monitoring:
#   - "bluetoothctl --monitor" prints change events ([CHG]/[NEW]/[DEL]) on
#     its stdout while it stays in interactive mode. A background pipeline
#     (kept alive by "sleep infinity" on its stdin) writes each event to a
#     flag file. The main loop reacts to the flag at once.
#   - A periodic refresh (15 s) acts as a safety net, because a connection
#     state change does not always produce a monitor line.
#
# Dependencies: bluez (bluetoothctl), rfkill, jq, awk, sed, coreutils.

export LC_ALL=C.UTF-8

source "$HOME/.local/bin/single-instance.sh"
single_instance

source "$(dirname "$0")/klog.sh"
source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_BLUETOOTH_MONITOR

# Material Symbols codepoints used by the Waybar module.
ICON_ON=$(printf '%b' '\U0000E1A7')          # bluetooth
ICON_CONNECTED=$(printf '%b' '\U0000E1A8')   # bluetooth_connected
ICON_OFF=$(printf '%b' '\U0000E1A9')         # bluetooth_disabled

RUN_DIR="${XDG_RUNTIME_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}}/bluetooth-monitor"
WATCH_FLAG="$RUN_DIR/event"
LAST_STATUS=""
LAST_REFRESH=0

for required_command in bluetoothctl rfkill awk sed jq; do
    if ! command -v "$required_command" >/dev/null 2>&1; then
        log ERROR "Required command not found: $required_command" >&2
        exit 1
    fi
done

mkdir -p "$RUN_DIR"
rm -f "$WATCH_FLAG"

# Prints "yes" when at least one Bluetooth device is soft-blocked by rfkill.
is_rfkill_blocked() {
    timeout 3 rfkill list bluetooth 2>/dev/null \
        | awk '/Soft blocked/ { if ($NF == "yes") found = 1 } END { print found ? "yes" : "no" }'
}

# Reads the adapter address and the Powered property. Prints "MAC|yes|no".
get_adapter() {
    local out
    out=$(timeout 3 bluetoothctl show 2>/dev/null)

    if [[ -z "$out" || "$out" == *"No default controller available"* ]]; then
        return 1
    fi

    local mac powered
    mac=$(printf '%s\n' "$out" | awk '/^Controller/ { print $2; exit }')
    powered=$(printf '%s\n' "$out" | awk -F': ' '/Powered:/ { print $2; exit }')

    printf '%s|%s\n' "${mac:-}" "${powered:-no}"
}

# Prints the names of all currently connected devices, one per line.
get_connected_names() {
    timeout 3 bluetoothctl devices Connected 2>/dev/null \
        | sed -E 's/^Device [0-9A-Fa-f:]+ //'
}

emit_state() {
    local adapter_line adapter mac powered status

    adapter_line=$(get_adapter)

    if [[ -z "$adapter_line" ]]; then
        status="no-adapter"
        if [[ "$LAST_STATUS" != "$status" ]]; then
            log INFO "Bluetooth status changed: no adapter" >&2
            LAST_STATUS="$status"
        fi
        jq -nc '{"text":"", "tooltip":"", "class":"hidden"}'
        return
    fi

    mac="${adapter_line%%|*}"
    powered="${adapter_line#*|}"

    if [[ "$powered" != "yes" ]] || [[ "$(is_rfkill_blocked)" == "yes" ]]; then
        status="off"
        if [[ "$LAST_STATUS" != "$status" ]]; then
            log INFO "Bluetooth status changed: adapter off" >&2
            LAST_STATUS="$status"
        fi
        jq -nc --arg icon "$ICON_OFF" \
            --arg tooltip "$(i18n_template "${MSG[ADAPTER_OFF]}")" \
            '{"text": $icon, "tooltip": $tooltip, "class": "off"}'
        return
    fi

    local connected
    connected=$(get_connected_names)

    if [[ -z "${connected//[$'\n']/}" ]]; then
        status="disconnected"
        if [[ "$LAST_STATUS" != "$status" ]]; then
            log INFO "Bluetooth status changed: no connected device" >&2
            LAST_STATUS="$status"
        fi
        jq -nc --arg icon "$ICON_ON" \
            --arg tooltip "$(i18n_template "${MSG[DISCONNECTED]}")" \
            '{"text": $icon, "tooltip": $tooltip, "class": "disconnected"}'
        return
    fi

    status="connected"
    if [[ "$LAST_STATUS" != "$status" ]]; then
        log INFO "Bluetooth status changed: device(s) connected" >&2
        LAST_STATUS="$status"
    fi

    jq -nc --arg icon "$ICON_CONNECTED" \
        --arg tooltip "$(i18n_template "${MSG[CONNECTED]}" DEVICES="$connected")" \
        '{"text": $icon, "tooltip": $tooltip, "class": "connected"}'
}

# Background event source. "sleep infinity" keeps bluetoothctl in interactive
# mode so that it keeps printing change events; the flag file only records
# that something changed. Only connection and power changes are kept, because
# the monitor also repeats unrelated Controller properties (for example the
# UUID list) which would trigger a refresh on every line.
sleep infinity | bluetoothctl --monitor 2>/dev/null \
    | grep --line-buffered -E 'Connected:|Powered:' > "$WATCH_FLAG" &

log INFO "Bluetooth monitor started" >&2
emit_state
LAST_REFRESH=$SECONDS

while true; do
    sleep 1

    if [[ -s "$WATCH_FLAG" ]]; then
        : > "$WATCH_FLAG"
        emit_state
        LAST_REFRESH=$SECONDS
    elif (( SECONDS - LAST_REFRESH >= 15 )); then
        emit_state
        LAST_REFRESH=$SECONDS
    fi
done
