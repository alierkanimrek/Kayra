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
    # Başkasının kilidine dokunma
    exit 0
fi

# Bundan sonra kilidi biz yaratıyoruz: hata olsa bile temizlenmeli,
# aksi halde başarısız klonlama sonraki tüm kayra-xbps işlemlerini bloklar.
trap 'rm -f "$LOCK_FILE"' EXIT

rm -rf "$PACKAGES_DIR"/*
echo "${MSG[LOCK_DOWNLOAD]}" > "$LOCK_FILE"
log "DEBUG" "${MSG[LOCK_DOWNLOAD]}"

nice -10 git clone https://github.com/void-linux/void-packages.git "$PACKAGES_DIR"

echo XBPS_ALLOW_RESTRICTED=yes >> "$PACKAGES_DIR/etc/conf"

echo "${MSG[LOCK_PREPARE]}" > "$LOCK_FILE"
log "DEBUG" "${MSG[LOCK_PREPARE]}"

cd "$PACKAGES_DIR"
nice -10 ./xbps-src binary-bootstrap

notify-send "${MSG[APP_NAME]}" "${MSG[DOWNLOAD_OK]}"
log "DEBUG" "${MSG[DOWNLOAD_OK]}"

rm -f "$LOCK_FILE"
