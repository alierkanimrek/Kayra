#!/usr/bin/env bash
#
# Wi-Fi Menu - Click behavior for the "custom/wifi" Waybar module.
#
# The menu lists nearby networks and allows the user to connect, disconnect,
# or enter a password for an encrypted network.
#
# Commands used:
#   bash, nmcli, fuzzel, awk, sort, sleep, pkill, command
#
# Dependencies:
#   nmcli (NetworkManager), fuzzel, notify-send (optional notifications).

set -uo pipefail
export LC_ALL=C.UTF-8

source "$(dirname "$0")/i18n.sh"
source "$(dirname "$0")/klog.sh"
source "$(dirname "$0")/notify.sh"
declare -n MSG=i18n_WIFI_MENU

# Material Symbols codepoints used in menu entries.
ICON_L1=$(printf '%b' '\U0000EBE4')
ICON_L2=$(printf '%b' '\U0000EBD6')
ICON_L3=$(printf '%b' '\U0000EBE1')
ICON_L4=$(printf '%b' '\U0000E1D8')
ICON_LOCK=$(printf '%b' '\U000E73C')
ICON_CHECK=$(printf '%b' '\U000E5CA')

require_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        log ERROR "Required command not found: $command_name" >&2
        notify_error "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[NOTIFY_COMMAND_NOT_FOUND]}" COMMAND="$command_name")"
        exit 1
    fi
}

require_command nmcli
require_command fuzzel

iface=$(nmcli --terse --escape no --fields DEVICE,TYPE device status 2>/dev/null \
    | awk -F: '$2 == "wifi" { print $1; exit }')

if [[ -z "$iface" ]]; then
    log ERROR "Wi-Fi device not found" >&2
    notify_error "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[NOTIFY_DEVICE_NOT_FOUND]}")"
    exit 1
fi

active_ssid=$(nmcli --terse --escape no --fields IN-USE,SSID device wifi list ifname "$iface" 2>/dev/null \
    | awk -F: '$1 == "*" {
        ssid = $2;
        for (i = 3; i <= NF; i++) ssid = ssid ":" $i;
        print ssid;
        exit
    }')

# Request a fresh scan and use the cached list if the scan fails.
if ! nmcli device wifi rescan ifname "$iface" >/dev/null 2>&1; then
    log WARN "Wi-Fi scan failed; using the cached network list" >&2
fi
sleep 1

# Fields are separated by ASCII unit separator so SSIDs containing colons or
# tabs remain intact. The third field is used for numeric signal sorting.
network_rows=()
mapfile -t network_rows < <(
    nmcli --terse --escape no --fields SSID,SECURITY,SIGNAL device wifi list ifname "$iface" 2>/dev/null \
        | awk -F: '{
            ssid = $1;
            for (i = 2; i <= NF - 2; i++) ssid = ssid ":" $i;
            security = $(NF - 1);
            signal = $NF;
            printf "%s\037%s\037%s\n", ssid, security, signal;
        }' \
        | sort -t $'\037' -k3,3nr \
        | awk -F $'\037' '!seen[$1]++'
)

if [[ ${#network_rows[@]} -eq 0 ]]; then
    log WARN "No Wi-Fi networks found" >&2
    notify_warn "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[NOTIFY_NO_NETWORKS]}")"
    exit 1
fi

declare -A menu_map=()
menu_lines=()

for row in "${network_rows[@]}"; do
    ssid="${row%%$'\037'*}"
    remaining="${row#*$'\037'}"
    security="${remaining%%$'\037'*}"
    signal="${remaining##*$'\037'}"

    [[ "$signal" =~ ^[0-9]+$ ]] || signal=0

    if   (( signal >= 80 )); then icon="$ICON_L4"
    elif (( signal >= 55 )); then icon="$ICON_L3"
    elif (( signal >= 30 )); then icon="$ICON_L2"
    else                          icon="$ICON_L1"
    fi

    lock=""
    [[ -n "$security" && "$security" != "--" ]] && lock="$ICON_LOCK "

    mark=""
    [[ -n "$active_ssid" && "$ssid" == "$active_ssid" ]] && mark="$ICON_CHECK "

    display_ssid="$ssid"
    [[ -z "$ssid" ]] && display_ssid="$(i18n_template "${MSG[MSG_HIDDEN]}")"

    label="$icon  $lock$mark$display_ssid"
    menu_lines+=("$label")
    menu_map["$label"]="$ssid$'\037'$security"
done

LINES=("${menu_lines[@]}")
MAX_WIDTH=$(printf '%s\n' "${LINES[@]}" | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')

pkill -x fuzzel 2>/dev/null || true
selection=$(printf '%s\n' "${menu_lines[@]}" \
    | fuzzel --dmenu --anchor=top-right --log-no-syslog --minimal-lines --hide-prompt \
        --placeholder="${MSG[PROMPT_SELECT]}" --prompt="${MSG[PROMPT_LABEL]}" \
        --width="$MAX_WIDTH")

if [[ -z "$selection" ]]; then
    log INFO "Wi-Fi menu selection cancelled" >&2
    exit 0
fi

chosen="${menu_map[$selection]:-}"
if [[ -z "$chosen" ]]; then
    log WARN "Invalid Wi-Fi menu selection" >&2
    exit 0
fi

ssid="${chosen%%$'\037'*}"
security="${chosen#*$'\037'}"
display_ssid="$ssid"
[[ -z "$display_ssid" ]] && display_ssid="$(i18n_template "${MSG[MSG_HIDDEN]}")"

# Disconnect the active network when it is selected again.
if [[ -n "$active_ssid" && "$ssid" == "$active_ssid" ]]; then
    if nmcli device disconnect "$iface" >/dev/null 2>&1; then
        log INFO "Disconnected from Wi-Fi network: $display_ssid" >&2
        notify_ok "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_DISCONNECTED]}" SSID="$display_ssid")"
    else
        log ERROR "Failed to disconnect from Wi-Fi network: $display_ssid" >&2
        notify_error "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_DISCONNECT_FAILED]}" SSID="$display_ssid")"
    fi
    exit 0
fi

# Ask for the password of an encrypted network.
if [[ -n "$security" && "$security" != "--" ]]; then
    password_prompt=$(i18n_template "${MSG[PROMPT_PASSWORD]}" SSID="$display_ssid")

    pkill -x fuzzel 2>/dev/null || true
    password=$(fuzzel --dmenu --password --anchor=top-right --log-no-syslog --minimal-lines \
        --placeholder="$password_prompt" --prompt="${MSG[PROMPT_PASSWORD_LABEL]}" < /dev/null)

    if [[ -z "$password" ]]; then
        log INFO "Wi-Fi password entry cancelled" >&2
        exit 0
    fi

    if nmcli device wifi connect "$ssid" password "$password" ifname "$iface" >/dev/null 2>&1; then
        log INFO "Connected to Wi-Fi network: $display_ssid" >&2
        notify_ok "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_CONNECTED]}" SSID="$display_ssid")"
    else
        log ERROR "Failed to connect to Wi-Fi network: $display_ssid" >&2
        notify_error "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_CONNECT_FAILED]}" SSID="$display_ssid")"
    fi
else
    if nmcli device wifi connect "$ssid" ifname "$iface" >/dev/null 2>&1; then
        log INFO "Connected to Wi-Fi network: $display_ssid" >&2
        notify_ok "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_CONNECTED]}" SSID="$display_ssid")"
    else
        log ERROR "Failed to connect to Wi-Fi network: $display_ssid" >&2
        notify_error "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_CONNECT_FAILED]}" SSID="$display_ssid")"
    fi
fi
