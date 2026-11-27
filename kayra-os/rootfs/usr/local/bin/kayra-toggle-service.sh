#!/usr/bin/env bash
#
# kayra-toggle-service.sh - Manages one runit service from the desktop session.
#
# Called from kayra-show-services.sh when a service is selected:
#   kayra-toggle-service.sh <service-name> [state] [protected] [boot]
#   e.g. kayra-toggle-service.sh sshd running false auto
#
# State: running | down | disabled | failed
# Boot:  auto | manual   (manual = /etc/sv/<service>/down exists)
#
# The actual work is done by the kayra-system-services job socket. This script
# is the user-facing client:
#   * It validates the service name and reads the state when it is missing.
#   * It opens a fuzzel action menu with the actions that are valid for the
#     current state. "Stop now" and "do not start at boot" are separate
#     actions: a stopped service still starts at boot, a down file stops the
#     automatic start without removing the service link.
#   * "Details" shows the state, PID, uptime, boot policy and the optional
#     "sv check" result (the check script is not required). A "Show log
#     records" button opens the log stream of the service in a terminal
#     window (kayra-show-service-logs.sh, tail -F); "Close" dismisses the
#     detail notification. A one-shot "sv once" test is in the action menu
#     for a stopped or failed service.
#   * The handler sends its events back on the same connection; this script
#     turns the terminal event into a notification. No separate monitor runs.
#
# Protected services are reported by the service manager in the list response.
# A running protected service never opens the action menu; the user gets a
# translated information notification instead. The service enforces the same
# rule on its own.
#
# The socket is only reachable for members of the fixed kayra-admin group. A
# regular user exits silently before any request is sent. If an admin cannot
# reach the service manager (service stopped, socket permission or timeout), a
# translated error notification is shown. The same happens when the request
# gets no response.
#
# Usage:
#   kayra-toggle-service.sh <service-name> [running|down|disabled|failed]
#                           [true|false] [auto|manual]
#
# Used commands: fuzzel, pkill, setsid, awk, jq (via services-client.sh),
#                notify-send (via notify.sh), socat, flock,
#                settings-conf.sh (conf_get)
#

set -uo pipefail

export LC_ALL=C.UTF-8

source /usr/local/lib/kayra/admin.sh
require_kayra_admin

source /usr/local/lib/kayra/i18n.sh
declare -n MSG=i18n_TOGGLE_SERVICE

source /usr/local/lib/kayra/klog.sh
source /usr/local/lib/kayra/notify.sh
source /usr/local/lib/kayra/settings-conf.sh
source /usr/local/lib/kayra/services-client.sh

# Icon of the notifications (Material Symbols codepoint).
ICON_SERVICE=$(printf '%b' '\U000E726')   # services
NOTIFY_ICON="$ICON_SERVICE"

# Returns the message of a key, the fallback is used when the key is
# missing. The fallback is passed as a separate argument, a placeholder
# inside a ${...:-default} expression would break the expansion.
msg_text() {
    local value="${MSG[$1]-}"
    [ -n "$value" ] || value="$2"
    printf '%s' "$value"
}

# Returns the message of a key with the service name in it.
msg_service() {
    i18n_template "$(msg_text "$1" "$2")" "SERVICE=$SERVICE"
}

# Returns the message of a key with the service name of an event in it.
msg_event() {
    i18n_template "$(msg_text "$1" "$2")" "SERVICE=$EVENT_SERVICE"
}

# Translated label of a service state.
state_label() {
    case "$1" in
        running)  msg_text STATE_RUNNING 'running' ;;
        down)     msg_text STATE_DOWN 'stopped' ;;
        disabled) msg_text STATE_DISABLED 'disabled' ;;
        failed)   msg_text STATE_FAILED 'failed' ;;
        *)        msg_text STATE_UNKNOWN 'unknown' ;;
    esac
}

# Translated label of the boot policy.
boot_label() {
    case "$1" in
        manual) msg_text BOOT_MANUAL 'does not start at boot' ;;
        *)      msg_text BOOT_AUTO 'starts at boot' ;;
    esac
}

manager_unavailable() {
    log ERROR "kayra-system-services is not reachable"
    notify_error "$(msg_text NOTIFY_TITLE 'Services')" \
        "$(msg_text MSG_MANAGER_UNAVAILABLE 'Service manager is not running')"
}

