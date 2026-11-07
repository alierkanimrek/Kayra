#!/usr/bin/env bash
#
# Bluetooth Menu - Click behavior for the "custom/bluetooth" Waybar module.
#
# The menu lists the known Bluetooth devices and allows the user to turn the
# adapter on/off, start a scan, connect or disconnect a paired device, and
# pair a device that is not paired yet.
#
# Commands used:
#   bash, bluetoothctl, fuzzel, awk, sed, pkill, timeout
#
# Dependencies:
#   bluez (bluetoothctl), fuzzel, notify-send (optional notifications).
#
# Design: the labels are built from three bluetoothctl queries only
# ("devices", "devices Paired", "devices Connected"); no per-device "info"
# call is made, so the menu stays fast even with many known devices.

set -uo pipefail
export LC_ALL=C.UTF-8

source "$(dirname "$0")/i18n.sh"
source "$(dirname "$0")/klog.sh"
source "$(dirname "$0")/notify.sh"
declare -n MSG=i18n_BLUETOOTH_MENU

# Material Symbols codepoints used in the menu entries.
ICON_BT=$(printf '%b' '\U0000E1A7')        # bluetooth
ICON_CONNECTED=$(printf '%b' '\U0000E1A8') # bluetooth_connected
ICON_ADD=$(printf '%b' '\U0000E145')       # add
ICON_SCAN=$(printf '%b' '\U0000E8B6')      # search
ICON_POWER=$(printf '%b' '\U0000E8AC')     # power_settings_new
ICON_CHECK=$(printf '%b' '\U0000E5CA')     # check

require_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        log ERROR "Required command not found: $command_name" >&2
        notify_error "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[NOTIFY_COMMAND_NOT_FOUND]}" COMMAND="$command_name")"
        exit 1
    fi
}

require_command bluetoothctl
require_command fuzzel

# Pairs a device reliably. A one-shot "bluetoothctl pair" has no registered
# agent, so BlueZ asks for a passkey confirmation and the pairing is cancelled.
# A registered NoInputNoOutput agent plus auto-confirmation avoids this.
pair_device() {
    local mac="$1"

    {
        printf 'agent NoInputNoOutput\n'; sleep 1
        printf 'pair %s\n' "$mac"
        for _ in 1 2 3 4 5 6; do sleep 1; printf 'yes\n'; done
        printf 'trust %s\n' "$mac"; sleep 1
        printf 'connect %s\n' "$mac"; sleep 3
        printf 'quit\n'
    } | timeout 30 bluetoothctl --agent NoInputNoOutput >/dev/null 2>&1
}

# --- Adapter state --------------------------------------------------------
adapter_out=$(timeout 3 bluetoothctl show 2>/dev/null)

if [[ -z "$adapter_out" || "$adapter_out" == *"No default controller available"* ]]; then
    log ERROR "Bluetooth adapter not found" >&2
    notify_error "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[NOTIFY_NO_DEVICE]}")"
    exit 1
fi

powered=$(printf '%s\n' "$adapter_out" | awk -F': ' '/Powered:/ { print $2; exit }' | tr -d '[:space:]')

# --- Collect the device lists --------------------------------------------
declare -a connected_macs=() paired_macs=()
mapfile -t connected_macs < <(timeout 3 bluetoothctl devices Connected 2>/dev/null | awk '{ print $2 }')
mapfile -t paired_macs    < <(timeout 3 bluetoothctl devices Paired    2>/dev/null | awk '{ print $2 }')

declare -A is_connected=() is_paired=()
for mac in "${connected_macs[@]}"; do [[ -n "$mac" ]] && is_connected["$mac"]=1; done
for mac in "${paired_macs[@]}";    do [[ -n "$mac" ]] && is_paired["$mac"]=1; done

# --- Build the menu -------------------------------------------------------
declare -A menu_map=()
declare -a menu_lines=()
declare -A used_label=()

add_line() {
    local label="$1" action="$2"

    # Keep labels unique, because the selection is matched by its text.
    if [[ -n "${used_label[$label]:-}" ]]; then
        label="$label ${3:-}"
    fi
    used_label["$label"]=1

    menu_lines+=("$label")
    menu_map["$label"]="$action"
}

# Power toggle
if [[ "$powered" == "yes" ]]; then
    add_line "$ICON_POWER  ${MSG[ACTION_POWER_OFF]}" "power-off"
else
    add_line "$ICON_POWER  ${MSG[ACTION_POWER_ON]}" "power-on"
fi

