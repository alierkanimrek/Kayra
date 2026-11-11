#!/usr/bin/env bash
#
# airplane-toggle.sh - Click action for the "custom/airplane" Waybar module.
#
# Toggles the system airplane mode with rfkill: when every radio is already
# soft-blocked it runs "rfkill unblock all", otherwise "rfkill block all"
# (this also turns Bluetooth off, like a real airplane mode). The change raises
# an rfkill event, so airplane-monitor.sh updates the icon immediately.
#
# Used commands: bash, rfkill, awk.

export LC_ALL=C.UTF-8

source "$(dirname "$0")/klog.sh"

for required_command in rfkill awk; do
    if ! command -v "$required_command" >/dev/null 2>&1; then
        log ERROR "Required command not found: $required_command" >&2
        exit 1
    fi
done

state=$(rfkill --noheadings --output SOFT list 2>/dev/null \
    | awk '$1 == "blocked" { b++ }
           $1 == "unblocked" { u++ }
           END { print (b > 0 && u == 0) ? "on" : "off" }')

if [[ "$state" == "on" ]]; then
    if rfkill unblock all >/dev/null 2>&1; then
        log INFO "Airplane mode disabled" >&2
    else
        log ERROR "Failed to disable airplane mode" >&2
        exit 1
    fi
else
    if rfkill block all >/dev/null 2>&1; then
        log INFO "Airplane mode enabled" >&2
    else
        log ERROR "Failed to enable airplane mode" >&2
        exit 1
    fi
fi
