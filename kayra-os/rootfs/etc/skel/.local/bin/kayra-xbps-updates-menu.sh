#!/usr/bin/env bash
#
# kayra-xbps-updates-menu.sh - Fuzzel menu of the available package updates.
#
# The first line is "Check for updates"; below it every package that has an
# update available is listed (packages built from source are tagged). Selecting
# "Check for updates" hands over to kayra-xbps-update.sh (repository sync,
# confirmation and update). Selecting a package opens kayra-xbps.sh for it,
# which offers remove / update / system update.
#
# Used commands: fuzzel, pkill, awk, grep, xbps-install, xbps-checkvers,
#                printf, readlink.
#
# Usage: kayra-xbps-updates-menu.sh

set -uo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

source "$SCRIPT_DIR/i18n.sh"
declare -n MSG=i18n_XBPS_MANAGER

source "$SCRIPT_DIR/klog.sh"
source "$SCRIPT_DIR/kayra-xbps-updates.sh"

# Available updates, one "name<TAB>type" per line.
updates=$(xbps_updatable_pkgs 2>/dev/null || true)

# Menu lines and their ids. The id of the "check" line is the empty string.
declare -a LINES=()
declare -a IDS=()

LINES+=("$(printf '%b' '\U000E923') ${MSG[CHECK_UPDATES]}")
IDS+=("")

while IFS=$'\t' read -r name type; do
    [[ -n "$name" ]] || continue
    if [[ "$type" == "source" ]]; then
        LINES+=("$name ${MSG[UPDATES_SOURCE_TAG]}")
    else
        LINES+=("$name")
    fi
    IDS+=("$name")
done <<< "$updates"

# Window width of the longest menu entry (icon counted as 3 characters).
MAX_WIDTH=$(printf '%s\n' "${LINES[@]}" | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')

# Close any open menu before starting a new one.
pkill -x fuzzel 2>/dev/null || true

SELECTED=$(printf '%s\n' "${LINES[@]}" | fuzzel --dmenu --anchor=top-left --log-no-syslog --minimal-lines --lines="${#LINES[@]}" --width="$MAX_WIDTH" --prompt="${MSG[UPDATES_PROMPT]}: ") || true
[[ -z "$SELECTED" ]] && exit 0

# Map the selected line back to its id. The check line maps to the empty string.
selected_id="__none__"
for i in "${!LINES[@]}"; do
    if [[ "${LINES[$i]}" == "$SELECTED" ]]; then
        selected_id="${IDS[$i]}"
        break
    fi
done
[[ "$selected_id" == "__none__" ]] && exit 0

if [[ -z "$selected_id" ]]; then
    # Check for updates: hand over to the full update flow.
    log INFO "Handing over to kayra-xbps-update.sh"
    exec "$SCRIPT_DIR/kayra-xbps-update.sh"
else
    log INFO "Opening package action for: $selected_id"
    exec "$SCRIPT_DIR/kayra-xbps.sh" "$selected_id"
fi
