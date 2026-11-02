#!/usr/bin/env bash
#
# power-menu.sh - Power and session menu for Kayra OS.
#
# Opens a fuzzel menu with the options: Shutdown, Reboot, Logout, Lock.
#   Shutdown -> loginctl poweroff
#   Reboot   -> loginctl reboot
#   Logout   -> loginctl terminate-user $USER
#   Lock     -> loginctl lock-session
#
# Shutdown, Reboot and Logout commands are executed through a control layer.
# The control layer runs the registered checks one by one; a check that does
# not approve the action blocks the command and its message is delivered with
# notify-send. Currently the only check is the existence of /tmp/xbps.lock.
#
# Used commands: fuzzel, loginctl, notify-send, cat, id, date, pkill, printf

export LC_ALL=C.UTF-8

set -uo pipefail

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_POWER_MENU

source "$(dirname "$0")/klog.sh"
source "$(dirname "$0")/notify.sh"

# The current user is used for the logout action.
CURRENT_USER="${USER:-$(id -un)}"

# Lock file created by the software manager while software operations run.
LOCK_FILE="/tmp/xbps.lock"

# Material symbols used in the menu labels.
ICON_SHUTDOWN=$(printf '%b' '\U000F16F')
ICON_REBOOT=$(printf '%b' '\U000E042')
ICON_LOGOUT=$(printf '%b' '\U000E9BA')
ICON_LOCK=$(printf '%b' '\U000E897')

# Stable action ids in display order. The visible labels are read from
# i18n_POWER_MENU (ITEM_<ACTION_ID>) so the menu follows the active language.
declare -a MENU_ITEMS=(
    "Shutdown"
    "Reboot"
    "Logout"
    "Lock"
)

# Control layer checks. Each check function prints a deny message and returns
# non zero when the action must not run. More checks can be appended here.
declare -a CHECK_FUNCTIONS=(
    check_xbps_lock
)

# Control layer check: a running software operation blocks the action.
check_xbps_lock() {
    local lock_content

    if [[ -f "$LOCK_FILE" ]]; then
        lock_content=$(cat "$LOCK_FILE" 2>/dev/null || true)
        [[ -n "$lock_content" ]] || lock_content="${MSG[LOCK_MSG]}"
        echo "${MSG[LOCK_MSG]} $lock_content"
        return 1
    fi

    return 0
}

# Run the control layer checks. Returns 0 when the action is approved.
control_layer() {
    local action="$1"
    local check_fn
    local deny_message

    for check_fn in "${CHECK_FUNCTIONS[@]}"; do
        if ! deny_message="$("$check_fn" "$action")"; then
            [[ -n "$deny_message" ]] || deny_message="${MSG[MSG_BLOCKED]}"
            notify_error "${MSG[NOTIFY_TITLE]}" "$deny_message"
            log WARN "Power action '$action' blocked by $check_fn: $deny_message"
            return 1
        fi
    done

    log INFO "Power action '$action' approved by the control layer"
    return 0
}

# Execute the action selected in the menu.
run_action() {
    local action="$1"

    case "$action" in
        Shutdown)
            control_layer "$action" || return 0
            log INFO "Executing shutdown: loginctl poweroff"
            loginctl poweroff
            ;;
        Reboot)
            control_layer "$action" || return 0
            log INFO "Executing reboot: loginctl reboot"
            loginctl reboot
            ;;
        Logout)
            control_layer "$action" || return 0
            log INFO "Executing logout: loginctl terminate-user $CURRENT_USER"
            loginctl terminate-user "$CURRENT_USER"
            ;;
        Lock)
            # Lock is not guarded by the control layer.
            if [[ -n "${XDG_SESSION_ID:-}" ]]; then
                log INFO "Executing lock: loginctl lock-session $XDG_SESSION_ID"
                loginctl lock-session "$XDG_SESSION_ID"
            else
                log INFO "Executing lock: loginctl lock-session"
                loginctl lock-session
            fi
            ;;
        *)
            log WARN "Unknown power action: $action"
            notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_UNKNOWN_ACTION]}"
            ;;
    esac
}

# Print the stable action id for a localized menu label. Fails when the label
# does not belong to any known menu entry.
resolve_action() {
    local label="$1"
    local item

    for item in "${MENU_ITEMS[@]}"; do
        if [[ "$label" == "${MSG[ITEM_${item^^}]}" ]]; then
            echo "$item"
            return 0
        fi
    done

    return 1
}

# Build the fuzzel input list with icons and localized labels. The result is
# stored in the global MENU_LINES array so the width can be calculated from it.
declare -a MENU_LINES=()

build_menu_lines() {
    local item
    local label

    MENU_LINES=()

    for item in "${MENU_ITEMS[@]}"; do
        label="${MSG[ITEM_${item^^}]}"
        case "$item" in
            Shutdown) MENU_LINES+=("$ICON_SHUTDOWN $label") ;;
            Reboot)   MENU_LINES+=("$ICON_REBOOT $label") ;;
            Logout)   MENU_LINES+=("$ICON_LOGOUT $label") ;;
            Lock)     MENU_LINES+=("$ICON_LOCK $label") ;;
            *)        MENU_LINES+=("$label") ;;
        esac
    done
}

# Build the menu entries once, then calculate the window width.
build_menu_lines

# Window width of the longest menu entry (icon counted as 3 characters).
MAX_WIDTH=$(printf '%s\n' "${MENU_LINES[@]}" | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')

# Close any existing fuzzel process before opening the menu.
pkill -x fuzzel 2>/dev/null || true

SELECTED_LINE=$(printf '%s\n' "${MENU_LINES[@]}" | fuzzel --dmenu --log-no-syslog --minimal-lines --lines="${#MENU_LINES[@]}" --width="$MAX_WIDTH" --hide-prompt) || true

[[ -z "$SELECTED_LINE" ]] && exit 0

# Strip the icon and keep the localized label.
SELECTED_LABEL="${SELECTED_LINE#* }"

[[ -z "$SELECTED_LABEL" ]] && exit 0

# Translate the label back to the stable action id used by run_action.
# An unknown label reaches the fallback branch of run_action.
SELECTED_ACTION="$(resolve_action "$SELECTED_LABEL")" || true

run_action "$SELECTED_ACTION"