# Scan (only useful while the adapter is on)
[[ "$powered" == "yes" ]] && add_line "$ICON_SCAN  ${MSG[ACTION_SCAN]}" "scan"

# Known devices: paired first, then unpaired.
while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    rest="${line#Device }"
    mac="${rest%% *}"
    name="${rest#* }"
    [[ "$name" == "$mac" ]] && name="$mac"

    if [[ -n "${is_paired[$mac]:-}" ]]; then
        if [[ -n "${is_connected[$mac]:-}" ]]; then
            add_line "$ICON_CONNECTED  $name" "disconnect:$mac" "$mac"
        else
            add_line "$ICON_BT  $name" "connect:$mac" "$mac"
        fi
    else
        add_line "$ICON_ADD  $name" "pair:$mac" "$mac"
    fi
done < <(timeout 3 bluetoothctl devices 2>/dev/null)

if [[ ${#menu_lines[@]} -eq 0 ]]; then
    log WARN "No Bluetooth devices found" >&2
    notify_warn "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_NO_DEVICES]}")"
    exit 1
fi

# --- Show the menu --------------------------------------------------------
LINES=("${menu_lines[@]}")
MAX_WIDTH=$(printf '%s\n' "${LINES[@]}" | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')

pkill -x fuzzel 2>/dev/null || true
selection=$(printf '%s\n' "${menu_lines[@]}" \
    | fuzzel --dmenu --anchor=top-right --log-no-syslog --minimal-lines --hide-prompt \
        --placeholder="${MSG[PROMPT_SELECT]}" --prompt="${MSG[PROMPT_LABEL]}" \
        --width="$MAX_WIDTH")

if [[ -z "$selection" ]]; then
    log INFO "Bluetooth menu selection cancelled" >&2
    exit 0
fi

action="${menu_map[$selection]:-}"
if [[ -z "$action" ]]; then
    log WARN "Invalid Bluetooth menu selection" >&2
    exit 0
fi

# --- Run the selected action ---------------------------------------------
case "$action" in
    power-on)
        if timeout 5 bluetoothctl power on >/dev/null 2>&1; then
            log INFO "Bluetooth turned on" >&2
            notify_ok "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_POWER_ON]}")"
        else
            log ERROR "Failed to turn Bluetooth on" >&2
            notify_error "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_POWER_FAILED]}")"
        fi
        ;;
    power-off)
        if timeout 5 bluetoothctl power off >/dev/null 2>&1; then
            log INFO "Bluetooth turned off" >&2
            notify_ok "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_POWER_OFF]}")"
        else
            log ERROR "Failed to turn Bluetooth off" >&2
            notify_error "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_POWER_FAILED]}")"
        fi
        ;;
    scan)
        log INFO "Bluetooth scan started" >&2
        NOTIFY_TIMEOUT=3000 notify_ok "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_SCAN_STARTED]}")"
        timeout 18 bluetoothctl --timeout 15 scan on >/dev/null 2>&1
        # Reopen the menu with the refreshed device list.
        log INFO "Bluetooth scan finished, reopening the menu" >&2
        exec "${BASH_SOURCE[0]}" "$@"
        ;;
    connect:*)
        mac="${action#connect:}"
        if timeout 15 bluetoothctl connect "$mac" >/dev/null 2>&1; then
            log INFO "Bluetooth device connected: $mac" >&2
            notify_ok "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_CONNECTED]}" NAME="$selection")"
        else
            log ERROR "Failed to connect Bluetooth device: $mac" >&2
            notify_error "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_CONNECT_FAILED]}" NAME="$selection")"
        fi
        ;;
    disconnect:*)
        mac="${action#disconnect:}"
        if timeout 10 bluetoothctl disconnect "$mac" >/dev/null 2>&1; then
            log INFO "Bluetooth device disconnected: $mac" >&2
            notify_ok "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_DISCONNECTED]}" NAME="$selection")"
        else
            log ERROR "Failed to disconnect Bluetooth device: $mac" >&2
            notify_error "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_DISCONNECT_FAILED]}" NAME="$selection")"
        fi
        ;;
    pair:*)
        mac="${action#pair:}"
        pair_device "$mac"
        if timeout 3 bluetoothctl info "$mac" 2>/dev/null | grep -q 'Paired: yes'; then
            log INFO "Bluetooth device paired: $mac" >&2
            notify_ok "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_PAIRED]}" NAME="$selection")"
        else
            log ERROR "Failed to pair Bluetooth device: $mac" >&2
            notify_error "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_PAIR_FAILED]}" NAME="$selection")"
        fi
        ;;
esac
