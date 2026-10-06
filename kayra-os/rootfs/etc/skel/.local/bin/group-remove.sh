#!/usr/bin/env bash
#
# Group Remove Script - Remove user from groups via fuzzel menu.
# Shows groups the user is a member of, with icons indicating removable vs. exception groups.
# Exception groups (marked in the script) cannot be removed.
#
# Usage: ./group-remove.sh [fuzzel parameters]

set -euo pipefail
export LC_CTYPE=en_US.UTF-8

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_GROUP_MANAGEMENT

# Configuration
ICON_MEMBER=$(printf '%b' '\U0000E7EF')
ICON_EXCEPTION=""

SEP=$'\t'

# Exception groups - cannot be removed from these
EXCEPTION_GROUPS=(audio video input users socklog)

TARGET_USER="${SUDO_USER:-${USER:-$(id -un)}}"

# Close any open fuzzel windows
pkill -x fuzzel 2>/dev/null || true

# Gather group information
mapfile -t USER_GROUPS < <(id -Gn "$TARGET_USER" | tr ' ' '\n')
PRIMARY_GROUP=$(id -gn "$TARGET_USER")

declare -A IS_EXCEPTION_MAP
for eg in "${EXCEPTION_GROUPS[@]}"; do
    IS_EXCEPTION_MAP["$eg"]=1
done
is_exception() { [[ -n "${IS_EXCEPTION_MAP[$1]+x}" ]]; }

# List of groups to display in menu (excluding primary group)
LISTED_GROUPS=()
for g in "${USER_GROUPS[@]}"; do
    [[ "$g" == "$PRIMARY_GROUP" ]] && continue
    LISTED_GROUPS+=("$g")
done

if [[ ${#LISTED_GROUPS[@]} -eq 0 ]]; then
    notify-send -u normal "${MSG[TITLE]}" "${MSG[NO_GROUPS_TO_REMOVE]}"
    exit 0
fi

# Build menu text (tab-separated with icons)
menu=""
for g in "${LISTED_GROUPS[@]}"; do
    if is_exception "$g"; then
        menu+="${ICON_EXCEPTION}${SEP}${g}"$'\n'
    else
        menu+="${ICON_MEMBER}${SEP}${g}"$'\n'
    fi
done

# Run fuzzel
line_count=${#LISTED_GROUPS[@]}

selection=$(printf '%s' "$menu" | fuzzel --dmenu --log-no-syslog "$@" --lines="$line_count") || true

[[ -z "$selection" ]] && exit 0

# Parse: extract group name after TAB (works even if icon is empty)
selected_group="${selection#*"$SEP"}"

# If exception group: do not perform operation
if is_exception "$selected_group"; then
    notify-send -u normal "${MSG[TITLE]}" \
        "$(i18n_template "${MSG[EXCEPTION_GROUP]}" GROUP="$selected_group" USER="$TARGET_USER")"
    exit 0
fi

# Remove from group using usermod with new group list
new_list=""
for g in "${USER_GROUPS[@]}"; do
    if [[ "$g" != "$selected_group" && "$g" != "$PRIMARY_GROUP" ]]; then
        new_list+="${g},"
    fi
done
new_list="${new_list%,}"

if pkexec usermod -G "$new_list" "$TARGET_USER"; then
    notify-send -u normal "${MSG[TITLE]}" \
        "$(i18n_template "${MSG[GROUP_REMOVED]}" USER="$TARGET_USER" GROUP="$selected_group")"
else
    notify-send -u critical "${MSG[TITLE]}" \
        "$(i18n_template "${MSG[REMOVE_FAILED]}" GROUP="$selected_group")"
fi
