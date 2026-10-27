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
# through pkexec, so a polkit password dialog is shown while toggling.
#
# Usage: toggle-service.sh <service-name>
#
export LC_ALL=C.UTF-8
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "$0")")" && pwd)"
SV_DIR="/etc/sv"
SERVICE_DIR="/var/service"

# Services that must stay running, they can not be stopped.
PROTECTED_SERVICES=(
    dbus
    greetd
    socklog-unix
    nanoklogd
    polkitd
)

# shellcheck source=/dev/null
source "$SCRIPT_DIR/i18n.sh"
declare -n MSG=i18n_TOGGLE_SERVICE

# Returns the message of a key, the fallback is used when the key is
# missing. The fallback is passed as a separate argument, a placeholder
# inside a ${...:-default} expression would break the expansion.
msg_text() {
    local value="${MSG[$1]}"
    [ -n "$value" ] || value="$2"
    printf '%s' "$value"
}

# shellcheck source=/dev/null
[ -f "$SCRIPT_DIR/klog.sh" ] && . "$SCRIPT_DIR/klog.sh"
if ! command -v log >/dev/null 2>&1; then
    log() { printf '%s\n' "$*"; }
fi

SERVICE="${1:-}"
if [ -z "$SERVICE" ]; then
    echo "$(msg_text MSG_USAGE 'Usage: toggle-service.sh <service-name>')" >&2
    exit 1
fi

# Only plain service names are accepted, no path traversal.
case "$SERVICE" in
    */*|.|..)
        log ERROR "Invalid service name: $SERVICE"
        echo "$(i18n_template "$(msg_text MSG_NOT_FOUND 'Service not found: {SERVICE}')" "SERVICE=$SERVICE")" >&2
        exit 1
        ;;
esac

if [ ! -d "$SV_DIR/$SERVICE" ]; then
    log WARN "Service directory not found: $SV_DIR/$SERVICE"
    echo "$(i18n_template "$(msg_text MSG_NOT_FOUND 'Service not found: {SERVICE}')" "SERVICE=$SERVICE")" >&2
    exit 1
fi

# ------------------------------------------------------------------
# Checks that do not need root privileges
# ------------------------------------------------------------------
# Checks if the service is one of the protected services.
is_protected() {
    local name="$1" service
    for service in "${PROTECTED_SERVICES[@]}"; do
        [ "$service" = "$name" ] && return 0
    done
    return 1
}

# Checks if the service is running without root privileges: the program
# that the run script starts is searched in the process table.
service_is_running() {
    local name="$1" run_file line token base

    run_file="$SV_DIR/$name/run"
    [ -r "$run_file" ] || return 1

    line=$(grep -E '^[[:space:]]*exec[[:space:]]+' "$run_file" 2>/dev/null | tail -n 1)
    [ -n "$line" ] || return 1
    line="${line#exec }"

    for token in $line; do
        # Skip redirections, options, user:group pairs and wrappers.
        case "$token" in
            *'>'*|'<'*) continue ;;
            -*) continue ;;
            *:*) continue ;;
            /*) base="${token##*/}" ;;
            *) base="$token" ;;
        esac
        case "$base" in
            exec|chpst|env|set|su|sh|bash) continue ;;
        esac

        pgrep -x "$base" >/dev/null 2>&1 && return 0
    done

    return 1
}


notify() {
    local urgency="$1" body="$2"
    command -v notify-send >/dev/null 2>&1 || return 0
    if [ "$urgency" = "critical" ]; then
        notify-send -u critical -a "Kayra" "$(msg_text NOTIFY_TITLE 'Services')" "$body"
    else
        notify-send -a "Kayra" "$(msg_text NOTIFY_TITLE 'Services')" "$body"
    fi
}

