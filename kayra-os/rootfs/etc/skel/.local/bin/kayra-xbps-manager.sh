#!/usr/bin/env bash
#
# kayra-xbps-manager.sh - Entry point of the Kayra software manager.
#
# Dispatches to the right tool depending on the state of the local
# void-packages checkout:
#   * If a package operation is running (lock held), notifies the user and stops.
#   * If the source tree is missing, offers to download it and runs
#     kayra-xbps-clone.sh.
#   * Otherwise opens the package menu (kayra-xbps-menu.sh).
#
# Commands used: flock, notify-send, kayra-xbps-clone.sh, kayra-xbps-menu.sh.
#
# Usage: kayra-xbps-manager.sh

set -euo pipefail
export LC_ALL=C.UTF-8

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_XBPS_MANAGER

source "$(dirname "$0")/klog.sh"
source "$(dirname "$0")/notify.sh"
source "$(dirname "$0")/kayra-xbps-lock.sh"

# Icon of the download prompt (Material Symbols "file_download").
ICON_DOWNLOAD="$(printf '%b' '\U000E2C4')"

PACKAGES_DIR="/var/spool/void-packages"
RUN_FILE="$PACKAGES_DIR/xbps-src"

# If any package operation is running (a Kayra script or a command the user
# started by hand), tell the user and stop. The manager only dispatches to the
# scripts that take the lock themselves, so it must not hold it here.
if xbps_busy; then
    notify_warn "${MSG[APP_NAME]}" "${MSG[LOCK_MSG]}"
    exit 0
fi

if [[ ! -f "$RUN_FILE" ]]; then
    NOTIFY_ICON="$ICON_DOWNLOAD"
    action=$(notify_action "${MSG[APP_NAME]}" "${MSG[NO_DATA]}" \
        "download=${MSG[ACTION_DOWNLOAD]}") || true
    unset NOTIFY_ICON
    if [[ "$action" == "download" ]]; then
        "$(dirname "$0")/kayra-xbps-clone.sh"
    fi
    exit 0
fi

"$(dirname "$0")/kayra-xbps-menu.sh"
