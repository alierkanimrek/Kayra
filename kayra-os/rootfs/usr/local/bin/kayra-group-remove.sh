#!/usr/bin/env bash
#
# kayra-group-remove.sh - Remove the user from a group via a fuzzel menu.
#
# Lists the groups the user is a member of and removes the selected one with
# "gpasswd -d" through the kayra-group-services job socket. Every group except
# the primary group can be removed. The kayra-admin group is protected: it is
# not listed and the service refuses to remove it. Removing the user from wheel
# needs a confirmation, because it removes sudo/polkit access. After a change
# the notification reminds the user to log out and in again; usermod/gpasswd
# do not update the supplementary groups of the running session.
#
# The service runs as root, so the script needs neither pkexec nor a root
# helper. The job socket is only reachable for members of the fixed
# "kayra-admin" group. A regular user exits silently; when the service is not
# reachable an admin gets a translated error notification.
#
# Usage: kayra-group-remove.sh [fuzzel parameters...]
#
# Used commands: fuzzel, pkill, id, awk, printf (via groups-client.sh:
#                socat, flock, jq)
#

set -euo pipefail
export LC_ALL=C.UTF-8

source /usr/local/lib/kayra/admin.sh
require_kayra_admin

source /usr/local/lib/kayra/i18n.sh
declare -n MSG=i18n_GROUP_MANAGEMENT

source /usr/local/lib/kayra/klog.sh
source /usr/local/lib/kayra/notify.sh
source /usr/local/lib/kayra/groups-client.sh

# The user the group is removed from.
TARGET_USER="$(id -un)"

# Material symbols used in front of every menu entry.
ICON_MEMBER=$(printf '%b' '\U000E7EF')  # group

# Groups that must never be removed through this menu. kayra-admin is the
# authorization boundary of the Kayra root services: without it the service,
# power and log menus disappear after the next login. The service refuses the
# group as well, so a direct request can not bypass the menu.
PROTECTED_GROUPS=(kayra-admin)

# Groups that may be removed only after a confirmation. wheel grants
# sudo/polkit access.
CONFIRM_GROUPS=(wheel)

# Returns the message of a key, the fallback is used when the key is
# missing. The fallback is passed as a separate argument, a placeholder
# inside a ${...:-default} expression would break the expansion.
msg_text() {
    local value="${MSG[$1]}"
    [ -n "$value" ] || value="$2"
    printf '%s' "$value"
}

manager_unavailable() {
    log ERROR "kayra-group-services is not reachable"
    notify_error "$(msg_text TITLE 'Group Management')" \
        "$(msg_text MSG_MANAGER_UNAVAILABLE 'Group service is not running.')"
}

# Returns the terminal event of the last request, empty when none arrived.
terminal_event() {
    local line event result=""

    for line in "${GROUPS_EVENTS[@]}"; do
        event=$("${GROUPS_JQ:-jq}" -r '.event // empty' <<<"$line" 2>/dev/null)
        case "$event" in
            added|removed|unchanged|notfound|failed) result=$event ;;
        esac
    done
    printf '%s' "$result"
}

# Returns 0 when the group is one of the given names.
group_in_list() {
    local group=$1 item
    shift

    for item in "$@"; do
        [[ "$item" == "$group" ]] && return 0
    done
    return 1
}

# ------------------------------------------------------------------
# Read the group list from the service manager
# ------------------------------------------------------------------
if ! GROUP_DATA=$(groups_list "$TARGET_USER"); then
    manager_unavailable
    exit 1
fi

# The primary group is not part of the list because it cannot be changed.
PRIMARY_GROUP=$(id -gn "$TARGET_USER")

# The protected groups are hidden as well; the space padded pattern is used
# with index() so that no regular expression matching is needed.
PROTECTED_PATTERN=" ${PROTECTED_GROUPS[*]} "

mapfile -t USER_GROUPS < <(
    awk -F'\t' -v primary="$PRIMARY_GROUP" -v protected="$PROTECTED_PATTERN" \
        '$2 == "1" && $1 != primary && index(protected, " " $1 " ") == 0 { print $1 }' <<<"$GROUP_DATA"
)

