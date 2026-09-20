#!/bin/sh
# socklog "errors" dizini zaten sadece err/crit/alert/emerg
# seviyesindeki mesajları içerir (svlogd tarafından filtrelenmiş).
#
# NOT: "current" dosyasındaki satırlar zaten ham tai64n değil, başında
# "YYYY-MM-DDTHH:MM:SS.ffffff" biçiminde UTC zaman damgası olan
# insan-okunur satırlar. Bu yüzden tai64nlocal'a hiç gerek yok; bu
# ISO 8601 damgalar zaten düz string karşılaştırmasıyla doğru
# kronolojik sırayı verir.
#
# Tasarım: her INTERVAL saniyede bir log dosyasını kontrol et, hafızada
# tutulan son zaman damgasından SONRA gelen satırları al, hepsini tek
# bir bildirimde gönder.

if pgrep -u "$(id -u)" -f "syslog-notify.sh" | grep -qv "^$$\$"; then
    exit 0
fi

LOGFILE="/var/log/socklog/errors/current"

# Ne kadar sıklıkla kontrol edilsin? Bu süre aynı zamanda "aynı
# bildirimde toplanacak" satırların birikme penceresidir.
INTERVAL=3

# Başlangıç noktasını sistem açılış zamanı olarak al, böylece bu script
# henüz çalışmıyor olsa bile açılıştan bu yana oluşmuş hata kayıtları
# ilk taramada bildirime dahil olur.
#
# LOGFILE'daki zaman damgaları UTC olduğu için "date -u" ile aynı
# formatta ve aynı saat diliminde üretiyoruz.
BOOT_EPOCH=$(awk '/^btime /{print $2}' /proc/stat 2>/dev/null)

if [ -n "$BOOT_EPOCH" ]; then
    LAST_TS=$(date -u -d "@$BOOT_EPOCH" +'%Y-%m-%dT%H:%M:%S.000000')
else
    # /proc/stat okunamazsa eski davranışa dön: sadece scriptin
    # başlamasından SONRAKİ kayıtları göster.
    LAST_TS=$(tail -n1 "$LOGFILE" 2>/dev/null | awk '{print $1}')
fi

while true; do
    sleep "$INTERVAL"

    if [ -n "$LAST_TS" ]; then
        NEW=$(awk -v last="$LAST_TS" '$1 > last' "$LOGFILE")
    else
        NEW=$(cat "$LOGFILE")
    fi

    [ -z "$NEW" ] && continue

    # Bir sonraki tur için hafızadaki zaman damgasını güncelle
    LAST_TS=$(printf '%s\n' "$NEW" | tail -n1 | awk '{print $1}')

    MSG="$NEW"
    COUNT=$(printf '%s\n' "$NEW" | grep -c .)

    if [ "$COUNT" -gt 1 ]; then
        TITLE="$COUNT Log kaydı var"
    else
        TITLE="Log kaydı var"
    fi

    # Bildirimi arka planda göster: "-w" ile aksiyon seçilene/bildirim
    # kapanana kadar bekleniyor, ama bunu "&" ile arka plana alarak ana
    # döngünün (yeni log takibinin) bloklanmasını önlüyoruz.
    (
        ACTION=$(notify-send -w -u low -a "syslog" \
            -A "open_log=Log Dosyasını Aç" \
            "$TITLE" "$MSG")
        if [ "$ACTION" = "open_log" ]; then
            mousepad "$LOGFILE" &
        fi
    ) &
done
