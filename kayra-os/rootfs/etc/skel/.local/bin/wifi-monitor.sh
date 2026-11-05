#!/usr/bin/env bash
#
# Wi-Fi Monitor - Waybar status producer for the "custom/wifi" module.
#
# Commands used:
#   bash, nmcli, ip, awk, jq, sleep, mkdir, rm
#
# Behavior:
#   - No Wi-Fi device: empty output with the "hidden" class.
#   - Wi-Fi device present but not connected: warning icon and "disconnected" class.
#   - Connected: signal-strength icon and "connected" class. The tooltip contains
#     the device name, SSID, IPv4 address, and signal strength.
#
# Monitoring:
#   - "ip monitor link address" triggers an immediate refresh after link or
#     address changes.
#   - A periodic refresh runs every 15 seconds because signal-strength changes
#     do not always produce a link or address event.
#
# Dependencies: nmcli (NetworkManager), jq, iproute2 (ip monitor), awk.

export LC_ALL=C.UTF-8

source "$HOME/.local/bin/single-instance.sh"
single_instance

source "$(dirname "$0")/klog.sh"
source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_WIFI_MONITOR

# Material Symbols codepoints used by the Waybar module.
ICON_WARN=$(printf '%b' '\U0000E1DA')
ICON_L1=$(printf '%b' '\U0000EBE4')
ICON_L2=$(printf '%b' '\U0000EBD6')
ICON_L3=$(printf '%b' '\U0000EBE1')
ICON_L4=$(printf '%b' '\U0000E1D8')

RUN_DIR="${XDG_RUNTIME_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}}/wifi-monitor"
WATCH_FLAG="$RUN_DIR/event"
LAST_STATUS=""
LAST_REFRESH=0

for required_command in nmcli ip awk jq; do
    if ! command -v "$required_command" >/dev/null 2>&1; then
        log ERROR "Required command not found: $required_command" >&2
        exit 1
    fi
done

mkdir -p "$RUN_DIR"
rm -f "$WATCH_FLAG"

get_wifi_iface() {
    nmcli --terse --escape no --fields DEVICE,TYPE device status 2>/dev/null \
        | awk -F: '$2 == "wifi" { print $1; exit }'
}

get_wifi_state() {
    local iface="$1"

    nmcli --terse --escape no --fields DEVICE,STATE device status 2>/dev/null \
        | awk -F: -v iface="$iface" '$1 == iface { print $2; exit }'
}

get_wifi_details() {
    local iface="$1"
    local details
    local -a fields=()

    details=$(nmcli --terse --escape no --fields IN-USE,SSID,SIGNAL \
        device wifi list ifname "$iface" 2>/dev/null \
        | awk -F: '$1 == "*" {
            ssid = $2;
            for (i = 3; i < NF; i++) ssid = ssid ":" $i;
            print ssid;
            print $NF;
            exit
        }')

    [[ -n "$details" ]] && mapfile -t fields <<<"$details"

    WIFI_SSID="${fields[0]:-}"
    WIFI_SIGNAL="${fields[1]:-0}"
}

emit_state() {
    local iface
    local state
    local ip4
    local icon
    local status
    local tooltip

    iface=$(get_wifi_iface)

    if [[ -z "$iface" ]]; then
        status="no-device"
        if [[ "$LAST_STATUS" != "$status" ]]; then
            log INFO "Wi-Fi status changed: no Wi-Fi device" >&2
            LAST_STATUS="$status"
        fi
        jq -nc '{"text":"", "tooltip":"", "class":"hidden"}'
        return
    fi

    state=$(get_wifi_state "$iface")
    if [[ "$state" != "connected" ]]; then
        status="$iface:disconnected"
        if [[ "$LAST_STATUS" != "$status" ]]; then
            log INFO "Wi-Fi status changed: $iface is disconnected" >&2
            LAST_STATUS="$status"
        fi

        jq -nc --arg icon "$ICON_WARN" \
            --arg disconnected "$(i18n_template "${MSG[DEVICE_DISCONNECTED]}" DEVICE="$iface")" \
            '{"text": $icon,
              "tooltip": $disconnected,
              "class": "disconnected"}'
        return
    fi

    get_wifi_details "$iface"
    [[ "$WIFI_SIGNAL" =~ ^[0-9]+$ ]] || WIFI_SIGNAL=0

    ip4=$(nmcli --terse --escape no --fields IP4.ADDRESS device show "$iface" 2>/dev/null \
        | awk -F: '$1 ~ /^IP4\.ADDRESS/ {
            split($2, address, "/");
            print address[1];
            exit
        }')
    [[ -z "$ip4" ]] && ip4="-"
    [[ -z "$WIFI_SSID" ]] && WIFI_SSID="-"

    if   (( WIFI_SIGNAL >= 80 )); then icon="$ICON_L4"
    elif (( WIFI_SIGNAL >= 55 )); then icon="$ICON_L3"
    elif (( WIFI_SIGNAL >= 30 )); then icon="$ICON_L2"
    else                                icon="$ICON_L1"
    fi

    status="$iface:connected"
    if [[ "$LAST_STATUS" != "$status" ]]; then
        log INFO "Wi-Fi status changed: $iface is connected" >&2
        LAST_STATUS="$status"
    fi

    tooltip=$(i18n_template "${MSG[DEVICE_CONNECTED]}" \
        DEVICE="$iface" SSID="$WIFI_SSID" IP="$ip4" SIGNAL="$WIFI_SIGNAL")

    jq -nc --arg icon "$icon" --arg tooltip "$tooltip" \
        '{"text": $icon,
          "tooltip": $tooltip,
          "class": "connected"}'
}

# The monitor output is consumed by awk and used only as an event flag.
ip monitor link address 2>/dev/null \
    | awk -v flag="$WATCH_FLAG" '{ print > flag; close(flag) }' &

log INFO "Wi-Fi monitor started" >&2
emit_state
LAST_REFRESH=$SECONDS

while true; do
    sleep 1

    if [[ -s "$WATCH_FLAG" ]]; then
        rm -f "$WATCH_FLAG"
        emit_state
        LAST_REFRESH=$SECONDS
    elif (( SECONDS - LAST_REFRESH >= 15 )); then
        emit_state
        LAST_REFRESH=$SECONDS
    fi
done
