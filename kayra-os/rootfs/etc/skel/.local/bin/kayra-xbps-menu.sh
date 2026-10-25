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

# eval yerine doğrudan find (değişkenler tırnaklı, kalıp sabit)
mapfile -t pkg_list < <(find "$PACKAGES_DIR/srcpkgs" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null || true)
if [[ ${#pkg_list[@]} -gt 0 ]]; then
    # fuzzel iptal edilirse (çıkış 1) set -e betiği erken öldürmesin
    selected=$(printf '%s\n' "${pkg_list[@]}" | fuzzel --dmenu --anchor=top-left --hide-before-typing --log-no-syslog) || true
    [[ -n "$selected" ]] && "$(dirname "$0")/kayra-xbps.sh" "$selected"
fi
