#!/usr/bin/env bash
#
# fix-groups.sh - Add the current user to the required system groups.
#
# Adds the groups the user is missing to the membership list with
# "usermod -aG" and reports the result with a notification. It is started by
# the action button of the check-groups.sh notification.
#
# The required group list is read from ~/.config/kayra/settings.conf
# (key: required_groups) with settings-conf.sh, so it stays in sync with
# check-groups.sh and group-remove.sh.
#
# Usage: fix-groups.sh
#
# Used commands: notify-send, id, cut, tr, sort, awk, printf, pkexec, usermod, settings-conf.sh

set -euo pipefail
export LC_ALL=C.UTF-8

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_FIX_GROUPS

source "$(dirname "$0")/klog.sh"
source "$(dirname "$0")/notify.sh"
source "$(dirname "$0")/settings-conf.sh"

# Fallback used when the required_groups key is missing from settings.conf.
DEFAULT_REQUIRED_GROUPS="users wheel disk floppy cdrom optical storage kvm audio video input dialout plugdev scanner usbmon lp lpadmin bluetooth socklog"

# Required system groups are read from settings.conf (key: required_groups) so
# check-groups.sh, fix-groups.sh and group-remove.sh always share one list.
# Group names never contain spaces, so plain word splitting is safe here.
REQUIRED_GROUPS_STR="$(conf_get required_groups | head -n1 || true)"
[[ -z "$REQUIRED_GROUPS_STR" ]] && REQUIRED_GROUPS_STR="$DEFAULT_REQUIRED_GROUPS"
REQUIRED_GROUPS=( $REQUIRED_GROUPS_STR )

# The user the groups are added to.
TARGET_USER="${SUDO_USER:-${USER:-$(id -un)}}"

# Groups the user belongs to, as one space padded list for an exact match.
USER_GROUP_LIST=" $(id -Gn "$TARGET_USER" | tr ' ' '\n' | sort -u | tr '\n' ' ')"

# Groups that exist on this system, as one space padded list. A required group
# that is not provided by any installed package (e.g. lpadmin before cups) must
# be skipped, otherwise usermod fails with "group does not exist".
AVAILABLE_GROUP_LIST=" $(cut -d: -f1 /etc/group | sort -u | tr '\n' ' ')"

# Required groups that exist but the user is not a member of.
mapfile -t MISSING_GROUPS < <(
    printf '%s\n' "${REQUIRED_GROUPS[@]}" | awk -v members="$USER_GROUP_LIST" -v available="$AVAILABLE_GROUP_LIST" '
        index(available, " " $0 " ") > 0 && index(members, " " $0 " ") == 0 { print $0 }
    '
)

# Required groups that do not exist on this system, logged for reference only.
mapfile -t SKIPPED_GROUPS < <(
    printf '%s\n' "${REQUIRED_GROUPS[@]}" | awk -v available="$AVAILABLE_GROUP_LIST" '
        index(available, " " $0 " ") == 0 { print $0 }
    '
)

if [[ ${#SKIPPED_GROUPS[@]} -gt 0 ]]; then
    log INFO "Required groups not present on this system, skipped: $(IFS=,; echo "${SKIPPED_GROUPS[*]}")"
fi

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
