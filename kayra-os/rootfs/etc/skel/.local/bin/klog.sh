#!/bin/sh
# ~/.local/bin/klog — kaynak olarak yüklenir, log() ile kullanılır

. "$HOME/.local/bin/settings-conf.sh" 2>/dev/null || true

lvl() {
    case "$1" in
        DEBUG) echo 0 ;; INFO) echo 1 ;; WARN|WARNING) echo 2 ;; ERROR) echo 3 ;; *) echo 1 ;;
    esac
}

log() {
    local lvl="$1"
    shift
    local msg="$*"
    local script="${KLOG_SCRIPT:-$(basename "$0")}"
    local conf_level=$(conf_get log_level 2>/dev/null | tr '[:lower:]' '[:upper:]')
    [ -z "$conf_level" ] && conf_level="INFO"
    [ "$(lvl "$lvl")" -lt "$(lvl "$conf_level")" ] && return 0
    mkdir -p "$HOME/.local/var/log" 2>/dev/null || true
    printf '%s [%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$script" "$lvl" "$msg" >> "$HOME/.local/var/log/kayra.log"
    echo "$msg"
}
