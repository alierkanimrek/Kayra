
#!/bin/bash
# ev-boyutu.sh - $HOME dizininin disk kullanımını hesaplar ve bildirim gönderir
# Bildirimdeki seçeneğe tıklanırsa baobab açılır.

set -euo pipefail

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_HOME_USAGE

# $HOME boyutunu hesapla (insan-okunur formatta)
HOME_SIZE=$(du -sh "$HOME" 2>/dev/null | awk '{print $1}')

# Bildirimi gönder ve tıklanan eylemi bekle (-w bekletir, -A eylem ekler)
ACTION=$(notify-send \
    -w \
    -i drive-harddisk \
    -A "open=${MSG[NOTIFY_BUTTON]}" \
    "${MSG[NOTIFY_TITLE]}" \
    "$(i18n_template "${MSG[NOTIFY_MSG]}" HOME="$HOME" USAGE="$HOME_SIZE")")

# Kullanıcı "Baobab'ı Aç" seçeneğine tıkladıysa baobab'ı başlat
if [ "$ACTION" = "open" ]; then
    baobab "$HOME" &
    disown
fi
