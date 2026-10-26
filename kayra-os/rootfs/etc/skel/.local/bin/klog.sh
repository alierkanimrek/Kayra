#!/bin/sh
#
# klog.sh - Kayra OS logging library (source it; do not execute it).
#
# Adds log() to the caller's shell: it appends the message to
#   ~/.local/var/log/kayra.log  as  "<date> [<script>] [<LEVEL>] <message>"
# and echoes the message to stdout.
#
# Usage in a script:
#   source "$(dirname "$0")/klog.sh"
#   log INFO "Something happened"      # levels: DEBUG INFO WARN|ERROR
#
# * The log level is read from settings-conf.sh (log_level=, default INFO);
#   messages below that level are dropped.
# * The script name in the log line is $0; set KLOG_SCRIPT to override it.
# * Also defines lvl(), which maps a level name to a numeric weight
#   (DEBUG=0, INFO=1, WARN=2, ERROR=3).
#

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
    touch "$HOME/.local/var/log/kayra.log" >/dev/null 2>&1
    printf '%s [%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$script" "$lvl" "$(echo -e $msg)" >> "$HOME/.local/var/log/kayra.log"
    echo "$msg"
}
