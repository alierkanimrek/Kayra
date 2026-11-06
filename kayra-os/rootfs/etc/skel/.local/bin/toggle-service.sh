#!/usr/bin/env bash
#
# toggle-service.sh - Toggles the running state of a runit service.
#
# Called from show-services.sh when a service is selected:
#   toggle-service.sh <service-name>
#   e.g. toggle-service.sh sshd
#
# * Service definition: /etc/sv/<name>
# * Enabled service:   /var/service/<name> (symlink handled by runsvdir)
#
# Toggle rules:
#   running  -> the service is stopped          (sv down)
#   stopped  -> the service is started          (sv up)
#   disabled -> the service is enabled + started (symlink + sv up)
#
# The services listed in PROTECTED_SERVICES are never stopped, stopping
# them would break the running session (D-Bus, the greeter, the log
# daemons and the polkit agent). They can still be started.
#
# A protected service is detected before the root helper is started, so no
# password is asked when such a service would be stopped.
#
# The runit control commands need root privileges, they are executed
# through pkexec, so a polkit password dialog is shown while toggling. The
# root helper is the permanent script sv-toggle-helper.sh.
#
# Important instructions:
#   * Only a plain service name is accepted, a name with a path would leave
#     the service directory.
#   * The result of the helper is read from its output: STARTED, STOPPED,
#     ENABLED, PROTECTED, NOTFOUND or FAILED.
#   * The log messages are in English, the notification texts come from the
#     language file (i18n_TOGGLE_SERVICE).
#
# Usage: toggle-service.sh <service-name>
#
# Used commands: pkexec, pgrep, notify-send (via notify.sh)
#

set -uo pipefail

export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "$0")")" && pwd)"

SV_DIR="/etc/sv"
SERVICE_DIR="/var/service"
HELPER="$SCRIPT_DIR/sv-toggle-helper.sh"

# Services that must stay running, they can not be stopped.
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

SERVICE="${1:-}"
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

# ------------------------------------------------------------------
# Protected services are checked before the root helper is called, so
# no password is asked when a protected service would be stopped.
# ------------------------------------------------------------------
if [[ " ${PROTECTED_SERVICES[*]} " == *" $SERVICE "* ]] && sv_service_is_running "$SERVICE"; then
    log WARN "Service $SERVICE is protected, it can not be stopped"
    notify_error "$(msg_text NOTIFY_TITLE 'Services')" \
        "$(msg_service MSG_PROTECTED 'Service {SERVICE} can not be stopped')"
    exit 1
fi

# ------------------------------------------------------------------
# Toggle the service with the root helper
# ------------------------------------------------------------------
if ! command -v pkexec >/dev/null 2>&1; then
    log ERROR "pkexec is not installed"
    notify_error "$(msg_text NOTIFY_TITLE 'Services')" \
        "$(msg_service MSG_FAILED 'Failed to toggle service {SERVICE}')"
    exit 1
fi

RESULT=$(pkexec /bin/sh "$HELPER" "$SERVICE" "${PROTECTED_SERVICES[@]}" 2>/dev/null)
[ -z "$RESULT" ] && RESULT="FAILED"

case "$RESULT" in
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
    ENABLED)
        log INFO "Service $SERVICE enabled and started"
        notify_ok "$(msg_text NOTIFY_TITLE 'Services')" \
            "$(msg_service MSG_ENABLED 'Service {SERVICE} enabled and started')"
        ;;
    PROTECTED)
        log WARN "Service $SERVICE is protected, it can not be stopped"
        notify_error "$(msg_text NOTIFY_TITLE 'Services')" \
            "$(msg_service MSG_PROTECTED 'Service {SERVICE} can not be stopped')"
        exit 1
        ;;
    NOTFOUND)
        log WARN "Service not found: $SERVICE"
        notify_error "$(msg_text NOTIFY_TITLE 'Services')" \
            "$(msg_service MSG_NOT_FOUND 'Service not found: {SERVICE}')"
        exit 1
        ;;
    *)
        log ERROR "Failed to toggle service: $SERVICE"
        notify_error "$(msg_text NOTIFY_TITLE 'Services')" \
            "$(msg_service MSG_FAILED 'Failed to toggle service {SERVICE}')"
        exit 1
        ;;
esac

exit 0
