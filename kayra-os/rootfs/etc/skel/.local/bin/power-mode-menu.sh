#!/usr/bin/env bash
#
# power-mode-menu.sh - Left-click menu of the Waybar "battery" module.
#
# Shows the TLP power profiles in a fuzzel menu and applies the selected one:
#   Performance  -> tlpctl set performance
#   Balanced     -> tlpctl set balanced
#   Power Saver  -> tlpctl set power-saver
#   Automatic    -> pkexec tlp start   (back to the AC/battery automatic mode)
#
# The three profile changes go through tlpctl, which talks to the tlp-pd
# daemon over D-Bus (org.freedesktop.UPower.PowerProfiles). tlpctl needs no
# root, only an active unlocked session. "Automatic" has no tlpctl command,
# so it uses "tlp start", which requires root and is run through pkexec
# (polkit password dialog), the same pattern as the other Kayra scripts.
#
# The active profile is read with "tlpctl get" (single line, e.g.
# "performance") and marked with a check glyph in the menu. tlpctl never
# reports "automatic" as a profile, so the Automatic entry carries no mark.
#
# Used commands: tlpctl, tlp, pkexec, fuzzel, pkill, awk, head, printf,
#                command, log (via klog.sh), notify_* (via notify.sh)
#
# Usage: power-mode-menu.sh   (Waybar "battery" on-click)

set -uo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

source "$SCRIPT_DIR/i18n.sh"
declare -n MSG=i18n_POWER_MODE_MENU

source "$SCRIPT_DIR/klog.sh"
source "$SCRIPT_DIR/notify.sh"

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

# tlpctl is required, pkexec is required for the Automatic entry only.
if ! command -v tlpctl >/dev/null 2>&1; then
    log ERROR "Required command not found: tlpctl" >&2
    notify_error "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[NOTIFY_COMMAND_NOT_FOUND]}" COMMAND="tlpctl")"
    exit 1
fi

# Read the currently active profile (empty when it can not be read).
ACTIVE="$(tlpctl get 2>/dev/null | head -n1 | tr -d '[:space:]')"

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

# Apply the selected profile.
if [[ "$profile" == "auto" ]]; then
    if ! command -v pkexec >/dev/null 2>&1; then
        log ERROR "Required command not found: pkexec" >&2
        notify_error "${MSG[NOTIFY_TITLE]}" \
            "$(i18n_template "${MSG[NOTIFY_COMMAND_NOT_FOUND]}" COMMAND="pkexec")"
        exit 1
    fi

    if pkexec tlp start >/dev/null 2>&1; then
        log INFO "Switched to automatic power profile" >&2
        notify_ok "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_AUTO_SET]}"
        exit 0
    fi

    log ERROR "Failed to switch to automatic power profile" >&2
    notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_SET_FAILED]}"
    exit 1
fi

if tlpctl set "$profile" >/dev/null 2>&1; then
    label="$(profile_label "$profile")"
    log INFO "Power mode set to: $profile" >&2
    notify_ok "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MSG_SET]}" PROFILE="$label")"
    exit 0
fi

log ERROR "Failed to set power mode: $profile" >&2
notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_SET_FAILED]}"
exit 1
