#!/usr/bin/env bash
#
# kayra-fix-groups.sh - Add the current user to the required system groups.
#
# The work is done by the kayra-group-services job socket: the service reads the
# required_groups list from /etc/default/kayra.conf, finds the groups that exist
# on the system and are missing for the user, and adds them with "usermod -aG".
# This script only sends the request and reports the result with a notification.
#
# The service runs as root, so the script needs neither pkexec nor a root
# helper. When the service is not reachable a translated error notification is
# shown.
#
# Usage: kayra-fix-groups.sh
#
# Used commands: notify-send (via notify.sh), socat, flock, jq
#                (via groups-client.sh)
#

set -euo pipefail
export LC_ALL=C.UTF-8

source /usr/local/lib/kayra/i18n.sh
declare -n MSG=i18n_FIX_GROUPS

source /usr/local/lib/kayra/klog.sh
source /usr/local/lib/kayra/notify.sh
source /usr/local/lib/kayra/groups-client.sh

# The user the groups are added to.
TARGET_USER="$(id -un)"

log INFO "Requesting the missing required groups for user $TARGET_USER"

if ! groups_fix "$TARGET_USER" || ! groups_result_ok; then
    log WARN "Failed to add the groups for user $TARGET_USER"
    notify_error "${MSG[TITLE_FAILED]}" "${MSG[MSG_FAILED]}"
    exit 1
fi

ADDED=$("${GROUPS_JQ:-jq}" -r '(.data.added // []) | join(",")' \
    <<<"$GROUPS_RES" 2>/dev/null || true)

log INFO "Groups ensured for user $TARGET_USER (added: ${ADDED:-none})"
notify_ok "${MSG[TITLE_SUCCESS]}" "${MSG[MSG_SUCCESS]}"
