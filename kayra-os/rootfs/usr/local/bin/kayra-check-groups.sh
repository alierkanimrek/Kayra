#!/usr/bin/env bash
#
# kayra-check-groups.sh - Add the missing required groups of the current user.
#
# The work is done by the kayra-group-services job socket: the service reads the
# required_groups list from /etc/default/kayra.conf, finds the groups that exist
# on the system and are missing for the user, and adds them with "usermod -aG".
# This script only sends the request; it runs at session start, so no
# notification and no confirmation is shown when the job succeeds.
#
# The check is skipped when the auto_group_management setting is "false": the
# user then manages the groups by hand and nothing is added automatically.
#
# A notification is shown only when the service is not reachable or the job
# fails.
#
# Usage: kayra-check-groups.sh
#
# Used commands: notify-send (via notify.sh), socat, flock, jq
#                (via groups-client.sh), settings-conf.sh
#

set -uo pipefail
export LC_ALL=C.UTF-8

source /usr/local/lib/kayra/i18n.sh
declare -n MSG=i18n_CHECK_GROUPS

source /usr/local/lib/kayra/klog.sh
source /usr/local/lib/kayra/notify.sh
source /usr/local/lib/kayra/settings-conf.sh
source /usr/local/lib/kayra/groups-client.sh

# Automatic group management: when "false" the user manages the groups by hand
# and nothing is added. Default is "true".
AUTO_GROUP_MANAGEMENT="$(conf_get auto_group_management | head -n1 || true)"
[[ -z "$AUTO_GROUP_MANAGEMENT" ]] && AUTO_GROUP_MANAGEMENT="true"

if [[ "$AUTO_GROUP_MANAGEMENT" != "true" ]]; then
    log INFO "Automatic group management is disabled, skipping the group check"
    exit 0
fi

# The user whose groups are checked.
TARGET_USER="$(id -un)"

# The service may not be up yet when the session starts, so retry a few times
# before giving up.
RC=1
for attempt in 1 2 3; do
    if groups_fix "$TARGET_USER"; then
        RC=0
        break
    fi
    log WARN "kayra-group-services is not reachable (attempt $attempt)"
    [[ "$attempt" -lt 3 ]] && sleep 1
done

if (( RC != 0 )) || ! groups_result_ok; then
    log WARN "Could not add the missing groups for user $TARGET_USER"
    notify_error "${MSG[TITLE]}" "${MSG[MSG_FAILED]}"
    exit 0
fi

ADDED=$("${GROUPS_JQ:-jq}" -r '(.data.added // []) | join(",")' \
    <<<"$GROUPS_RES" 2>/dev/null || true)

log INFO "Required groups checked for user $TARGET_USER (added: ${ADDED:-none})"
exit 0