if [[ ${#USER_GROUPS[@]} -eq 0 ]]; then
    log INFO "No removable groups found for user $TARGET_USER"
    notify_info "${MSG[TITLE]}" "${MSG[NO_GROUPS_TO_REMOVE]}"
    exit 0
fi

# Menu entries: the icon in front of the group name.
declare -a MENU_LINES=()
for group in "${USER_GROUPS[@]}"; do
    MENU_LINES+=("$ICON_MEMBER $group")
done

# Window width of the longest menu entry (icon counted as 3 characters).
MAX_WIDTH=$(printf '%s\n' "${MENU_LINES[@]}" | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')

# Close any open fuzzel windows
pkill -x fuzzel 2>/dev/null || true

SELECTED=$(printf '%s\n' "${MENU_LINES[@]}" | fuzzel --dmenu --log-no-syslog --minimal-lines \
    --lines="${#MENU_LINES[@]}" --width="$MAX_WIDTH" --hide-prompt "$@") || true

[[ -z "$SELECTED" ]] && exit 0

# Strip the icon and keep the group name.
SELECTED_GROUP="${SELECTED#* }"

[[ -z "$SELECTED_GROUP" ]] && exit 0

# Removing the user from a privileged group needs an explicit confirmation.
# A closed or expired notification cancels the operation.
if group_in_list "$SELECTED_GROUP" "${CONFIRM_GROUPS[@]}"; then
    CONFIRM_BODY=$(i18n_template \
        "$(msg_text WHEEL_REMOVE_CONFIRM "The 'wheel' group grants sudo/polkit access. Removing {USER} from '{GROUP}' removes this access. Continue?")" \
        USER="$TARGET_USER" GROUP="$SELECTED_GROUP")

    CONFIRM_ACTION=$(notify_action "${MSG[TITLE]}" "$CONFIRM_BODY" \
        "remove=$(msg_text ACTION_REMOVE 'Remove')" \
        "cancel=$(msg_text ACTION_CANCEL 'Cancel')") || CONFIRM_ACTION=""

    if [[ "$CONFIRM_ACTION" != "remove" ]]; then
        log INFO "Removal of user $TARGET_USER from group $SELECTED_GROUP cancelled"
        exit 0
    fi
fi

log INFO "Removing user $TARGET_USER from group $SELECTED_GROUP"

if ! groups_remove "$TARGET_USER" "$SELECTED_GROUP"; then
    manager_unavailable
    exit 1
fi

if ! groups_result_ok; then
    log WARN "Failed to remove user $TARGET_USER from group $SELECTED_GROUP"
    notify_error "${MSG[TITLE]}" \
        "$(i18n_template "${MSG[REMOVE_FAILED]}" GROUP="$SELECTED_GROUP")"
    exit 1
fi

# usermod/gpasswd do not update the supplementary groups of the running
# session, so a successful change needs a new login.
RELOGIN_NOTE="$(msg_text RELOGIN_REQUIRED 'Log out and sign in again for the change to take effect.')"

case "$(terminal_event)" in
    removed)
        log INFO "User $TARGET_USER removed from group $SELECTED_GROUP"
        notify_ok "${MSG[TITLE]}" \
            "$(i18n_template "${MSG[GROUP_REMOVED]}" USER="$TARGET_USER" GROUP="$SELECTED_GROUP") $RELOGIN_NOTE"
        ;;
    unchanged)
        log INFO "User $TARGET_USER is not a member of group $SELECTED_GROUP"
        ;;
    *)
        log INFO "User $TARGET_USER removed from group $SELECTED_GROUP"
        notify_ok "${MSG[TITLE]}" \
            "$(i18n_template "${MSG[GROUP_REMOVED]}" USER="$TARGET_USER" GROUP="$SELECTED_GROUP") $RELOGIN_NOTE"
        ;;
esac
