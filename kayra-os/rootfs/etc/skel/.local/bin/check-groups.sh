#!/bin/bash
#
# Check Groups Script - Verify user group membership and prompt to add missing groups.
# Required groups are defined in the REQUIRED variable.

REQUIRED="users audio video input socklog"
MISSING=""

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_CHECK_GROUPS

for g in $REQUIRED; do
    if ! id -nG | tr ' ' '\n' | grep -qx "$g"; then
        MISSING="$MISSING,$g"
    fi
done
MISSING="${MISSING#,}"

if [ -n "$MISSING" ]; then
    notify-send -a "Group Check" -u critical \
        -A "fix=$(i18n_template "${MSG[NOTIFY_ACTION]}")" \
        "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MISSING_GROUPS]}" GROUPS="$MISSING")"
fi
