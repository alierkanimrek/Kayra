#!/usr/bin/env bash
#
# kayra-power-mode-menu.sh - Left-click menu of the Waybar "battery" module.
#
# Shows the TLP power profiles in a fuzzel menu and applies the selected one
# through the kayra-power-services job socket:
#   Performance  -> profile performance
#   Balanced     -> profile balanced
#   Power Saver  -> profile power-saver
#   Automatic    -> profile auto
#
# The actual work is done by the root service:
#   performance|balanced|power-saver   tlpctl set <profile>
#   auto                               tlp start (AC/battery automatic mode)
#
# The service is the only way to change a profile. When it can not be reached
# (service stopped, socket permission or timeout) a translated error
# notification is shown and nothing is changed.
#
# The active profile is read from the service (status command) and marked with
# a check glyph in the menu. The service reports the profile from "tlpctl get";
# it never reports "automatic", so the Automatic entry carries no mark.
#
# Used commands: fuzzel, pkill, awk, head, tr, printf, jq (via power-client.sh),
#                log (via klog.sh), notify_* (via notify.sh),
#                power_call (via power-client.sh)
#
# Usage: kayra-power-mode-menu.sh   (Waybar "battery" on-click)

set -uo pipefail
export LC_ALL=C.UTF-8

source /usr/local/lib/kayra/i18n.sh
declare -n MSG=i18n_POWER_MODE_MENU

source /usr/local/lib/kayra/klog.sh
source /usr/local/lib/kayra/notify.sh
source /usr/local/lib/kayra/power-client.sh

# Notification icon (Material Icons "bolt"), rendered by notify.sh.
NOTIFY_ICON=$(printf '%b' '\U0000EA0B')

# Stable profile ids in display order. The visible labels come from
# i18n_POWER_MODE_MENU (PROFILE_<ID_UPPER>) so the menu follows the language.
declare -a PROFILE_IDS=(
    performance
    balanced
    power-saver
    auto
)

# Material Icons glyphs (verified present in the installed font).
ICON_PERFORMANCE=$(printf '%b' '\U0000E9E4')  # speed
ICON_BALANCED=$(printf '%b' '\U0000E429')     # tune
ICON_POWER_SAVER=$(printf '%b' '\U0000EA35')  # eco
ICON_AUTO=$(printf '%b' '\U0000E863')         # autorenew
ICON_CHECK=$(printf '%b' '\U0000E5CA')        # check (active marker)

# The power service is required: without it no profile can be changed.
if ! power_call status; then
    log ERROR "kayra-power-services is not reachable" >&2
    notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_SERVICE_UNAVAILABLE]}"
    exit 1
fi

# Read the currently active profile from the service response.
ACTIVE="$("$POWER_JQ" -r '.data.profile // empty' <<<"$POWER_RES" 2>/dev/null)"

# Print the profile label of a stable id (e.g. power-saver -> PROFILE_POWER_SAVER).
profile_label() {
    local id="$1"
    local key
    key="PROFILE_${id^^}"
    key="${key//-/_}"
    printf '%s' "${MSG[$key]:-$id}"
}

# Print the icon of a stable id.
profile_icon() {
    case "$1" in
        performance) printf '%s' "$ICON_PERFORMANCE" ;;
        balanced)    printf '%s' "$ICON_BALANCED" ;;
        power-saver) printf '%s' "$ICON_POWER_SAVER" ;;
        auto)        printf '%s' "$ICON_AUTO" ;;
        *)           printf '%s' "" ;;
    esac
}

# Build the menu lines and the line -> profile id map.
declare -a MENU_LINES=()
declare -A MENU_MAP=()

for id in "${PROFILE_IDS[@]}"; do
    icon="$(profile_icon "$id")"
    label="$(profile_label "$id")"

    mark=""
    [[ -n "$ACTIVE" && "$id" == "$ACTIVE" ]] && mark="$ICON_CHECK "

    line="$icon  $mark$label"
    MENU_LINES+=("$line")
    MENU_MAP["$line"]="$id"
done

# Window width of the longest menu entry (icon counted as 3 characters).
MAX_WIDTH=$(printf '%s\n' "${MENU_LINES[@]}" | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')

# Close any existing fuzzel menu before opening this one.
pkill -x fuzzel 2>/dev/null || true

selection=$(printf '%s\n' "${MENU_LINES[@]}" \
    | fuzzel --dmenu --anchor=top-right --log-no-syslog --minimal-lines --hide-prompt \
        --width="$MAX_WIDTH")

if [[ -z "$selection" ]]; then
    log INFO "Power mode menu cancelled" >&2
    exit 0
fi

profile="${MENU_MAP[$selection]:-}"
if [[ -z "$profile" ]]; then
    log WARN "Invalid power mode selection" >&2
    exit 0
fi

# Ask the service to apply the selected profile. The parm is one element:
# ["<profile>"].
parm=$("$POWER_JQ" -cn --arg profile "$profile" '[$profile]') || exit 1

if ! power_call profile "$parm"; then
    log ERROR "kayra-power-services is not reachable" >&2
    notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_SERVICE_UNAVAILABLE]}"
    exit 1
fi

if power_result_ok; then
    if [[ "$profile" == "auto" ]]; then
        log INFO "Switched to automatic power profile" >&2
        notify_ok "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_AUTO_SET]}"
    else
        label="$(profile_label "$profile")"
        log INFO "Power mode set to: $profile" >&2
        notify_ok "${MSG[NOTIFY_TITLE]}" \
            "$(i18n_template "${MSG[MSG_SET]}" PROFILE="$label")"
    fi
    exit 0
fi

log ERROR "Failed to set power mode: $profile" >&2
notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_SET_FAILED]}"
exit 1
