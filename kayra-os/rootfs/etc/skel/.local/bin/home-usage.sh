
#!/bin/bash
# ev-boyutu.sh - $HOME dizininin disk kullanımını hesaplar ve bildirim gönderir
# Bildirimdeki seçeneğe tıklanırsa baobab açılır.

set -euo pipefail

# Gerekli komutların varlığını kontrol et
if ! command -v notify-send >/dev/null 2>&1; then
    echo "Hata: notify-send bulunamadı. Kurulum: sudo xbps-install -S libnotify" >&2
    exit 1
fi

if ! command -v baobab >/dev/null 2>&1; then
    echo "Uyarı: baobab bulunamadı. Kurulum: sudo xbps-install -S baobab" >&2
fi

# $HOME boyutunu hesapla (insan-okunur formatta)
HOME_SIZE=$(du -sh "$HOME" 2>/dev/null | awk '{print $1}')

# Bildirimi gönder ve tıklanan eylemi bekle (-w bekletir, -A eylem ekler)
ACTION=$(notify-send \
    -w \
    -i drive-harddisk \
    -A "open=Baobab'ı Aç" \
    "Ev Dizini Boyutu" \
    "$HOME dizini şu anda ${HOME_SIZE} yer kaplıyor.")

# Kullanıcı "Baobab'ı Aç" seçeneğine tıkladıysa baobab'ı başlat
if [ "$ACTION" = "open" ]; then
    baobab "$HOME" &
    disown
fi
