#!/bin/sh
# ~/.local/bin/check-groups.sh
REQUIRED="audio video input socklog"
MISSING=""

for g in $REQUIRED; do
    if ! id -nG | tr ' ' '\n' | grep -qx "$g"; then
        MISSING="$MISSING,$g"
    fi
done
MISSING="${MISSING#,}"

if [ -n "$MISSING" ]; then
    notify-send -a "Group Check" -u critical \
        -A "fix=Add groups" \
        "Missing group membership" \
        "You are not a member of: $MISSING"
fi
