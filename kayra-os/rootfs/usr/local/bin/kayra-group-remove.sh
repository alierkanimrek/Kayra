#!/usr/bin/env bash
#
# kayra-group-remove.sh - Remove the user from a group via a fuzzel menu.
#
# Lists the groups the user is a member of and removes the selected one with
# "gpasswd -d" through the kayra-group-services job socket. Every group except
# the primary group can be removed. The service only refuses the primary group.
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

# ------------------------------------------------------------------
# Read the group list from the service manager
# ------------------------------------------------------------------
if ! GROUP_DATA=$(groups_list "$TARGET_USER"); then
    manager_unavailable
    exit 1
fi

# The primary group is not part of the list because it cannot be changed.
PRIMARY_GROUP=$(id -gn "$TARGET_USER")

mapfile -t USER_GROUPS < <(
    awk -F'\t' -v primary="$PRIMARY_GROUP" \
        '$2 == "1" && $1 != primary { print $1 }' <<<"$GROUP_DATA"
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

case "$(terminal_event)" in
    removed)
        log INFO "User $TARGET_USER removed from group $SELECTED_GROUP"
        notify_ok "${MSG[TITLE]}" \
            "$(i18n_template "${MSG[GROUP_REMOVED]}" USER="$TARGET_USER" GROUP="$SELECTED_GROUP")"
        ;;
    unchanged)
        log INFO "User $TARGET_USER is not a member of group $SELECTED_GROUP"
        ;;
    *)
        log INFO "User $TARGET_USER removed from group $SELECTED_GROUP"
        notify_ok "${MSG[TITLE]}" \
            "$(i18n_template "${MSG[GROUP_REMOVED]}" USER="$TARGET_USER" GROUP="$SELECTED_GROUP")"
        ;;
esac
