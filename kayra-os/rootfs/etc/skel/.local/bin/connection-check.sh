#!/usr/bin/env bash
#
# Waybar module script for custom/wifi-warning (event-driven / "ip monitor")
# ---------------------------------------------------------------------------
# Logic:
#   - If "nmcli networking connectivity check" output is "full"  -> no icon
#   - If system has a Wi-Fi device (even if not connected) -> no icon
#   - If none of the above (connectivity is not "full" AND
#     no Wi-Fi device present)                              -> warning icon
#
# No periodic (interval) checks: script reports status once on startup,
# then listens to interface (link) / address / route events via "ip monitor"
# and only rechecks when something changes. Waybar runs this script continuously
# (without interval); each line is read as a new JSON state.
#
# NOTE: The original icon code is an invalid Unicode codepoint.
# If you want a different icon, replace the line below with your own codepoint.

set -u

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_CONNECTION_CHECK

ICON_WARNING=$(printf '%b' '\U000FFFB7')

trap 'exit 0' TERM INT PIPE

check_and_report() {
    local connectivity has_wifi_device

    connectivity="$(nmcli networking connectivity check 2>/dev/null)"

    has_wifi_device="false"
    if nmcli -t -f TYPE device status 2>/dev/null | grep -qx "wifi"; then
        has_wifi_device="true"
    fi

    if [[ "$connectivity" == "full" || "$has_wifi_device" == "true" ]]; then
        # Everything is normal: show no icon
        printf '{"text": "", "class": "hidden"}\n'
    else
        # Internet is not "full" AND no Wi-Fi device present -> warn
        printf '{"text": "%s", "class": "warning", "tooltip": "%s"}\n' \
            "$ICON_WARNING" "$(i18n_template "${MSG[TOOLTIP_NO_WIFI_NO_INTERNET]}" CONNECTIVITY="$connectivity")"
    fi
}

# Report current status once at startup
check_and_report


# Read "ip monitor" output line by line; listens for link (interface add/remove,
# up/down), address (IP assignment/removal) and route (default route changes) events.
# This command produces no output unless network changes, so it idles on the CPU.
ip monitor link address route 2>/dev/null | while true; do
    # Wait until an event line arrives
    if ! read -r _; then
        break
    fi

    # Combine consecutive events within a short time (e.g., multiple lines from
    # an interface going down/up) into a single check (debounce) to prevent
    # unnecessary repeated checks.
    while read -r -t 0.5 _; do :; done

    # Check if stdout is still available before writing
    if ! printf "" 2>/dev/null; then
        break
    fi
    
    check_and_report
done
