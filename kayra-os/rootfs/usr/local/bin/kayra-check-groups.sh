#!/usr/bin/env bash
#
# kayra-check-groups.sh - Check the group membership of the current user.
#
# Compares the groups the user belongs to with the required system groups
# and shows a notification when a group is missing. The notification carries
# a button that adds the missing groups. The button is handled by this
# script, so no swaync script rule is needed for it.
#
# The required group list is system wide data read from /etc/default/kayra.conf
# (key: required_groups) with settings-conf.sh, so it stays in sync with
# kayra-fix-groups.sh and kayra-group-remove.sh. The check is skipped when the
# auto_group_management setting is "false" (the user manages groups manually).
#
# Usage: kayra-check-groups.sh
#
# Used commands: notify-send, id, cut, tr, sort, awk, printf, settings-conf.sh

set -euo pipefail
export LC_ALL=C.UTF-8

source /usr/local/lib/kayra/i18n.sh
declare -n MSG=i18n_CHECK_GROUPS

source /usr/local/lib/kayra/klog.sh
source /usr/local/lib/kayra/notify.sh
source /usr/local/lib/kayra/settings-conf.sh

# Automatic group management: when "false" the user manages the groups by hand
# and no missing-group notification is shown. Default is "true".
AUTO_GROUP_MANAGEMENT="$(conf_get auto_group_management | head -n1 || true)"
[[ -z "$AUTO_GROUP_MANAGEMENT" ]] && AUTO_GROUP_MANAGEMENT="true"

if [[ "$AUTO_GROUP_MANAGEMENT" != "true" ]]; then
    log INFO "Automatic group management is disabled, skipping the group check"
    exit 0
fi

# Required system groups are system wide data read from /etc/default/kayra.conf
# (key: required_groups) so kayra-check-groups.sh, kayra-fix-groups.sh and
# kayra-group-remove.sh always share one list. Group names never contain spaces,
# so plain word splitting is safe here.
REQUIRED_GROUPS_STR="$(system_conf_get required_groups | head -n1 || true)"
REQUIRED_GROUPS=( $REQUIRED_GROUPS_STR )

# The user whose membership is checked.
TARGET_USER="${SUDO_USER:-${USER:-$(id -un)}}"

# The notification is critical, so it stays on the screen until the user
# acts on it or dismisses it.
NOTIFY_URGENCY="critical"

# Groups the user belongs to, as one space padded list for an exact match.
USER_GROUP_LIST=" $(id -Gn "$TARGET_USER" | tr ' ' '\n' | sort -u | tr '\n' ' ')"

# Groups that exist on this system, as one space padded list. A required group
# that is not provided by any installed package (e.g. lpadmin before cups) must
# be ignored, otherwise the notification keeps asking for a group that cannot be
# added.
AVAILABLE_GROUP_LIST=" $(cut -d: -f1 /etc/group | sort -u | tr '\n' ' ')"

# Required groups that exist but the user is not a member of.
mapfile -t MISSING_GROUPS < <(
    printf '%s\n' "${REQUIRED_GROUPS[@]}" | awk -v members="$USER_GROUP_LIST" -v available="$AVAILABLE_GROUP_LIST" '
        index(available, " " $0 " ") > 0 && index(members, " " $0 " ") == 0 { print $0 }
    '
)

if [[ ${#MISSING_GROUPS[@]} -eq 0 ]]; then
    log INFO "All required groups are present for user $TARGET_USER"
    exit 0
fi

MISSING_LIST=$(IFS=,; echo "${MISSING_GROUPS[*]}")

log WARN "User $TARGET_USER is missing the groups: $MISSING_LIST"

# The notification is sent in the background, the script does not wait for
# the user. The kayra-fix-groups.sh is started when the button is pressed.
(
    ACTION=$(notify_action "${MSG[NOTIFY_MSG]}" \
        "$(i18n_template "${MSG[MISSING_GROUPS]}" GROUPS="$MISSING_LIST")" \
        "fix=$(i18n_template "${MSG[NOTIFY_ACTION]}")")

    if [[ "$ACTION" == "fix" ]]; then
        log INFO "The group fix was requested, starting fix-groups.sh"
        "/usr/local/bin/kayra-fix-groups.sh"
    fi
) &

exit 0
