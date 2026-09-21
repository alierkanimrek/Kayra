#!/bin/sh
# Sistem açılışından bu yana socklog "errors" dosyasında birikmiş
# hata kayıtlarını TEK bir bildirimde gösterir ve sonlanır.
#
# Oturum başlangıcında (autostart) bir kere çalıştırılmak üzere
# tasarlanmıştır; sürekli çalışan syslog-notify.sh'den bağımsızdır.

LOGFILE="/var/log/socklog/errors/current"
NOTIFY_TIMEOUT=0   # 0 = otomatik kapanma yok, elle kapatılana/aksiyona kadar bekler

# LOGFILE'daki zaman damgaları UTC ISO 8601 formatında
# ("YYYY-MM-DDTHH:MM:SS.ffffff ..."). Açılış zamanını da aynı
# formatta üretip düz string karşılaştırmasıyla filtreliyoruz.
BOOT_EPOCH=$(awk '/^btime /{print $2}' /proc/stat 2>/dev/null)

if [ -n "$BOOT_EPOCH" ]; then
    BOOT_TS=$(date -u -d "@$BOOT_EPOCH" +'%Y-%m-%dT%H:%M:%S.000000')
    NEW=$(awk -v last="$BOOT_TS" '$1 > last' "$LOGFILE")
else
    # btime okunamazsa dosyanın tamamını göster
    NEW=$(cat "$LOGFILE")
fi

[ -z "$NEW" ] && exit 0

COUNT=$(printf '%s\n' "$NEW" | grep -c .)

if [ "$COUNT" -gt 1 ]; then
    TITLE="Açılıştan Bu Yana Hatalar ($COUNT kayıt)"
else
    TITLE="Açılıştan Bu Yana Hata"
fi

ACTION=$(notify-send -w -t "$NOTIFY_TIMEOUT" -u normal -a "syslog" \
    -A "open_log=Log Dosyasını Aç" \
    "$TITLE" "$NEW")

if [ "$ACTION" = "open_log" ]; then
    mousepad "$LOGFILE" &
fi
