#!/usr/bin/env bash

set -euo pipefail
export LC_ALL=C

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_XBPS_MANAGER

source "$(dirname "$0")/klog.sh"

PACKAGES_DIR="/var/spool/void-packages"
LOCK_FILE="/tmp/xbps.lock"

if [[ -f "$LOCK_FILE" ]]; then
    lock_content=$(cat "$LOCK_FILE" 2>/dev/null || true)
    notify-send "${MSG[APP_NAME]}" "${MSG[LOCK_MSG]}\n $lock_content"
    exit 0
fi

PACKAGE_LIST_CMD="find $PACKAGES_DIR/srcpkgs -maxdepth 1 -mindepth 1 -type d -printf '%f\n'"

mapfile -t pkg_list < <(eval "$PACKAGE_LIST_CMD" 2>/dev/null || true)
if [[ ${#pkg_list[@]} -gt 0 ]]; then
    selected=$(printf '%s\n' "${pkg_list[@]}" | fuzzel --dmenu --hide-before-typing)
    [[ -n "$selected" ]] && "$(dirname "$0")/kayra-xbps.sh" "$selected"
fi
