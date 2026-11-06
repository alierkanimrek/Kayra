#!/usr/bin/env bash
#
# fix-groups.sh - Add the current user to the required system groups.
#
# Adds the groups the user is missing to the membership list with
# "usermod -aG" and reports the result with a notification. It is started by
# the action button of the check-groups.sh notification.
#
# Usage: fix-groups.sh
#
# Used commands: notify-send, id, tr, sort, awk, printf, pkexec, usermod

set -euo pipefail
export LC_ALL=C.UTF-8

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_FIX_GROUPS

source "$(dirname "$0")/klog.sh"
source "$(dirname "$0")/notify.sh"

# Required system groups. Add a group here when the desktop needs it.
REQUIRED_GROUPS=(users audio video input socklog lpadmin bluetooth)

# The user the groups are added to.
TARGET_USER="${SUDO_USER:-${USER:-$(id -un)}}"

# Groups the user belongs to, as one space padded list for an exact match.
USER_GROUP_LIST=" $(id -Gn "$TARGET_USER" | tr ' ' '\n' | sort -u | tr '\n' ' ')"

# Required groups the user is not a member of.
mapfile -t MISSING_GROUPS < <(
    printf '%s\n' "${REQUIRED_GROUPS[@]}" | awk -v members="$USER_GROUP_LIST" '
        index(members, " " $0 " ") == 0 { print $0 }
    '
)

if [[ ${#MISSING_GROUPS[@]} -eq 0 ]]; then
    log INFO "No missing groups for user $TARGET_USER, nothing to add"
    notify_ok "${MSG[TITLE_SUCCESS]}" "${MSG[MSG_SUCCESS]}"
    exit 0
fi

MISSING_LIST=$(IFS=,; echo "${MISSING_GROUPS[*]}")

log INFO "Adding user $TARGET_USER to the groups: $MISSING_LIST"

if pkexec usermod -aG "$MISSING_LIST" "$TARGET_USER"; then
    log INFO "Groups added for user $TARGET_USER: $MISSING_LIST"
    # Info notification only, no action, so this does not retrigger the script.
    notify_ok "${MSG[TITLE_SUCCESS]}" "${MSG[MSG_SUCCESS]}"
else
    log WARN "Failed to add the groups for user $TARGET_USER: $MISSING_LIST"
    notify_error "${MSG[TITLE_FAILED]}" "${MSG[MSG_FAILED]}"
fi