# Reads the state, the protected flag and the boot policy from the manager.
lookup_service() {
    local list line

    if ! list=$(services_list); then
        manager_unavailable
        return 1
    fi

    line=$(awk -F'\t' -v service="$SERVICE" '
        $1 == service {
            print $2 "\t" $3 "\t" ($4 == "" ? "auto" : $4)
            exit
        }
    ' <<<"$list")

    if [ -z "$line" ]; then
        log WARN "Service not found: $SERVICE"
        notify_error "$(msg_text NOTIFY_TITLE 'Services')" \
            "$(msg_service MSG_NOT_FOUND 'Service not found: {SERVICE}')"
        return 1
    fi

    IFS=$'\t' read -r STATE PROTECTED BOOT <<<"$line"
    return 0
}

# Turns the terminal events of the last request into notifications.
NOTIFIED=0

show_events() {
    local line event

    NOTIFIED=0

    for line in "${SERVICES_EVENTS[@]}"; do
        event=$("${JQ:-jq}" -r '.event // empty' <<<"$line" 2>/dev/null)
        EVENT_SERVICE=$("${JQ:-jq}" -r '.data.service // empty' <<<"$line" 2>/dev/null)
        [ -n "$EVENT_SERVICE" ] || EVENT_SERVICE="$SERVICE"

        case "$event" in
            started)
                log INFO "Service $EVENT_SERVICE started"
                notify_ok "$(msg_text NOTIFY_TITLE 'Services')" \
                    "$(msg_event MSG_STARTED 'Service {SERVICE} started')"
                NOTIFIED=1
                ;;
            stopped)
                log INFO "Service $EVENT_SERVICE stopped"
                if [ "$BOOT" = "manual" ]; then
                    notify_ok "$(msg_text NOTIFY_TITLE 'Services')" \
                        "$(msg_event MSG_STOPPED_MANUAL 'Service {SERVICE} stopped; it does not start at boot')"
                else
                    notify_ok "$(msg_text NOTIFY_TITLE 'Services')" \
                        "$(msg_event MSG_STOPPED 'Service {SERVICE} stopped now; it still starts at boot')"
                fi
                NOTIFIED=1
                ;;
            restarted)
                log INFO "Service $EVENT_SERVICE restarted"
                notify_ok "$(msg_text NOTIFY_TITLE 'Services')" \
                    "$(msg_event MSG_RESTARTED 'Service {SERVICE} restarted')"
                NOTIFIED=1
                ;;
            enabled)
                log INFO "Service $EVENT_SERVICE enabled and started"
                notify_ok "$(msg_text NOTIFY_TITLE 'Services')" \
                    "$(msg_event MSG_ENABLED 'Service {SERVICE} enabled and started')"
                NOTIFIED=1
                ;;
            disabled)
                log INFO "Service $EVENT_SERVICE disabled"
                notify_ok "$(msg_text NOTIFY_TITLE 'Services')" \
                    "$(msg_event MSG_DISABLED 'Service {SERVICE} disabled')"
                NOTIFIED=1
                ;;
            boot_off)
                log INFO "Service $EVENT_SERVICE will not start at boot"
                notify_ok "$(msg_text NOTIFY_TITLE 'Services')" \
                    "$(msg_event MSG_BOOT_OFF 'Service {SERVICE} will not start at boot')"
                NOTIFIED=1
                ;;
            boot_on)
                log INFO "Service $EVENT_SERVICE will start at boot"
                notify_ok "$(msg_text NOTIFY_TITLE 'Services')" \
                    "$(msg_event MSG_BOOT_ON 'Service {SERVICE} will start at boot')"
                NOTIFIED=1
                ;;
            once)
                log INFO "Service $EVENT_SERVICE run once"
                notify_ok "$(msg_text NOTIFY_TITLE 'Services')" \
                    "$(msg_event MSG_ONCE 'Service {SERVICE} run once')"
                NOTIFIED=1
                ;;
            protected)
                log WARN "Service $EVENT_SERVICE is protected"
                notify_warn "$(msg_text NOTIFY_TITLE 'Services')" \
                    "$(msg_event MSG_PROTECTED 'Service {SERVICE} can not be stopped')"
                NOTIFIED=1
                ;;
            notfound)
                log WARN "Service not found: $EVENT_SERVICE"
                notify_warn "$(msg_text NOTIFY_TITLE 'Services')" \
                    "$(msg_event MSG_NOT_FOUND 'Service not found: {SERVICE}')"
                NOTIFIED=1
                ;;
            failed)
                log ERROR "Failed to change service: $EVENT_SERVICE"
                notify_error "$(msg_text NOTIFY_TITLE 'Services')" \
                    "$(msg_event MSG_FAILED 'Failed to change service {SERVICE}')"
                NOTIFIED=1
                ;;
        esac
    done
}

