#!/bin/sh
# ~/.local/bin/fix-groups.sh
REQUIRED="audio video input socklog"
USER=$(id -un)
MISSING=""

for g in $REQUIRED; do
    if ! id -nG | tr ' ' '\n' | grep -qx "$g"; then
        MISSING="$MISSING,$g"
    fi
done
MISSING="${MISSING#,}"

if [ -n "$MISSING" ]; then
    pkexec usermod -aG "$MISSING" "$USER"
    if [ $? -eq 0 ]; then
        # Info only — no action, so this notification won't retrigger the fix script
        notify-send -a "Group Check" "Groups added" \
            "Log out and log back in for this to take effect."
    else
        notify-send -a "Group Check" -u critical "Operation cancelled or failed"
    fi
fi
