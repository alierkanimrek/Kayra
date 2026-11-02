#!/usr/bin/env bash
#
# group-remove.sh - Remove the user from a group via a fuzzel menu.
#
# Lists the groups the user is a member of and removes the selected one
# with "usermod -G". Exception groups (listed in EXCEPTION_GROUPS) are shown
# with a lock icon and cannot be removed.
#
# Usage: group-remove.sh [fuzzel parameters...]
#
# Used commands: fuzzel, notify-send, pkexec, usermod, id, getent, pkill,
#                printf, awk, sort

set -euo pipefail
export LC_ALL=C.UTF-8

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_GROUP_MANAGEMENT

source "$(dirname "$0")/klog.sh"
source "$(dirname "$0")/notify.sh"

# The user the group is removed from. SUDO_USER is used when the script runs
# through pkexec, otherwise the current user.
TARGET_USER="${SUDO_USER:-${USER:-$(id -un)}}"

# Material symbols used in front of every menu entry.
ICON_MEMBER=$(printf '%b' '\U0000E7EF')
ICON_EXCEPTION=$(printf '%b' '\U0000E88F')

# Exception groups - the user cannot be removed from these.
EXCEPTION_GROUPS=(audio video input users socklog)

# Exception groups as one space padded list for an exact match.
EXCEPTION_LIST=" ${EXCEPTION_GROUPS[*]} "

# Returns 0 when the given group is an exception group. The match is exact,
# so a group name is never treated as a pattern.
is_exception() {
    printf '%s\n' "$1" | awk -v list="$EXCEPTION_LIST" 'index(list, " " $0 " ") > 0 { found = 1 } END { exit !found }'
}

# Close any open fuzzel windows
pkill -x fuzzel 2>/dev/null || true

# Gather group information. The primary group is not part of the list because
# it cannot be changed with usermod -G.
PRIMARY_GROUP=$(id -gn "$TARGET_USER")

mapfile -t USER_GROUPS < <(
    id -Gn "$TARGET_USER" | tr ' ' '\n' | awk -v primary="$PRIMARY_GROUP" 'NF && $0 != primary'
)

if [[ ${#USER_GROUPS[@]} -eq 0 ]]; then
    log INFO "No removable groups found for user $TARGET_USER"
    notify_info "${MSG[TITLE]}" "${MSG[NO_GROUPS_TO_REMOVE]}"
    exit 0
fi

# Menu entries: the icon in front of the group name.
declare -a MENU_LINES=()
for group in "${USER_GROUPS[@]}"; do
    if is_exception "$group"; then
        MENU_LINES+=("$ICON_EXCEPTION $group")
    else
        MENU_LINES+=("$ICON_MEMBER $group")
    fi
done

# Window width of the longest menu entry (icon counted as 3 characters).
MAX_WIDTH=$(printf '%s\n' "${MENU_LINES[@]}" | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')

SELECTED=$(printf '%s\n' "${MENU_LINES[@]}" | fuzzel --dmenu --log-no-syslog --minimal-lines \
    --lines="${#MENU_LINES[@]}" --width="$MAX_WIDTH" --hide-prompt "$@") || true

[[ -z "$SELECTED" ]] && exit 0

# Strip the icon and keep the group name.
SELECTED_GROUP="${SELECTED#* }"

[[ -z "$SELECTED_GROUP" ]] && exit 0

# If exception group: do not perform the operation.
if is_exception "$SELECTED_GROUP"; then
    log INFO "Group $SELECTED_GROUP is an exception group, removal skipped for user $TARGET_USER"
    notify_warn "${MSG[TITLE]}" \
        "$(i18n_template "${MSG[EXCEPTION_GROUP]}" GROUP="$SELECTED_GROUP" USER="$TARGET_USER")"
    exit 0
fi

# New supplementary group list without the removed group. The primary group
# is kept so the list never becomes empty.
NEW_LIST=$(printf '%s\n' "${USER_GROUPS[@]}" | awk -v removed="$SELECTED_GROUP" -v primary="$PRIMARY_GROUP" '
    $0 != removed && $0 != primary { list = (list == "" ? $0 : list "," $0) }
    END { print list }
')

[[ -z "$NEW_LIST" ]] && NEW_LIST="$PRIMARY_GROUP"

log INFO "Removing user $TARGET_USER from group $SELECTED_GROUP"

# Remove from group using usermod with the new group list.
if pkexec usermod -G "$NEW_LIST" "$TARGET_USER"; then
    log INFO "User $TARGET_USER removed from group $SELECTED_GROUP"
    notify_ok "${MSG[TITLE]}" \
        "$(i18n_template "${MSG[GROUP_REMOVED]}" USER="$TARGET_USER" GROUP="$SELECTED_GROUP")"
else
    log WARN "Failed to remove user $TARGET_USER from group $SELECTED_GROUP"
    notify_error "${MSG[TITLE]}" \
        "$(i18n_template "${MSG[REMOVE_FAILED]}" GROUP="$SELECTED_GROUP")"
fi
