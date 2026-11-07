#!/usr/bin/env bash
#
# kayra-xbps-clone.sh - Clone/refresh the Void Linux packages source tree.
#
# Downloads (or re-downloads) the void-packages git repository into
# PACKAGES_DIR and prepares the xbps-src build environment. A lock file
# serialises the package operations: it is created before the clone and removed
# on exit (trap EXIT), so a failed clone never blocks later operations.
#
# How it works:
#   * Stops early if another operation already owns the lock.
#   * Removes any previous checkout, then clones void-packages.
#   * Enables restricted packages in etc/conf.
#   * Bootstraps the xbps-src build environment.
#
# Commands used: cat, rm, echo, trap, nice, git, cd, xbps-src, notify-send, date.
#
# Usage: kayra-xbps-clone.sh

set -euo pipefail
export LC_ALL=C.UTF-8

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_XBPS_MANAGER

source "$(dirname "$0")/klog.sh"
source "$(dirname "$0")/notify.sh"

PACKAGES_DIR="/var/spool/void-packages"
LOCK_FILE="/tmp/xbps.lock"

if [[ -f "$LOCK_FILE" ]]; then
    lock_content=$(cat "$LOCK_FILE" 2>/dev/null || true)
    notify_warn "${MSG[APP_NAME]}" "${MSG[LOCK_MSG]}"$'\n'"$lock_content"
    # Do not touch another operation's lock.
    exit 0
fi

# From here on we own the lock: it must be removed even on failure,
# otherwise a failed clone blocks every later kayra-xbps operation.
trap 'rm -f "$LOCK_FILE"' EXIT

rm -rf "${PACKAGES_DIR:?}"/*
echo "${MSG[LOCK_DOWNLOAD]}" > "$LOCK_FILE"
log DEBUG "${MSG[LOCK_DOWNLOAD]}"

nice -10 git clone https://github.com/void-linux/void-packages.git "$PACKAGES_DIR"

echo XBPS_ALLOW_RESTRICTED=yes >> "$PACKAGES_DIR/etc/conf"

echo "${MSG[LOCK_PREPARE]}" > "$LOCK_FILE"
log DEBUG "${MSG[LOCK_PREPARE]}"

cd "$PACKAGES_DIR"
nice -10 ./xbps-src binary-bootstrap

notify_ok "${MSG[APP_NAME]}" "${MSG[DOWNLOAD_OK]}"
log DEBUG "${MSG[DOWNLOAD_OK]}"
