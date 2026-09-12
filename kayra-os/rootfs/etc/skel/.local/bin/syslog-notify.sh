#!/bin/sh
# socklog "errors" dizini zaten sadece err/crit/alert/emerg
# seviyesindeki mesajları içerir (svlogd tarafından filtrelenmiş).
if pgrep -u "$(id -u)" -f "syslog-notify.sh" | grep -qv "^$$\$"; then
    exit 0
fi

LOGFILE="/var/log/socklog/errors/current"

tail -Fn0 "$LOGFILE" | tai64nlocal | while IFS= read -r line; do
    notify-send -u critical -a "syslog" "Sistem Hatası" "$line"
done
