#!/usr/bin/env bash
#
# kayra-toggle-service.sh - Changes the state of a runit service.
#
# Called from kayra-show-services.sh when a service is selected:
#   kayra-toggle-service.sh <service-name> [state] [protected]
#   e.g. kayra-toggle-service.sh sshd running false
#
# The actual work is done by the kayra-system-services job socket. This script
# is the user-facing client:
#   * It validates the service name and finds the state when it is missing.
#   * A running service offers "Stop" and "Restart" in an actionable
#     notification.
#   * A stopped service is started, a disabled service is enabled and started.
#   * The handler sends its events back on the same connection; this script
#     turns the terminal event into a notification. No separate monitor runs.
#
# Protected services are reported by the service manager in the list response.
# A running protected service never opens the stop/restart prompt; the user
# gets a translated information notification instead. The service enforces the
# same rule on its own.
#
# The socket is only reachable for members of the fixed kayra-admin group. A
# regular user exits silently before any request is sent. If an admin cannot
# reach the service manager (service stopped, socket permission or timeout), a
# translated error notification is shown. The same happens when the request
# gets no response.
#
# Usage: kayra-toggle-service.sh <service-name> [running|stopped|disabled] [true|false]
#
# Used commands: notify-send (via notify.sh), jq (via services-client.sh),
#                socat, flock
#

set -uo pipefail

export LC_ALL=C.UTF-8

source /usr/local/lib/kayra/admin.sh
require_kayra_admin

source /usr/local/lib/kayra/i18n.sh
declare -n MSG=i18n_TOGGLE_SERVICE

source /usr/local/lib/kayra/klog.sh
source /usr/local/lib/kayra/notify.sh
source /usr/local/lib/kayra/services-client.sh

# Icon of the notifications (Material Symbols codepoint).
ICON_SERVICE=$(printf '%b' '\U000E726')   # services
NOTIFY_ICON="$ICON_SERVICE"

# Returns the message of a key, the fallback is used when the key is
# missing. The fallback is passed as a separate argument, a placeholder
# inside a ${...:-default} expression would break the expansion.
msg_text() {
    local value="${MSG[$1]}"
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

manager_unavailable() {
    log ERROR "kayra-system-services is not reachable"
    notify_error "$(msg_text NOTIFY_TITLE 'Services')" \
        "$(msg_text MSG_MANAGER_UNAVAILABLE 'Service manager is not running')"
}

# Reads the state and the protected flag from the service manager.
lookup_service() {
    local list line

    if ! list=$(services_list); then
        manager_unavailable
        return 1
    fi

    line=$(awk -F'\t' -v service="$SERVICE" '
        $1 == service { print $2 "\t" $3; exit }
    ' <<<"$list")

    if [ -z "$line" ]; then
        log WARN "Service not found: $SERVICE"
        notify_error "$(msg_text NOTIFY_TITLE 'Services')" \
            "$(msg_service MSG_NOT_FOUND 'Service not found: {SERVICE}')"
        return 1
    fi

    IFS=$'\t' read -r STATE PROTECTED <<<"$line"
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
                notify_ok "$(msg_text NOTIFY_TITLE 'Services')" \
                    "$(msg_event MSG_STOPPED 'Service {SERVICE} stopped')"
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
                    "$(msg_event MSG_FAILED 'Failed to toggle service {SERVICE}')"
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
                notify_ok "$(msg_text NOTIFY_TITLE 'Services')" \
                    "$(msg_service MSG_STOPPED 'Service {SERVICE} stopped')"
                ;;
            restart)
                notify_ok "$(msg_text NOTIFY_TITLE 'Services')" \
                    "$(msg_service MSG_RESTARTED 'Service {SERVICE} restarted')"
                ;;
            enable)
                notify_ok "$(msg_text NOTIFY_TITLE 'Services')" \
                    "$(msg_service MSG_ENABLED 'Service {SERVICE} enabled and started')"
                ;;
        esac
    else
        notify_error "$(msg_text NOTIFY_TITLE 'Services')" \
            "$(msg_service MSG_FAILED 'Failed to toggle service {SERVICE}')"
    fi

    return 0
}

SERVICE="${1:-}"
STATE="${2:-}"
PROTECTED="${3:-}"

if [ -z "$SERVICE" ]; then
    log ERROR "No service name given"
    echo "$(msg_text MSG_USAGE 'Usage: toggle-service.sh <service-name>')" >&2
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

case "$STATE" in
    running|stopped|disabled) ;;
    *) STATE="" ;;
esac

if [ -z "$STATE" ] || [ -z "$PROTECTED" ]; then
    lookup_service || exit 1
fi

[ -n "$PROTECTED" ] || PROTECTED="false"

# ------------------------------------------------------------------
# Act according to the state of the service
# ------------------------------------------------------------------
case "$STATE" in
    running)
        if [ "$PROTECTED" = "true" ]; then
            log WARN "Service $SERVICE is protected, it can not be stopped or restarted"
            notify_info "$(msg_text NOTIFY_TITLE 'Services')" \
                "$(msg_service MSG_PROTECTED 'Service {SERVICE} can not be stopped')"
            exit 0
        fi

        # A running service offers the stop and restart actions in an
        # actionable notification.
        ACTION=$(notify_action "$(msg_text NOTIFY_TITLE 'Services')" \
            "$(msg_service MSG_ACTION_QUERY 'Service {SERVICE} is running. What do you want to do?')" \
            "stop=$(msg_text ACTION_STOP 'Stop')" \
            "restart=$(msg_text ACTION_RESTART 'Restart')")

        case "$ACTION" in
            stop)
                send_action stop
                ;;
            restart)
                send_action restart
                ;;
            *)
                log INFO "No action selected for service: $SERVICE"
                ;;
        esac
        ;;
    stopped)
        send_action start
        ;;
    disabled)
        send_action enable
        ;;
esac

exit 0
