#!/bin/sh
#
# sv-status-helper.sh - Print the state of every runit service.
#
# This script is the root helper of show-services.sh. It is called through
# pkexec, because the runit control files under /var/service are only
# readable by root. The states are read with "sv status".
#
# The output is one line per service:
#   <service-name><TAB><running|stopped|disabled>
#
#   running   the service is enabled and up
#   stopped   the service is enabled but down
#   disabled  the service is installed but not supervised
#
# Important instructions:
#   * The script only reads the service directories, it never writes
#     anything and it never changes a service.
#   * It is started as root, so it must not depend on the environment of the
#     user session. The service directories are therefore hard coded.
#   * The file is read by root, so it must stay executable and it must not
#     be writable by other users.
#
# Used commands: sv, head
#

set -u

SV_DIR="/etc/sv"
SERVICE_DIR="/var/service"

for dir in "$SV_DIR"/*; do
    [ -d "$dir" ] || continue
    name="${dir##*/}"

    if [ -e "$SERVICE_DIR/$name" ]; then
        state=$(sv status "$SERVICE_DIR/$name" 2>&1 | head -n 1)
        case "$state" in
            run:*) state="running" ;;
            *)     state="stopped" ;;
        esac
    else
        state="disabled"
    fi

    printf '%s\t%s\n' "$name" "$state"
done
