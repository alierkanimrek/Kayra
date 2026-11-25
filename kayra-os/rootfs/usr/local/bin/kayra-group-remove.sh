#!/usr/bin/env bash
#
# kayra-group-remove.sh - Remove the user from a group via a fuzzel menu.
#
# Lists the groups the user is a member of and removes the selected one with
# "gpasswd -d" through the kayra-group-services job socket. Exception groups
# are shown with a lock icon and cannot be removed; the exception policy is
# managed by this client: the exception list is the required_groups list from
# /etc/default/kayra.conf (via settings-conf.sh) while the auto_group_management
# setting is "true". When that setting is "false" the exception list is empty
# and every group can be removed. The service only refuses the primary group.
#
# The service runs as root, so the script needs neither pkexec nor a root
# helper. When the service is not reachable a translated error notification is
# shown.
#
# Usage: kayra-group-remove.sh [fuzzel parameters...]
#
# Used commands: fuzzel, pkill, id, awk, printf (via groups-client.sh:
#                socat, flock, jq)
#

set -euo pipefail
export LC_ALL=C.UTF-8

source /usr/local/lib/kayra/i18n.sh
declare -n MSG=i18n_GROUP_MANAGEMENT

source /usr/local/lib/kayra/klog.sh
source /usr/local/lib/kayra/notify.sh
source /usr/local/lib/kayra/settings-conf.sh
source /usr/local/lib/kayra/groups-client.sh

# The user the group is removed from.
TARGET_USER="$(id -un)"

# Material symbols used in front of every menu entry.
ICON_MEMBER=$(printf '%b' '\U000E7EF')      # group
ICON_EXCEPTION=$(printf '%b' '\U000E897')  # lock, the group can not be left

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

# Automatic group management: when "true" (default) the required groups are
# protected and cannot be removed from the menu. When "false" the user is free
# to add or remove any group.
AUTO_GROUP_MANAGEMENT="$(conf_get auto_group_management | head -n1 || true)"
[[ -z "$AUTO_GROUP_MANAGEMENT" ]] && AUTO_GROUP_MANAGEMENT="true"

# Exception groups - the user cannot be removed from these while automatic
# group management is enabled. Group names never contain spaces, so plain word
# splitting is safe here.
if [[ "$AUTO_GROUP_MANAGEMENT" == "true" ]]; then
    EXCEPTION_GROUPS_STR="$(system_conf_get required_groups | head -n1 || true)"
    EXCEPTION_GROUPS=( $EXCEPTION_GROUPS_STR )
else
    # Free mode: every group can be removed.
    EXCEPTION_GROUPS=()
fi

# Exception groups as one space padded list for an exact match.
EXCEPTION_LIST=" ${EXCEPTION_GROUPS[*]:-} "

# Returns 0 when the given group is an exception group. The match is exact,
# so a group name is never treated as a pattern.
is_exception() {
    printf '%s\n' "$1" | awk -v list="$EXCEPTION_LIST" 'index(list, " " $0 " ") > 0 { found = 1 } END { exit !found }'
}

# Returns the terminal event of the last request, empty when none arrived.
terminal_event() {
    local line event result=""

    for line in "${GROUPS_EVENTS[@]}"; do
        event=$("${GROUPS_JQ:-jq}" -r '.event // empty' <<<"$line" 2>/dev/null)
        case "$event" in
            added|removed|fixed|unchanged|notfound|failed) result=$event ;;
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
    if is_exception "$group"; then
        MENU_LINES+=("$ICON_EXCEPTION $group")
    else
        MENU_LINES+=("$ICON_MEMBER $group")
    fi
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

# If exception group: do not perform the operation.
if is_exception "$SELECTED_GROUP"; then
    log INFO "Group $SELECTED_GROUP is an exception group, removal skipped for user $TARGET_USER"
    notify_warn "${MSG[TITLE]}" \
        "$(i18n_template "${MSG[EXCEPTION_GROUP]}" GROUP="$SELECTED_GROUP" USER="$TARGET_USER")"
    exit 0
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
