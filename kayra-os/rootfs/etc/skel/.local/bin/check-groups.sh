#!/usr/bin/env bash
#
# check-groups.sh - Check the group membership of the current user.
#
# Compares the groups the user belongs to with the required system groups
# and shows a notification when a group is missing. The notification carries
# a button that adds the missing groups. The button is handled by this
# script, so no swaync script rule is needed for it.
#
# Usage: check-groups.sh
#
# Used commands: notify-send, id, tr, sort, awk, printf

set -euo pipefail
export LC_ALL=C.UTF-8

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_CHECK_GROUPS

source "$(dirname "$0")/klog.sh"
source "$(dirname "$0")/notify.sh"

# Required system groups. Add a group here when the desktop needs it.
REQUIRED_GROUPS=(users audio video input socklog)

# The user whose membership is checked.
TARGET_USER="${SUDO_USER:-${USER:-$(id -un)}}"

# The notification is critical, so it stays on the screen until the user
# acts on it or dismisses it.
NOTIFY_URGENCY="critical"

# Groups the user belongs to, as one space padded list for an exact match.
USER_GROUP_LIST=" $(id -Gn "$TARGET_USER" | tr ' ' '\n' | sort -u | tr '\n' ' ')"

# Required groups the user is not a member of.
mapfile -t MISSING_GROUPS < <(
    printf '%s\n' "${REQUIRED_GROUPS[@]}" | awk -v members="$USER_GROUP_LIST" '
        index(members, " " $0 " ") == 0 { print $0 }
    '
)

if [[ ${#MISSING_GROUPS[@]} -eq 0 ]]; then
    log INFO "All required groups are present for user $TARGET_USER"
    exit 0
fi

MISSING_LIST=$(IFS=,; echo "${MISSING_GROUPS[*]}")

log WARN "User $TARGET_USER is missing the groups: $MISSING_LIST"

# The notification is sent in the background, the script does not wait for
# the user. The fix-groups.sh is started when the button is pressed.
(
    ACTION=$(notify_action "${MSG[NOTIFY_MSG]}" \
        "$(i18n_template "${MSG[MISSING_GROUPS]}" GROUPS="$MISSING_LIST")" \
        "fix=$(i18n_template "${MSG[NOTIFY_ACTION]}")")

    if [[ "$ACTION" == "fix" ]]; then
        log INFO "The group fix was requested, starting fix-groups.sh"
        "$HOME/.local/bin/fix-groups.sh"
    fi
) &

exit 0
