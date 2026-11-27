#!/usr/bin/env bash
#
# kayra-show-service-logs.sh - Follows the log of one runit service.
#
# This script is meant to run inside a terminal window, for example from the
# "Show log records" button of kayra-toggle-service.sh:
#
#   kayra-show-service-logs.sh <service-name>
#
# It connects to the kayra-system-logs socket (0660 root:kayra-admin) and
# streams the last 20 log lines followed by new lines (tail -F). The log
# service runs as root, so the user does not need read access to /var/log.
#
# The connection stays open until the terminal is closed or Ctrl+C is pressed.
# A regular user exits silently before the socket is opened.
#
# Usage: kayra-show-service-logs.sh <service-name>
#
# Used commands: socat (via services-client.sh: jq, cat, printf), sleep
#

set -uo pipefail

export LC_ALL=C.UTF-8

source /usr/local/lib/kayra/admin.sh
require_kayra_admin

# The language file may not define this array yet on a system where only the
# scripts were updated. An empty array lets the fallback strings work.
declare -A i18n_SHOW_SERVICE_LOGS=()

source /usr/local/lib/kayra/i18n.sh
declare -n MSG=i18n_SHOW_SERVICE_LOGS

source /usr/local/lib/kayra/klog.sh
source /usr/local/lib/kayra/services-client.sh

# Returns the message of a key, the fallback is used when the key is
# missing. The fallback is passed as a separate argument, a placeholder
# inside a ${...:-default} expression would break the expansion.
msg_text() {
    local value="${MSG[$1]-}"
    [ -n "$value" ] || value="$2"
    printf '%s' "$value"
}

SERVICE="${1:-}"

if [ -z "$SERVICE" ]; then
    log ERROR "No service name given"
    printf '%s\n' "$(msg_text MSG_USAGE 'Usage: kayra-show-service-logs.sh <service-name>')" >&2
    exit 1
fi

# Only plain service names are accepted, no path traversal.
case "$SERVICE" in
    */*|.|..)
        log ERROR "Invalid service name: $SERVICE"
        printf '%s\n' "$(msg_text MSG_INVALID_SERVICE 'Invalid service name')" >&2
        sleep 3
        exit 1
        ;;
esac

if [ ! -d "/etc/sv/$SERVICE" ]; then
    log WARN "Service directory not found: /etc/sv/$SERVICE"
    printf '%s\n' "$(msg_text MSG_NOT_FOUND 'Service not found')" >&2
    sleep 3
    exit 1
fi

printf '%s: %s\n' "$(msg_text LABEL_SERVICE 'Service')" "$SERVICE"
printf '%s\n\n' \
    "$(msg_text MSG_FOLLOWING 'Showing the last 20 log lines and following new ones. Press Ctrl+C to close.')"

if ! services_logs "$SERVICE"; then
    log ERROR "kayra-system-logs is not reachable"
    printf '%s\n' "$(msg_text MSG_LOG_UNAVAILABLE 'Log service is not running')" >&2
    sleep 5
    exit 1
fi

exit 0
