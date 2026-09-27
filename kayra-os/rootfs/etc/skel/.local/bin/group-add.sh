#!/usr/bin/env bash
#
# Group Add Script - Add user to a group via fuzzel menu.
# Displays groups the user is not yet a member of.
#
# Usage: ./group-add.sh [fuzzel parameters]

set -euo pipefail

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_GROUP_MANAGEMENT

TARGET_USER="${SUDO_USER:-${USER:-$(id -un)}}"

# Close any open fuzzel windows
pkill -x fuzzel 2>/dev/null || true

# Gather group information
mapfile -t ALL_GROUPS < <(getent group | cut -d: -f1 | sort -u)
mapfile -t USER_GROUPS < <(id -Gn "$TARGET_USER" | tr ' ' '\n')

declare -A IS_MEMBER_MAP
for ug in "${USER_GROUPS[@]}"; do
    IS_MEMBER_MAP["$ug"]=1
done
is_member() { [[ -n "${IS_MEMBER_MAP[$1]+x}" ]]; }

# List of groups user can be added to (groups they are not yet members of)
ADDABLE_GROUPS=()
for g in "${ALL_GROUPS[@]}"; do
    if ! is_member "$g"; then
        ADDABLE_GROUPS+=("$g")
    fi
done

if [[ ${#ADDABLE_GROUPS[@]} -eq 0 ]]; then
    notify-send -u normal "${MSG[TITLE]}" "${MSG[NO_GROUPS_AVAILABLE]}"
    exit 0
fi

menu=$(printf '%s\n' "${ADDABLE_GROUPS[@]}")

# Run fuzzel
line_count=${#ADDABLE_GROUPS[@]}

selected_group=$(printf '%s' "$menu" | fuzzel --dmenu --log-no-syslog "$@" --lines="$line_count") || true

[[ -z "$selected_group" ]] && exit 0

# Add to group using usermod
if pkexec usermod -aG "$selected_group" "$TARGET_USER"; then
    notify-send -u normal "${MSG[TITLE]}" \
        "$(i18n_template "${MSG[GROUP_ADDED]}" USER="$TARGET_USER" GROUP="$selected_group")"
else
    notify-send -u critical "${MSG[TITLE]}" \
        "$(i18n_template "${MSG[ADD_FAILED]}" GROUP="$selected_group")"
fi
