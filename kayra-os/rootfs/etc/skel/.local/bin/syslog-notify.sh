#!/bin/sh
# socklog "errors" dizini zaten sadece err/crit/alert/emerg
# seviyesindeki mesajları içerir (svlogd tarafından filtrelenmiş).
#
# NOT: "current" dosyasındaki satırlar başında UTC ISO 8601 zaman
# damgası olan insan-okunur satırlar ("YYYY-MM-DDTHH:MM:SS.ffffff ...").
# Bu damgalar düz string karşılaştırmasıyla doğru kronolojik sırayı
# verir; ayrıca çevirme (tai64nlocal vb.) gerekmez.
#
# Tasarım (inotify tabanlı "debounce"):
#   - sleep ile periyodik tarama YOK. inotifywait dosyayı olay tabanlı
#     izler; script çoğu zaman tamamen boşta (kernel tarafından
#     uyandırılır), CPU/disk'i periyodik olarak yormaz.
#   - Yeni bir yazma (MODIFY) olayı geldiğinde HEMEN bildirim gönderilmez;
#     sadece "hâlâ yazılıyor" olarak kabul edilip bekleme penceresi
#     sıfırlanır (debounce). Yazmalar DEBOUNCE saniye durunca (yani
#     inotifywait zaman aşımına uğrayınca), o ana kadar birikmiş TÜM
#     satırlar TEK bildirimde gönderilir.
#   - Bu script yalnızca kendi başladığı ANDAN itibaren oluşan
#     kayıtlarla ilgilenir; açılıştan bu yana birikmiş eski kayıtlar
#     için ayrı script (syslog-boot-report.sh) kullanılır.

if pgrep -u "$(id -u)" -f "syslog-notify.sh" | grep -qv "^$$\$"; then
    exit 0
fi

LOGFILE="/var/log/socklog/errors/current"

# Yeni bir yazmadan sonra bildirimi göndermeden önce ne kadar
# sessizlik (yeni satır gelmemesi) beklensin? (saniye)
DEBOUNCE=1

# Bildirimin ekranda gösterim süresi (ms)
NOTIFY_TIMEOUT=0   # 0 = otomatik kapanma yok, elle kapatilana/aksiyona kadar bekler

# Başlangıç noktası: script'in başladığı an. Bundan ÖNCEKİ kayıtlar
# (eski "tail -Fn0" davranışıyla aynı şekilde) görmezden gelinir.
LAST_TS=$(date -u +'%Y-%m-%dT%H:%M:%S.000000')

while true; do
    # DEBOUNCE saniye içinde dosyaya yazma olursa hemen döner (kod 0);
    # hiç yazma olmazsa DEBOUNCE saniye sonra zaman aşımıyla döner (kod 2).
    inotifywait -q -t "$DEBOUNCE" -e modify "$LOGFILE" >/dev/null 2>&1
    RET=$?

    if [ "$RET" -eq 0 ]; then
        # Yeni yazma oldu: henüz "sakinleşmedi", pencereyi sıfırlayıp
        # tekrar bekle. Bildirim GÖNDERME.
        continue
    fi

    # RET=2 (zaman aşımı, yani sessizlik oldu) -> birikmiş satırları al
    NEW=$(awk -v last="$LAST_TS" '$1 > last' "$LOGFILE")
    [ -z "$NEW" ] && continue

    LAST_TS=$(printf '%s\n' "$NEW" | tail -n1 | awk '{print $1}')

    MSG="$NEW"
    COUNT=$(printf '%s\n' "$NEW" | grep -c .)

    if [ "$COUNT" -gt 1 ]; then
        TITLE="Sistem Hatası ($COUNT kayıt)"
    else
        TITLE="Sistem Hatası"
    fi

    # Bildirimi arka planda göster; ana döngü (inotifywait) bloklanmasın.
    (
        ACTION=$(notify-send -w -t "$NOTIFY_TIMEOUT" -u normal -a "syslog" \
            -A "open_log=Log Dosyasını Aç" \
            "$TITLE" "$MSG")
        if [ "$ACTION" = "open_log" ]; then
            mousepad "$LOGFILE" >/tmp/mousepad-debug.log 2>&1 &
        fi
    ) &
done