# ------------------------------------------------------------------
# Toggle the service with a root helper
# ------------------------------------------------------------------
toggle_service() {
    local helper result
    helper=$(mktemp) || return 1

    cat >"$helper" <<'ROOT_HELPER'
#!/bin/sh
# Starts, stops or enables the given runit service.
# Prints one of: STARTED, STOPPED, ENABLED, PROTECTED, NOTFOUND, FAILED
#
# $1    service name
# $2... services that are not allowed to be stopped
name="$1"
shift
protected="$*"
dir="/etc/sv/$name"
svc="/var/service/$name"

is_protected() {
    for p in $protected; do
        [ "$p" = "$name" ] && return 0
    done
    return 1
}

[ -d "$dir" ] || { echo "NOTFOUND"; exit 1; }

if [ -e "$svc" ]; then
    state=$(sv status "$svc" 2>&1 | head -n 1)
    case "$state" in
        run:*)
            # Protected services are never stopped.
            if is_protected; then
                echo "PROTECTED"
                exit 0
            fi
            if sv down "$svc" >/dev/null 2>&1; then
                echo "STOPPED"
                exit 0
            fi
            ;;
        *)
            if sv up "$svc" >/dev/null 2>&1; then
                echo "STARTED"
                exit 0
            fi
            ;;
    esac
    echo "FAILED"
    exit 1
fi

# Not enabled yet: create the service link and start it.
ln -sfn "$dir" "$svc" || { echo "FAILED"; exit 1; }

# runsvdir needs a moment to pick up the new service directory.
i=0
while [ "$i" -lt 6 ]; do
    [ -e "$svc/supervise/ok" ] && break
    sleep 1
    i=$((i + 1))
done

if sv up "$svc" >/dev/null 2>&1; then
    echo "ENABLED"
else
    # runsv starts the service on its own, give it a chance.
    sleep 2
    echo "ENABLED"
fi
ROOT_HELPER

    if ! command -v pkexec >/dev/null 2>&1; then
        rm -f "$helper"
        printf 'FAILED\n'
        return 0
    fi

    result=$(pkexec /bin/sh "$helper" "$SERVICE" "${PROTECTED_SERVICES[@]}" 2>/dev/null)
    rm -f "$helper"

    [ -z "$result" ] && result="FAILED"
    printf '%s\n' "$result"
}

# ------------------------------------------------------------------
# Protected services are checked before the root helper is called, so
# no password is asked when a protected service would be stopped.
# ------------------------------------------------------------------
if is_protected "$SERVICE" && service_is_running "$SERVICE"; then
    log WARN "Service $SERVICE is protected, it can not be stopped"
    notify critical "$(i18n_template "$(msg_text MSG_PROTECTED 'Service {SERVICE} can not be stopped')" "SERVICE=$SERVICE")"
    exit 1
fi

RESULT=$(toggle_service)

case "$RESULT" in
    STARTED)
        log INFO "Service $SERVICE started"
        notify normal "$(i18n_template "$(msg_text MSG_STARTED 'Service {SERVICE} started')" "SERVICE=$SERVICE")"
        ;;
    STOPPED)
        log INFO "Service $SERVICE stopped"
        notify normal "$(i18n_template "$(msg_text MSG_STOPPED 'Service {SERVICE} stopped')" "SERVICE=$SERVICE")"
        ;;
    ENABLED)
        log INFO "Service $SERVICE enabled and started"
        notify normal "$(i18n_template "$(msg_text MSG_ENABLED 'Service {SERVICE} enabled and started')" "SERVICE=$SERVICE")"
        ;;
    PROTECTED)
        log WARN "Service $SERVICE is protected, it can not be stopped"
        notify critical "$(i18n_template "$(msg_text MSG_PROTECTED 'Service {SERVICE} can not be stopped')" "SERVICE=$SERVICE")"
        exit 1
        ;;
    NOTFOUND)
        log WARN "Service not found: $SERVICE"
        notify critical "$(i18n_template "$(msg_text MSG_NOT_FOUND 'Service not found: {SERVICE}')" "SERVICE=$SERVICE")"
        exit 1
        ;;
    *)
        log ERROR "Failed to toggle service: $SERVICE"
        notify critical "$(i18n_template "$(msg_text MSG_FAILED 'Failed to toggle service {SERVICE}')" "SERVICE=$SERVICE")"
        exit 1
        ;;
esac

exit 0
