#!/usr/bin/env bash
#
# kayra-group-add.sh - Add the user to a group via a fuzzel menu.
#
# Lists the groups the user is not a member of and adds the selected one with
# "usermod -aG" through the kayra-group-services job socket. Groups whose name
# starts with an underscore are system internal groups and are hidden from the
# menu. The menu entries are plain group names, without icons.
#
# usermod does not update the supplementary groups of the running session, so
# the success notification reminds the user to log out and in again.
#
# The service runs as root, so the script needs neither pkexec nor a root
# helper. The job socket is only reachable for members of the fixed
# "kayra-admin" group (socket 0660 root:kayra-admin). A regular user exits
# silently; when the service is not reachable an admin gets a translated error
# notification.
#
# Usage: kayra-group-add.sh [fuzzel parameters...]
#
# Used commands: fuzzel, pkill, awk, printf (via groups-client.sh: socat, flock, jq)
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

# The user the group is added to.
TARGET_USER="$(id -un)"

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

# Groups the user is not a member of and that are not internal (_) groups,
# sorted by name.
mapfile -t ADDABLE_GROUPS < <(
    awk -F'\t' '$2 == "0" && $3 == "0" { print $1 }' <<<"$GROUP_DATA" | sort -u
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

if ! groups_add "$TARGET_USER" "$SELECTED_GROUP"; then
    manager_unavailable
    exit 1
fi

if ! groups_result_ok; then
    log WARN "Failed to add user $TARGET_USER to group $SELECTED_GROUP"
    notify_error "${MSG[TITLE]}" \
        "$(i18n_template "${MSG[ADD_FAILED]}" GROUP="$SELECTED_GROUP")"
    exit 1
fi

# usermod does not update the supplementary groups of the running session, so
# a successful change needs a new login.
RELOGIN_NOTE="$(msg_text RELOGIN_REQUIRED 'Log out and sign in again for the change to take effect.')"

case "$(terminal_event)" in
    added)
        log INFO "User $TARGET_USER added to group $SELECTED_GROUP"
        notify_ok "${MSG[TITLE]}" \
            "$(i18n_template "${MSG[GROUP_ADDED]}" USER="$TARGET_USER" GROUP="$SELECTED_GROUP") $RELOGIN_NOTE"
        ;;
    unchanged)
        log INFO "User $TARGET_USER is already a member of group $SELECTED_GROUP"
        ;;
    *)
        # A response without a terminal event is still a success.
        log INFO "User $TARGET_USER added to group $SELECTED_GROUP"
        notify_ok "${MSG[TITLE]}" \
            "$(i18n_template "${MSG[GROUP_ADDED]}" USER="$TARGET_USER" GROUP="$SELECTED_GROUP") $RELOGIN_NOTE"
        ;;
esac
