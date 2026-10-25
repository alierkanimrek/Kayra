#!/usr/bin/env bash
# /tmp/xbps.lock değişikliklerini inotifywait ile izler ve waybar custom modülü için JSON üretir.

source "$HOME/.local/bin/single-instance.sh"
single_instance

export LC_ALL=C

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_XBPS_MANAGER

LOCK_FILE="/tmp/xbps.lock"
WATCH_DIR="${LOCK_FILE%/*}"
BASE_NAME="${LOCK_FILE##*/}"
ICON=$(LC_ALL=C.UTF-8 printf '%b' '\U000EF40')   # Nerd Font glifi U+EF40

command -v inotifywait >/dev/null || { echo "inotifywait bulunamadı" >&2; exit 1; }

# emit <text> <tooltip> <class>
emit() {
    jq -cn --arg text "$1" --arg tooltip "$2" --arg class "$3" \
        '{text: $text, tooltip: $tooltip, class: $class}'
}

publish() {
    if [[ -e $LOCK_FILE ]]; then
        local content=""
        [[ -r $LOCK_FILE ]] && content=$(<"$LOCK_FILE")
        [[ -z $content ]] && content="xbps.lock boş"
        emit "$ICON" "$content" "present"
    else
        emit "" "" "absent"
    fi
}

# Başlangıç durumunu yayınla.
publish

# Yalnızca dizin olaylarını dinle, dosya adını al ve hedef dosyaysa yayınla.
inotifywait -m -q \
    -e close_write,create,delete,moved_to,moved_from \
    --format '%f' "$WATCH_DIR" |
while IFS= read -r file; do
    [[ $file == "$BASE_NAME" ]] && publish
done
