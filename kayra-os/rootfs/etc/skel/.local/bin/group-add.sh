#!/usr/bin/env bash
#
# group-add.sh - Add the user to a group via a fuzzel menu.
#
# Lists the groups the user is not a member of and adds the selected one
# with "usermod -aG". Groups whose name starts with an underscore are
# system internal groups and are hidden from the menu. The menu entries are
# plain group names, without icons.
#
# Usage: group-add.sh [fuzzel parameters...]

set -euo pipefail
export LC_ALL=C.UTF-8

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_GROUP_MANAGEMENT

source "$(dirname "$0")/klog.sh"
source "$(dirname "$0")/notify.sh"

# The user the group is added to. SUDO_USER is used when the script runs
# through pkexec, otherwise the current user.
TARGET_USER="${SUDO_USER:-${USER:-$(id -un)}}"

# Groups whose name starts with "_" are internal and are not offered.
HIDDEN_GROUP_PREFIX="_"

# Groups the user is not a member of, sorted by name.
# getent prints "name:password:gid:members"; the member check uses the
# group list of the user, because the primary group is not listed in the
# members field.
USER_GROUP_LIST=" $(id -Gn "$TARGET_USER" | tr ' ' '\n' | sort -u | tr '\n' ' ')"

mapfile -t ADDABLE_GROUPS < <(
    getent group | awk -F: -v members="$USER_GROUP_LIST" -v prefix="$HIDDEN_GROUP_PREFIX" '
        $1 ~ "^" prefix { next }
        index(members, " " $1 " ") == 0 { print $1 }
    ' | sort -u
)

if [[ ${#ADDABLE_GROUPS[@]} -eq 0 ]]; then
    log INFO "No addable groups found for user $TARGET_USER"
    notify_info "${MSG[TITLE]}" "${MSG[NO_GROUPS_AVAILABLE]}"
    exit 0
fi

# Menu entries are the plain group names (no icon).
declare -a MENU_LINES=("${ADDABLE_GROUPS[@]}")

# Window width of the longest menu entry, using the shared project formula.
# The entries have no icon, but the formula is kept unchanged so the extra
# slack (-1 + 3) prevents fuzzel from clipping the longest group name.
MAX_WIDTH=$(printf '%s\n' "${MENU_LINES[@]}" | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')

# Close any open fuzzel windows
pkill -x fuzzel 2>/dev/null || true

SELECTED=$(printf '%s\n' "${MENU_LINES[@]}" | fuzzel --dmenu --log-no-syslog --minimal-lines \
    --lines="${#MENU_LINES[@]}" --width="$MAX_WIDTH" --hide-prompt "$@") || true

[[ -z "$SELECTED" ]] && exit 0

# The selected line is the group name.
SELECTED_GROUP="$SELECTED"

[[ -z "$SELECTED_GROUP" ]] && exit 0

log INFO "Adding user $TARGET_USER to group $SELECTED_GROUP"

# Add to group using usermod
if pkexec usermod -aG "$SELECTED_GROUP" "$TARGET_USER"; then
    log INFO "User $TARGET_USER added to group $SELECTED_GROUP"
    notify_ok "${MSG[TITLE]}" \
        "$(i18n_template "${MSG[GROUP_ADDED]}" USER="$TARGET_USER" GROUP="$SELECTED_GROUP")"
else
    log WARN "Failed to add user $TARGET_USER to group $SELECTED_GROUP"
    notify_error "${MSG[TITLE]}" \
        "$(i18n_template "${MSG[ADD_FAILED]}" GROUP="$SELECTED_GROUP")"
fi
