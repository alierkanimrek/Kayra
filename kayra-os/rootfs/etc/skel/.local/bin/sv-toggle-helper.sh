#!/bin/sh
#
# sv-toggle-helper.sh - Start, stop or enable a runit service.
#
# Root helper of toggle-service.sh. The runit control commands need root
# privileges, so the script is called through pkexec and a polkit password
# dialog is shown while the service is toggled.
#
# The script prints the result of the action, one of:
#   STARTED   the service was started
#   STOPPED   the service was stopped
#   ENABLED   the service was enabled and started
#   PROTECTED the service must not be stopped
#   NOTFOUND  the service is not installed
#   FAILED    the service could not be changed
#
# Important instructions:
#   * The script changes the state of a service, so it may only be called
#     after the user has selected the service in the menu.
#   * The services given as arguments are protected, they are never
#     stopped, they can only be started.
#   * The service name must be a plain name, it is used as a path part.
#
# Usage: sv-toggle-helper.sh <service-name> [protected-service...]
#
# Used commands: sv, ln, sleep
#

set -u

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
