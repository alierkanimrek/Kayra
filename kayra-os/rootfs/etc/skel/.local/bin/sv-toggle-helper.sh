#!/bin/sh
#
# sv-toggle-helper.sh - Start, stop, restart or enable a runit service.
#
# Root helper of toggle-service.sh. The runit control commands need root
# privileges, so the script is called through pkexec and a polkit password
# dialog is shown while the service is changed.
#
# The script prints the result of the action, one of:
#   STARTED   the service was started
#   STOPPED   the service was stopped
#   RESTARTED the service was restarted
#   ENABLED   the service was enabled and started
#   PROTECTED the service must not be stopped
#   NOTFOUND  the service is not installed
#   FAILED    the service could not be changed
#
# Important instructions:
#   * The script changes the state of a service, so it may only be called
#     after the user has selected the service and the action in the menu.
#   * The services given as arguments are protected, they are never
#     stopped or restarted, they can only be started or enabled.
#   * The service name must be a plain name, it is used as a path part.
#
# Usage: sv-toggle-helper.sh <action> <service-name> [protected-service...]
#   action: start | stop | restart | enable
#
# Used commands: sv, ln, sleep, grep
#

set -u

# The action and the service name are required.
[ "$#" -ge 2 ] || { echo "FAILED"; exit 1; }

action="$1"
name="$2"
shift 2 || true
protected="$*"

dir="/etc/sv/$name"
svc="/var/service/$name"

is_protected() {
    for p in $protected; do
        [ "$p" = "$name" ] && return 0
    done
    return 1
}

# Creates the service link when the service is not supervised yet and waits
# until runsv has picked up the new service directory.
enable_link() {
    [ -e "$svc" ] && return 0

    ln -sfn "$dir" "$svc" || { echo "FAILED"; exit 1; }

    # runsvdir needs a moment to pick up the new service directory.
    i=0
    while [ "$i" -lt 6 ]; do
        [ -e "$svc/supervise/ok" ] && break
        sleep 1
        i=$((i + 1))
    done

    return 0
}

[ -d "$dir" ] || { echo "NOTFOUND"; exit 1; }

case "$action" in
    start)
        enable_link
        if sv up "$svc" >/dev/null 2>&1; then
            echo "STARTED"
            exit 0
        fi
        # runsv starts the service on its own, give it a chance.
        sleep 2
        echo "STARTED"
        exit 0
        ;;
    enable)
        enable_link
        sv up "$svc" >/dev/null 2>&1 || true
        # runsv starts the service on its own, give it a chance.
        sleep 2
        echo "ENABLED"
        exit 0
        ;;
    stop)
        is_protected && { echo "PROTECTED"; exit 0; }
        if sv down "$svc" >/dev/null 2>&1; then
            echo "STOPPED"
            exit 0
        fi
        echo "FAILED"
        exit 1
        ;;
    restart)
        is_protected && { echo "PROTECTED"; exit 0; }
        if sv restart "$svc" >/dev/null 2>&1; then
            echo "RESTARTED"
            exit 0
        fi
        # Fall back to a manual down + up when "sv restart" is not available.
        sv down "$svc" >/dev/null 2>&1
        sleep 1
        if sv up "$svc" >/dev/null 2>&1; then
            echo "RESTARTED"
            exit 0
        fi
        echo "FAILED"
        exit 1
        ;;
    *)
        echo "FAILED"
        exit 1
        ;;
esac
