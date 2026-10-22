#!/usr/bin/env bash

set -euo pipefail
export LC_ALL=C

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_XBPS_MANAGER

source "$(dirname "$0")/klog.sh"

PACKAGES_DIR="/var/spool/void-packages"
LOCK_FILE="$PACKAGES_DIR/xbps.lock"
RUN_FILE="$PACKAGES_DIR/xbps-src"

if [[ -f "$LOCK_FILE" ]]; then
    lock_content=$(cat "$LOCK_FILE" 2>/dev/null || true)
    notify-send -i applications-engineering "${MSG[LOCK_MSG]}" "$lock_content"
    exit 0
fi

if [[ ! -f "$RUN_FILE" ]]; then
    action=$(notify-send -i applications-engineering -t 0 \
        -A download="${MSG[ACTION_DOWNLOAD]}" \
        "${MSG[NO_DATA]}" "")
    if [[ "$action" == "download" ]]; then
        "$(dirname "$0")/kayra-xbps-clone.sh"
    fi
    exit 0
fi

"$(dirname "$0")/kayra-xbps-menu.sh"
