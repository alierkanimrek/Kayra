#!/usr/bin/env bash
#
# Wi-Fi Monitor Script - Waybar status producer for "custom/wifi" module.
#
# Behavior:
#   - No Wi-Fi device -> empty/hidden output (exec-if already hides the module at startup;
#     this script provides consistent behavior for hotplug events).
#   - Wi-Fi device present but not connected -> warning icon + "disconnected" class.
#   - Connected -> 4-level signal strength icon + "connected" class,
#     with device name, SSID, IP address, and signal strength in tooltip.
#
# Monitoring:
#   `ip monitor link addr` captures interface/address changes instantly
#   (connection up/down, IP assignment etc.). Since signal strength changes
#   don't always trigger these events, we also do periodic refresh every 15 seconds.
#
# Dependencies: nmcli (NetworkManager), jq, iproute2 (ip monitor).

#set -uo pipefail
trap 'exit 0' PIPE SIGTERM

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_WIFI_MONITOR

# nmcli locale: Prevent localized (Turkish etc.) keywords in output;
# fixed-text comparisons (STATE, SECURITY, "--" etc.) rely on this.

ICON_WARN=$(printf '%b' '\U0000E1DA')
ICON_L1=$(printf '%b' '\U0000EBE4')
ICON_L2=$(printf '%b' '\U0000EBD6')
ICON_L3=$(printf '%b' '\U0000EBE1')
ICON_L4=$(printf '%b' '\U0000E1D8')

get_wifi_iface() {
    LC_ALL=C nmcli -t -f DEVICE,TYPE device status 2>/dev/null \
        | awk -F: '$2=="wifi"{print $1; exit}'
}

emit() {
    local iface="$1"

    if [[ -z "$iface" ]]; then
        # No Wi-Fi device -> hide module (empty text, no whitespace)
        jq -nc '{"text":"", "tooltip":"", "class":"hidden"}'
        return
    fi

    local state
    state=$(LC_ALL=C nmcli -t -f DEVICE,STATE device status 2>/dev/null \
        | awk -F: -v i="$iface" '$1==i{print $2}')

    if [[ "$state" != "connected" ]]; then
        jq -nc --arg icon "$ICON_WARN" --arg dev "$iface" \
            --arg disconnected "$(i18n_template "${MSG[DEVICE_DISCONNECTED]}" DEVICE="$dev")" \
            '{"text": $icon,
              "tooltip": $disconnected,
              "class": "disconnected"}'
        return
    fi

    local line ssid signal ip4
    line=$(LC_ALL=C nmcli -t -f IN-USE,SSID,SIGNAL device wifi list ifname "$iface" 2>/dev/null \
        | awk -F: '$1=="*"{print; exit}')
    ssid=$(printf '%s' "$line" | cut -d: -f2)
    signal=$(printf '%s' "$line" | cut -d: -f3)
    [[ "$signal" =~ ^[0-9]+$ ]] || signal=0

    ip4=$(LC_ALL=C nmcli -t -f IP4.ADDRESS device show "$iface" 2>/dev/null \
        | head -n1 | cut -d: -f2 | cut -d/ -f1)
    [[ -z "$ip4" ]] && ip4="-"
    [[ -z "$ssid" ]] && ssid="-"

    local icon
    if   (( signal >= 80 )); then icon="$ICON_L4"
    elif (( signal >= 55 )); then icon="$ICON_L3"
    elif (( signal >= 30 )); then icon="$ICON_L2"
    else                          icon="$ICON_L1"
    fi

    local tooltip="$(i18n_template "${MSG[DEVICE_CONNECTED]}" DEVICE="$iface" SSID="$ssid" IP="$ip4" SIGNAL="$signal")"

    jq -nc --arg icon "$icon" --arg tooltip "$tooltip" \
        '{"text": $icon,
          "tooltip": $tooltip,
          "class": "connected"}'
}

# Report initial state immediately
iface=$(get_wifi_iface)
emit "$iface"

# Signal strength changes may not trigger ip monitor events, so do periodic refresh
while true; do
    sleep 15
    iface=$(get_wifi_iface)
    emit "$iface"
done
