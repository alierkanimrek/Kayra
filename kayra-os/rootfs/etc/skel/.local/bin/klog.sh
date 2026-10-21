#!/bin/sh
# ~/.local/bin/klog
# Kullanım: klog SEVIYE MESAJ
LOG="$HOME/.local/var/log/kayra.log"

. "$HOME/.local/bin/settings-conf.sh" 2>/dev/null

lvl() {
    case "$1" in
        DEBUG) echo 0 ;; INFO) echo 1 ;; WARN|WARNING) echo 2 ;; ERROR) echo 3 ;; *) echo 1 ;;
    esac
}

MSG=$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]'); shift
CONF=$(conf_get log_level 2>/dev/null | tr '[:lower:]' '[:upper:]')

[ "$(lvl "$MSG")" -lt "$(lvl "$CONF")" ] && exit 0

mkdir -p "$(dirname "$LOG")" 2>/dev/null
printf '%s [%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" \
    "${KLOG_SCRIPT:-$(basename "$0")}" "$MSG" "$*" >> "$LOG" 2>/dev/null

echo $*

exit 0