# Sends an action request and shows the result.
send_action() {
    local action=$1

    log INFO "Changing service $SERVICE: $action"

    if ! services_action "$action" "$SERVICE"; then
        manager_unavailable
        return 1
    fi

    show_events
    (( NOTIFIED == 1 )) && return 0

    # The handler normally emits an event. This fallback keeps the user
    # informed when a response arrives without a terminal event.
    if services_result_ok; then
        case "$action" in
            start)
                notify_ok "$(msg_text NOTIFY_TITLE 'Services')" \
                    "$(msg_service MSG_STARTED 'Service {SERVICE} started')"
                ;;
            stop)
                if [ "$BOOT" = "manual" ]; then
                    notify_ok "$(msg_text NOTIFY_TITLE 'Services')" \
                        "$(msg_service MSG_STOPPED_MANUAL 'Service {SERVICE} stopped; it does not start at boot')"
                else
                    notify_ok "$(msg_text NOTIFY_TITLE 'Services')" \
                        "$(msg_service MSG_STOPPED 'Service {SERVICE} stopped now; it still starts at boot')"
                fi
                ;;
            restart)
                notify_ok "$(msg_text NOTIFY_TITLE 'Services')" \
                    "$(msg_service MSG_RESTARTED 'Service {SERVICE} restarted')"
                ;;
            enable)
                notify_ok "$(msg_text NOTIFY_TITLE 'Services')" \
                    "$(msg_service MSG_ENABLED 'Service {SERVICE} enabled and started')"
                ;;
            disable)
                notify_ok "$(msg_text NOTIFY_TITLE 'Services')" \
                    "$(msg_service MSG_DISABLED 'Service {SERVICE} disabled')"
                ;;
            boot-off)
                notify_ok "$(msg_text NOTIFY_TITLE 'Services')" \
                    "$(msg_service MSG_BOOT_OFF 'Service {SERVICE} will not start at boot')"
                ;;
            boot-on)
                notify_ok "$(msg_text NOTIFY_TITLE 'Services')" \
                    "$(msg_service MSG_BOOT_ON 'Service {SERVICE} will start at boot')"
                ;;
            once)
                notify_ok "$(msg_text NOTIFY_TITLE 'Services')" \
                    "$(msg_service MSG_ONCE 'Service {SERVICE} run once')"
                ;;
        esac
    else
        notify_error "$(msg_text NOTIFY_TITLE 'Services')" \
            "$(msg_service MSG_FAILED 'Failed to change service {SERVICE}')"
    fi

    return 0
}

# ------------------------------------------------------------------
# Action menu
# ------------------------------------------------------------------
declare -a ACTION_IDS=()
declare -a ACTION_LABELS=()
MENU_MESG=""

add_action() {  # add_action <id> <label>
    ACTION_IDS+=("$1")
    ACTION_LABELS+=("$2")
}

build_menu() {
    ACTION_IDS=()
    ACTION_LABELS=()

    MENU_MESG="$SERVICE - $(state_label "$STATE")"
    if [ "$STATE" != "disabled" ] && [ "$BOOT" = "manual" ]; then
        MENU_MESG="$MENU_MESG, $(boot_label manual)"
    fi
    [ "$PROTECTED" = "true" ] &&
        MENU_MESG="$MENU_MESG, $(msg_text LABEL_PROTECTED 'protected')"

    case "$STATE" in
        running)
            if [ "$PROTECTED" = "true" ]; then
                add_action detail "$(msg_text ACTION_DETAIL 'Details')"
            else
                add_action stop "$(msg_text ACTION_STOP 'Stop now')"
                add_action restart "$(msg_text ACTION_RESTART 'Restart')"
                if [ "$BOOT" = "manual" ]; then
                    add_action boot-on "$(msg_text ACTION_BOOT_ON 'Start at boot')"
                else
                    add_action boot-off "$(msg_text ACTION_BOOT_OFF 'Do not start at boot')"
                fi
                add_action disable "$(msg_text ACTION_DISABLE 'Disable service')"
                add_action detail "$(msg_text ACTION_DETAIL 'Details')"
            fi
            ;;
        down)
            add_action start "$(msg_text ACTION_START 'Start now')"
            if [ "$PROTECTED" = "true" ]; then
                # Turning the automatic start back on is harmless; stopping
                # or disabling a protected service is not.
                [ "$BOOT" = "manual" ] &&
                    add_action boot-on "$(msg_text ACTION_BOOT_ON 'Start at boot')"
            else
                if [ "$BOOT" = "manual" ]; then
                    add_action boot-on "$(msg_text ACTION_BOOT_ON 'Start at boot')"
                else
                    add_action boot-off "$(msg_text ACTION_BOOT_OFF 'Do not start at boot')"
                fi
                add_action once "$(msg_text ACTION_ONCE 'Run once')"
                add_action disable "$(msg_text ACTION_DISABLE 'Disable service')"
            fi
            add_action detail "$(msg_text ACTION_DETAIL 'Details')"
            ;;
        failed)
            if [ "$PROTECTED" = "true" ]; then
                add_action detail "$(msg_text ACTION_DETAIL 'Details')"
            else
                add_action restart "$(msg_text ACTION_RESTART 'Restart')"
                add_action once "$(msg_text ACTION_ONCE 'Run once')"
                add_action disable "$(msg_text ACTION_DISABLE 'Disable service')"
                add_action detail "$(msg_text ACTION_DETAIL 'Details')"
            fi
            ;;
        disabled)
            add_action enable "$(msg_text ACTION_ENABLE 'Enable and start')"
            add_action detail "$(msg_text ACTION_DETAIL 'Details')"
            ;;
    esac
}

