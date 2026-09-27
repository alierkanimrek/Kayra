#!/bin/sh
#
# Fix Groups Script - Add user to required system groups.

REQUIRED="users audio video input socklog"
USER=$(id -un)
MISSING=""

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_FIX_GROUPS

for g in $REQUIRED; do
    if ! id -nG | tr ' ' '\n' | grep -qx "$g"; then
        MISSING="$MISSING,$g"
    fi
done
MISSING="${MISSING#,}"

if [ -n "$MISSING" ]; then
    pkexec usermod -aG "$MISSING" "$USER"
    if [ $? -eq 0 ]; then
        # Info notification only — no action, so this won't retrigger the fix script
        notify-send -a "Group Check" "${MSG[TITLE_SUCCESS]}" "${MSG[MSG_SUCCESS]}"
    else
        notify-send -a "Group Check" -u critical "${MSG[TITLE_FAILED]}"
    fi
fi
