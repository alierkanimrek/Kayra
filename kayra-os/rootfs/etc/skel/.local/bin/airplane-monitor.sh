#!/usr/bin/env bash
#
# airplane-monitor.sh - Waybar status producer for the "custom/airplane" module.
#
# Commands used:
#   bash, rfkill, awk, jq
#
# Behavior:
#   - Hidden ({"text":"","class":"hidden"}) when the "plane_mode_icon" setting
#     in ~/.config/kayra/settings.conf is not "true". The module itself always
#     stays in the Waybar config; only its output decides whether it is visible.
#   - Airplane ON : every rfkill radio is soft-blocked -> flight icon (E539),
#     class "on" (colored with @color-warning by style.css).
#   - Airplane OFF: airplanemode_inactive icon (E194), class "off".
#
# Monitoring:
#   - "rfkill event" is opened on file descriptor 3. Every line it prints means
#     a radio changed, so the module is refreshed immediately. Changes made
#     manually from the command line are followed as well. No flag file is used.
#   - "read -t POLL_INTERVAL" is a safety net: when no event arrives within the
#     interval the state is sampled again, so a plane_mode_icon change is picked
#     up even though it raises no rfkill event.
#
# Dependencies: rfkill (util-linux), jq, awk.

export LC_ALL=C.UTF-8

source "$HOME/.local/bin/single-instance.sh"
single_instance

source "$(dirname "$0")/klog.sh"
source "$(dirname "$0")/i18n.sh"
source "$(dirname "$0")/settings-conf.sh"
declare -n MSG=i18n_AIRPLANE_MONITOR

# Material Symbols codepoints used by the Waybar module.
ICON_ON=$(printf '%b' '\U0000E539')    # flight
ICON_OFF=$(printf '%b' '\U0000E194')   # airplanemode_inactive

POLL_INTERVAL=3      # safety refresh in seconds (when no rfkill event arrives)
LAST_STATUS=""

for required_command in rfkill awk jq; do
    if ! command -v "$required_command" >/dev/null 2>&1; then
        log ERROR "Required command not found: $required_command" >&2
        exit 1
    fi
done

# Prints "on" when every rfkill radio is soft-blocked, otherwise "off".
get_airplane_state() {
    rfkill --noheadings --output SOFT list 2>/dev/null \
        | awk '$1 == "blocked" { b++ }
               $1 == "unblocked" { u++ }
               END { print (b > 0 && u == 0) ? "on" : "off" }'
}

emit_state() {
    local state icon status tooltip

    if [[ "$(conf_get plane_mode_icon)" != "true" ]]; then
        if [[ "$LAST_STATUS" != "hidden" ]]; then
            log INFO "Airplane mode icon hidden (disabled)" >&2
            LAST_STATUS="hidden"
        fi
        jq -nc '{"text":"","tooltip":"","class":"hidden"}'
        return
    fi

    state=$(get_airplane_state)
    if [[ "$state" == "on" ]]; then
        icon="$ICON_ON"
        tooltip="${MSG[ON]}"
        status="on"
    else
        icon="$ICON_OFF"
        tooltip="${MSG[OFF]}"
        status="off"
    fi

    if [[ "$LAST_STATUS" != "$status" ]]; then
        log INFO "Airplane mode status changed: $status" >&2
        LAST_STATUS="$status"
    fi

    jq -nc --arg icon "$icon" --arg tooltip "$tooltip" --arg class "$status" \
        '{"text": $icon, "tooltip": $tooltip, "class": $class}'
}

log INFO "Airplane monitor started" >&2

# The rfkill event stream lives on file descriptor 3.
exec 3< <(rfkill event 2>/dev/null)

emit_state
while :; do
    IFS= read -r -t "$POLL_INTERVAL" _ <&3
    rc=$?
    # rc == 0   : an rfkill event arrived           -> instant refresh
    # rc > 128  : read timed out (safety net)       -> refresh anyway
    # otherwise : the rfkill event stream ended     -> stop
    if (( rc != 0 && rc <= 128 )); then
        log WARN "rfkill event stream ended" >&2
        break
    fi
    emit_state
done