choose_action() {
    local selected i
    local max_width

    ((${#ACTION_IDS[@]})) || return 1

    pkill -x fuzzel 2>/dev/null || true

    max_width=$(printf '%s\n' "${ACTION_LABELS[@]}" \
        | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')

    selected=$(printf '%s\n' "${ACTION_LABELS[@]}" \
        | fuzzel --dmenu --anchor=top-right \
            --log-no-syslog --minimal-lines --hide-prompt \
            --width="$max_width" --lines 12 \
            --mesg="$MENU_MESG") || true

    [ -n "$selected" ] || return 1

    for i in "${!ACTION_LABELS[@]}"; do
        if [ "${ACTION_LABELS[$i]}" = "$selected" ]; then
            printf '%s' "${ACTION_IDS[$i]}"
            return 0
        fi
    done

    return 1
}

# ------------------------------------------------------------------
# Detail view
# ------------------------------------------------------------------
load_detail() {  # fills SERVICES_RES with the detail response
    if ! services_action detail "$SERVICE"; then
        manager_unavailable
        return 1
    fi

    if ! services_result_ok; then
        log ERROR "Failed to read service detail: $SERVICE"
        notify_error "$(msg_text NOTIFY_TITLE 'Services')" \
            "$(msg_service MSG_FAILED 'Failed to change service {SERVICE}')"
        return 1
    fi

    return 0
}

build_detail_body() {
    local state boot pid uptime check_defined check_ok check_message body

    state=$("${JQ:-jq}" -r '.data.state // "unknown"' <<<"$SERVICES_RES")
    boot=$("${JQ:-jq}" -r '.data.boot // "auto"' <<<"$SERVICES_RES")
    pid=$("${JQ:-jq}" -r '.data.pid // ""' <<<"$SERVICES_RES")
    uptime=$("${JQ:-jq}" -r '.data.uptime // ""' <<<"$SERVICES_RES")
    check_defined=$("${JQ:-jq}" -r '.data.check.defined // empty' <<<"$SERVICES_RES")
    check_ok=$("${JQ:-jq}" -r '.data.check.ok // false' <<<"$SERVICES_RES")
    check_message=$("${JQ:-jq}" -r '.data.check.message // ""' <<<"$SERVICES_RES")

    body="$(msg_text LABEL_STATE 'State'): $(state_label "$state")"
    body="$body"$'\n'"$(msg_text LABEL_PID 'PID'): ${pid:--}${uptime:+ ($uptime)}"
    body="$body"$'\n'"$(msg_text LABEL_BOOT 'At boot'): $(boot_label "$boot")"

    if [ "$("${JQ:-jq}" -r '.data.protected // false' <<<"$SERVICES_RES")" = "true" ]; then
        body="$body"$'\n'"$(msg_text LABEL_PROTECTED 'protected')"
    fi

    if [ "$check_defined" = "false" ]; then
        body="$body"$'\n'"$(msg_text LABEL_CHECK 'Check'): $(msg_text CHECK_UNDEFINED 'not defined')"
    elif [ "$check_ok" = "true" ]; then
        body="$body"$'\n'"$(msg_text LABEL_CHECK 'Check'): $(msg_text CHECK_OK 'ready')"
    else
        body="$body"$'\n'"$(msg_text LABEL_CHECK 'Check'): $(msg_text CHECK_FAILED 'not ready')"
        [ -n "$check_message" ] && body="$body ($check_message)"
    fi

    printf '%s' "$body"
}

open_log_console() {
    local terminal term_cmd

    # The terminal setting can carry arguments (for example "alacritty -e").
    terminal="$(conf_get terminal | head -n1)"
    [ -n "$terminal" ] || terminal="alacritty -e"
    term_cmd=${terminal%% *}

    if ! command -v "$term_cmd" >/dev/null 2>&1; then
        log ERROR "Terminal not found: $term_cmd"
        notify_error "$(msg_text NOTIFY_TITLE 'Services')" \
            "$(msg_text MSG_NO_TERMINAL 'Could not open a terminal window')"
        return 1
    fi

    # shellcheck disable=SC2086
    if ! setsid -f $terminal /usr/local/bin/kayra-show-service-logs.sh \
        "$SERVICE" >/dev/null 2>&1; then
        log ERROR "Failed to open the log console"
        notify_error "$(msg_text NOTIFY_TITLE 'Services')" \
            "$(msg_text MSG_NO_TERMINAL 'Could not open a terminal window')"
        return 1
    fi

    log INFO "Opened the log console for service: $SERVICE"
    return 0
}

show_detail() {
    local body action

    load_detail || return 1
    body=$(build_detail_body)

    # notify_action treats a body that contains "=" as an action list; check
    # messages can contain "=", so use the fullwidth equals for display.
    body=${body//=/＝}

    action=$(notify_action \
        "$(msg_service MSG_DETAIL_TITLE 'Service {SERVICE}')" \
        "$body" \
        "show-logs=$(msg_text ACTION_SHOW_LOGS 'Show log records')" \
        "close=$(msg_text ACTION_CLOSE 'Close')")

    case "$action" in
        show-logs)
            open_log_console
            ;;
        *)
            log INFO "Service detail closed: $SERVICE"
            ;;
    esac

    return 0
}

# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------
SERVICE="${1:-}"
STATE="${2:-}"
PROTECTED="${3:-}"
BOOT="${4:-}"

if [ -z "$SERVICE" ]; then
    log ERROR "No service name given"
    echo "$(msg_text MSG_USAGE 'Usage: kayra-toggle-service.sh <service-name>')" >&2
    exit 1
fi

# Only plain service names are accepted, no path traversal.
case "$SERVICE" in
    */*|.|..)
        log ERROR "Invalid service name: $SERVICE"
        echo "$(msg_service MSG_NOT_FOUND 'Service not found: {SERVICE}')" >&2
        notify_error "$(msg_text NOTIFY_TITLE 'Services')" \
            "$(msg_service MSG_NOT_FOUND 'Service not found: {SERVICE}')"
        exit 1
        ;;
esac

if [ ! -d "/etc/sv/$SERVICE" ]; then
    log WARN "Service directory not found: /etc/sv/$SERVICE"
    echo "$(msg_service MSG_NOT_FOUND 'Service not found: {SERVICE}')" >&2
    notify_error "$(msg_text NOTIFY_TITLE 'Services')" \
        "$(msg_service MSG_NOT_FOUND 'Service not found: {SERVICE}')"
    exit 1
fi

case "$PROTECTED" in
    true|false) ;;
    *) PROTECTED="" ;;
esac

# "stopped" was the old name of the down state; keep it as an alias.
case "$STATE" in
    stopped) STATE="down" ;;
    running|down|disabled|failed) ;;
    *) STATE="" ;;
esac

case "$BOOT" in
    auto|manual) ;;
    *) BOOT="" ;;
esac

if [ -z "$STATE" ] || [ -z "$PROTECTED" ] || [ -z "$BOOT" ]; then
    lookup_service || exit 1
fi

[ -n "$PROTECTED" ] || PROTECTED="false"
[ -n "$BOOT" ] || BOOT="auto"

# A running protected service must not be stopped or restarted. The manager
# enforces the same rule, this only avoids a menu that cannot work.
if [ "$STATE" = "running" ] && [ "$PROTECTED" = "true" ]; then
    log WARN "Service $SERVICE is protected, it can not be stopped or restarted"
    notify_info "$(msg_text NOTIFY_TITLE 'Services')" \
        "$(msg_service MSG_PROTECTED 'Service {SERVICE} can not be stopped')"
    exit 0
fi

build_menu
ACTION=$(choose_action) || exit 0

case "$ACTION" in
    detail)
        show_detail
        ;;
    *)
        send_action "$ACTION"
        ;;
esac

exit 0
