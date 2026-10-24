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
    notify-send "Yazılım Deposu" "${MSG[LOCK_MSG]}\n $lock_content"
    exit 0
fi

rm -rf $PACKAGES_DIR/*
echo "Yazılım bilgileri indiriliyor." > $LOCK_FILE
log "DEBUG" "Yazılım bilgileri indiriliyor..."

nice -10 git clone https://github.com/void-linux/void-packages.git $PACKAGES_DIR

echo XBPS_ALLOW_RESTRICTED=yes >> $PACKAGES_DIR/etc/conf

echo "Yazılım derleme ortamı hazırlanıyor." > $LOCK_FILE
log "DEBUG" "Yazılım derleme ortamı hazırlanıyor."

cd $PACKAGES_DIR
nice -10 ./xbps-src binary-bootstrap

notify-send "Yazılım Deposu" "Yazılım bilgileri indirildi, kurulum için hazır."
log "DEBUG" "Yazılım bilgileri indirildi, kurulum için hazır."

rm $LOCK_FILE
