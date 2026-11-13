#!/usr/bin/env bash
#
# toggle-service.sh - Changes the state of a runit service.
#
# Called from show-services.sh when a service is selected:
#   toggle-service.sh <service-name> [state]
#   e.g. toggle-service.sh sshd running
#
# * Service definition: /etc/sv/<name>
# * Enabled service:   /var/service/<name> (symlink handled by runsvdir)
#
# The optional second argument is the state that show-services.sh read with
# the root helper (running, stopped or disabled). When it is missing, the
# state is guessed from the process table (sv-lib.sh).
#
# Behavior:
#   running  -> an actionable notification with a "Stop" and a "Restart"
#               button is shown, the selected action is executed
#   stopped  -> the service is started                  (sv up)
#   disabled -> the service is enabled and started      (symlink + sv up)
#
# The services listed in PROTECTED_SERVICES are never stopped or restarted,
# stopping them would break the running session (D-Bus, the greeter, the log
# daemons and the polkit agent). They can still be started.
#
# A protected service is detected before the root helper is started, so no
# password is asked when such a service would be stopped.
#
# The runit control commands need root privileges, they are executed
# through pkexec, so a polkit password dialog is shown while changing a
# service. The root helper is the permanent script sv-toggle-helper.sh.
#
# Important instructions:
#   * Only a plain service name is accepted, a name with a path would leave
#     the service directory.
#   * The action of the user is read from the notification with notify_action
#     (notify.sh). The notification stays on screen while waiting for the
#     answer.
#   * The result of the helper is read from its output: STARTED, STOPPED,
#     RESTARTED, ENABLED, PROTECTED, NOTFOUND or FAILED.
#   * The log messages are in English, the notification texts come from the
#     language file (i18n_TOGGLE_SERVICE).
#
# Usage: toggle-service.sh <service-name> [running|stopped|disabled]
#
# Used commands: pkexec, pgrep, notify-send (via notify.sh)
#

set -uo pipefail

export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "$0")")" && pwd)"

SV_DIR="/etc/sv"
SERVICE_DIR="/var/service"
HELPER="$SCRIPT_DIR/sv-toggle-helper.sh"

# Services that must stay running, they can not be stopped or restarted.
PROTECTED_SERVICES=(
    dbus
    greetd
    socklog-unix
    nanoklogd
    polkitd
)

source "$SCRIPT_DIR/i18n.sh"
declare -n MSG=i18n_TOGGLE_SERVICE

source "$SCRIPT_DIR/klog.sh"
source "$SCRIPT_DIR/notify.sh"
source "$SCRIPT_DIR/sv-lib.sh"

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

# Returns 0 when the service is protected and must not be stopped.
is_protected() {
    [[ " ${PROTECTED_SERVICES[*]} " == *" $SERVICE "* ]]
}

SERVICE="${1:-}"
STATE="${2:-}"

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
        exit 1
        ;;
esac

if [ ! -d "$SV_DIR/$SERVICE" ]; then
    log WARN "Service directory not found: $SV_DIR/$SERVICE"
    echo "$(msg_service MSG_NOT_FOUND 'Service not found: {SERVICE}')" >&2
    exit 1
fi

if [ ! -r "$HELPER" ]; then
    log ERROR "Root helper not found: $HELPER"
    notify_error "$(msg_text NOTIFY_TITLE 'Services')" \
        "$(msg_service MSG_FAILED 'Failed to toggle service {SERVICE}')"
    exit 1
fi

if ! command -v pkexec >/dev/null 2>&1; then
    log ERROR "pkexec is not installed"
    notify_error "$(msg_text NOTIFY_TITLE 'Services')" \
        "$(msg_service MSG_FAILED 'Failed to toggle service {SERVICE}')"
    exit 1
fi

# The state from the menu is trusted, otherwise it is guessed.
case "$STATE" in
    running|stopped|disabled) ;;
    *) STATE=$(sv_guess_state "$SERVICE") ;;
esac

# ------------------------------------------------------------------
# run_action <start|stop|restart|enable>
# ------------------------------------------------------------------
# Protected services are checked before the root helper is called, so no
# password is asked when a protected service would be stopped or restarted.
run_action() {
    local action="$1" result

    if [ "$action" != "start" ] && [ "$action" != "enable" ] && is_protected; then
        log WARN "Service $SERVICE is protected, it can not be stopped or restarted"
        notify_error "$(msg_text NOTIFY_TITLE 'Services')" \
            "$(msg_service MSG_PROTECTED 'Service {SERVICE} can not be stopped')"
        return 1
    fi

    result=$(pkexec /bin/sh "$HELPER" "$action" "$SERVICE" "${PROTECTED_SERVICES[@]}" 2>/dev/null)
    [ -z "$result" ] && result="FAILED"

    case "$result" in
        STARTED)
            log INFO "Service $SERVICE started"
            notify_ok "$(msg_text NOTIFY_TITLE 'Services')" \
                "$(msg_service MSG_STARTED 'Service {SERVICE} started')"
            ;;
        STOPPED)
            log INFO "Service $SERVICE stopped"
            notify_ok "$(msg_text NOTIFY_TITLE 'Services')" \
                "$(msg_service MSG_STOPPED 'Service {SERVICE} stopped')"
            ;;
        RESTARTED)
            log INFO "Service $SERVICE restarted"
            notify_ok "$(msg_text NOTIFY_TITLE 'Services')" \
                "$(msg_service MSG_RESTARTED 'Service {SERVICE} restarted')"
            ;;
        ENABLED)
            log INFO "Service $SERVICE enabled and started"
            notify_ok "$(msg_text NOTIFY_TITLE 'Services')" \
                "$(msg_service MSG_ENABLED 'Service {SERVICE} enabled and started')"
            ;;
        PROTECTED)
            log WARN "Service $SERVICE is protected, it can not be stopped"
            notify_error "$(msg_text NOTIFY_TITLE 'Services')" \
                "$(msg_service MSG_PROTECTED 'Service {SERVICE} can not be stopped')"
            return 1
            ;;
        NOTFOUND)
            log WARN "Service not found: $SERVICE"
            notify_error "$(msg_text NOTIFY_TITLE 'Services')" \
                "$(msg_service MSG_NOT_FOUND 'Service not found: {SERVICE}')"
            return 1
            ;;
        *)
            log ERROR "Failed to change service: $SERVICE"
            notify_error "$(msg_text NOTIFY_TITLE 'Services')" \
                "$(msg_service MSG_FAILED 'Failed to toggle service {SERVICE}')"
            return 1
            ;;
    esac
}

# ------------------------------------------------------------------
# Act according to the state of the service
# ------------------------------------------------------------------
case "$STATE" in
    running)
        # A running service offers the stop and restart actions in an
        # actionable notification.
        ACTION=$(notify_action "$(msg_text NOTIFY_TITLE 'Services')" \
            "$(msg_service MSG_ACTION_QUERY 'Service {SERVICE} is running. What do you want to do?')" \
            "stop=$(msg_text ACTION_STOP 'Stop')" \
            "restart=$(msg_text ACTION_RESTART 'Restart')")

        case "$ACTION" in
            stop)
                log INFO "Stopping service: $SERVICE"
                run_action stop
                ;;
            restart)
                log INFO "Restarting service: $SERVICE"
                run_action restart
                ;;
            *)
                log INFO "No action selected for service: $SERVICE"
                ;;
        esac
        ;;
    stopped)
        log INFO "Starting service: $SERVICE"
        run_action start
        ;;
    disabled)
        log INFO "Enabling service: $SERVICE"
        run_action enable
        ;;
esac

exit 0
