#!/usr/bin/env bash
#
# wifi-menu.sh — Click behavior for "custom/wifi" module.
#
# Presents list of available networks via fuzzel --dmenu:
#   <signal-icon> <lock-if-encrypted> <✓ if-connected> SSID
# When a network is selected:
#   - If already connected -> disconnect.
#   - If encrypted -> ask password via fuzzel --password and connect
#     (fuzzel masks input; wofi doesn't, so fuzzel is preferred for passwords).
#   - If open -> connect directly.
#
# Dependencies: nmcli (NetworkManager), fuzzel, jq (optional for consistency;
# plain bash/awk is sufficient here, so jq is not required).

set -uo pipefail
export LC_CTYPE=en_US.UTF-8

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_WIFI_MENU

# Prevent nmcli output from using localized keywords (Turkish, etc.);
# locale-independent text comparisons (STATE, SECURITY, "--" etc.) rely on this.

ICON_L1=$(printf '%b' '\U0000EBE4')
ICON_L2=$(printf '%b' '\U0000EBD6')
ICON_L3=$(printf '%b' '\U0000EBE1')
ICON_L4=$(printf '%b' '\U0000E1D8')
LOCK="🔒"
CHECK="✓"

notify() {
    command -v notify-send >/dev/null 2>&1 && notify-send -a "Wifi" "$1" "${2:-}"
}

iface=$(LC_ALL=C nmcli -t -f DEVICE,TYPE device status | awk -F: '$2=="wifi"{print $1; exit}')
if [[ -z "$iface" ]]; then
    notify "Wifi" "${MSG[NOTIFY_DEVICE_NOT_FOUND]}"
    exit 1
fi

active_ssid=$(LC_ALL=C nmcli -t -f IN-USE,SSID device wifi list ifname "$iface" \
    | awk -F: '$1=="*"{print $2; exit}')

# Request fresh scan (use cached list if scan fails)
LC_ALL=C nmcli device wifi rescan ifname "$iface" >/dev/null 2>&1
sleep 1

# Get SSID:SECURITY:SIGNAL lines, sort by signal, deduplicate by SSID
mapfile -t networks < <(
    LC_ALL=C nmcli -t -f SSID,SECURITY,SIGNAL device wifi list ifname "$iface" 2>/dev/null \
        | awk -F: '$1!=""' \
        | sort -t: -k3,3 -nr \
        | awk -F: '!seen[$1]++'
)

if [[ ${#networks[@]} -eq 0 ]]; then
    notify "Wifi" "${MSG[NOTIFY_NO_NETWORKS]}"
    exit 1
fi

declare -A menu_map
menu_lines=()

for entry in "${networks[@]}"; do
    ssid="${entry%%:*}"
    rest="${entry#*:}"
    security="${rest%%:*}"
    signal="${rest#*:}"
    [[ "$signal" =~ ^[0-9]+$ ]] || signal=0

    if   (( signal >= 80 )); then icon="$ICON_L4"
    elif (( signal >= 55 )); then icon="$ICON_L3"
    elif (( signal >= 30 )); then icon="$ICON_L2"
    else                          icon="$ICON_L1"
    fi

    lock=""
    [[ -n "$security" && "$security" != "--" ]] && lock="$LOCK "

    mark=""
    [[ "$ssid" == "$active_ssid" ]] && mark="$CHECK "

    label="${icon}  ${lock}${mark}${ssid}"
    menu_lines+=("$label")
    menu_map["$label"]="${ssid}:::${security}"
done


selection=$(pkill fuzzel 2>/dev/null || true; printf '%s\n' "${menu_lines[@]}" \
    | fuzzel --dmenu --anchor=top-right --log-no-syslog --placeholder="${MSG[PROMPT_SELECT]}" --lines=10 --prompt="${MSG[PROMPT_LABEL]}")
[[ -z "$selection" ]] && exit 0

chosen="${menu_map[$selection]:-}"
[[ -z "$chosen" ]] && exit 0

ssid="${chosen%%:::*}"
security="${chosen#*:::}"

# If selected network is already connected: disconnect
if [[ "$ssid" == "$active_ssid" ]]; then
    if LC_ALL=C nmcli device disconnect "$iface" >/dev/null 2>&1; then
        notify "Wifi" "${MSG[MSG_DISCONNECTED]}" "$ssid"
    else
        notify "Wifi" "${MSG[MSG_DISCONNECT_FAILED]}" "$ssid"
    fi
    exit 0
fi

# Encrypted network: ask for masked password via fuzzel --password
if [[ -n "$security" && "$security" != "--" ]]; then
    password=$(fuzzel --dmenu --password --anchor=top-right --log-no-syslog --placeholder="$(i18n_template "${MSG[PROMPT_PASSWORD]}" SSID="$ssid")" --prompt="${MSG[PROMPT_PASSWORD_LABEL]}" < /dev/null)
    [[ -z "$password" ]] && exit 0

    if LC_ALL=C nmcli device wifi connect "$ssid" password "$password" ifname "$iface" >/dev/null 2>&1; then
        notify "Wifi" "${MSG[MSG_CONNECTED]}" "$ssid"
    else
        notify "Wifi" "${MSG[MSG_CONNECT_FAILED]}" "$ssid"
    fi
else
    if LC_ALL=C nmcli device wifi connect "$ssid" ifname "$iface" >/dev/null 2>&1; then
        notify "Wifi" "${MSG[MSG_CONNECTED]}" "$ssid"
    else
        notify "Wifi" "${MSG[MSG_CONNECT_FAILED]}" "$ssid"
    fi
fi
