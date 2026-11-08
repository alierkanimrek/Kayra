#!/usr/bin/env bash
#
# kayra-xbps-clone.sh - Clone/refresh the Void Linux packages source tree.
#
# Downloads (or re-downloads) the void-packages git repository into
# PACKAGES_DIR and prepares the xbps-src build environment.
#
# Locking: takes the shared XBPS lock (see kayra-xbps-lock.sh) for the whole
# clone/build, so a package operation run by hand waits for it. The lock is an
# flock and is released automatically on exit, so a failed clone never leaves a
# stale lock behind.
#
# How it works:
#   * Stops early if another operation already holds the lock.
#   * Removes any previous checkout, then clones void-packages.
#   * Enables restricted packages in etc/conf.
#   * Bootstraps the xbps-src build environment.
#
# Commands used: flock, rm, printf, trap, nice, git, cd, xbps-src, notify-send.
#
# Usage: kayra-xbps-clone.sh

set -euo pipefail
export LC_ALL=C.UTF-8

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_XBPS_MANAGER

source "$(dirname "$0")/klog.sh"
source "$(dirname "$0")/notify.sh"
source "$(dirname "$0")/kayra-xbps-lock.sh"

PACKAGES_DIR="/var/spool/void-packages"

# Take the shared XBPS lock for the whole clone/build. While it is held, any
# xbps command the user starts by hand waits for us and no other Kayra
# operation can overlap. flock is released automatically on exit.
if ! xbps_lock_acquire; then
    notify_warn "${MSG[APP_NAME]}" "${MSG[LOCK_MSG]}"
    exit 0
fi

trap 'xbps_status_clear; xbps_lock_release' EXIT

rm -rf "${PACKAGES_DIR:?}"/*
xbps_status_set "${MSG[LOCK_DOWNLOAD]}"
log DEBUG "${MSG[LOCK_DOWNLOAD]}"

nice -10 git clone https://github.com/void-linux/void-packages.git "$PACKAGES_DIR"

echo XBPS_ALLOW_RESTRICTED=yes >> "$PACKAGES_DIR/etc/conf"

xbps_status_set "${MSG[LOCK_PREPARE]}"
log DEBUG "${MSG[LOCK_PREPARE]}"

# xbps-src runs inside the masterdir, which has its own package database and
# its own pkgdb lock, so it does not conflict with the host lock held here.
cd "$PACKAGES_DIR"
nice -10 ./xbps-src binary-bootstrap

notify_ok "${MSG[APP_NAME]}" "${MSG[DOWNLOAD_OK]}"
log DEBUG "${MSG[DOWNLOAD_OK]}"
