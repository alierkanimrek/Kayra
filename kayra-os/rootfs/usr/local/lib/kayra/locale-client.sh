#!/usr/bin/env bash
#
# locale-client.sh - client helpers for the Kayra locale service
#                    (source it; do not execute it).
#
# The library talks to the kayra-locale-services job socket with socat-link.sh.
# It is meant for user scripts in the desktop session:
#
#     source /usr/local/lib/kayra/locale-client.sh
#
#     if locale_ensure tr_TR.UTF-8; then
#         locale_result_ok && echo "ready"
#     fi
#
# API
#   locale_call <cmd> [parm-json]
#       Sends one request. Returns 0 when a res line was received, 1 on a
#       transport error. Sets the globals below.
#   locale_ensure <locale>
#       Asks the service to generate one locale. Returns 0 when a res line was
#       received, 1 on a transport error. Check locale_result_ok afterwards.
#   locale_add <code> <locale> <language> <native> <name_en>
#       Asks the service to append one entry to languages.tsv. Returns 0 when a
#       res line was received, 1 on a transport error. Check locale_result_ok
#       afterwards.
#   locale_generated <locale>
#       Returns 0 when the locale is present in the locale archive.
#   locale_supported <locale>
#       Returns 0 when the locale is listed in /etc/default/libc-locales.
#   locale_result_ok
#       Returns 0 when the last res has ok=true.
#
# GLOBALS
#   LOCALE_SOCK    job socket (default /run/kayra-locale-services/locale.sock)
#   LOCALE_LOCK    job lock   (default /run/kayra-locale-services/locale.lock)
#   LOCALE_DB      locale list (default /etc/default/libc-locales)
#   LOCALE_RES     last res line, empty on a transport error
#   LOCALE_EVENTS  array of evt lines received for the last request
#
# IMPORTANT
#   locale_call and locale_ensure update globals in the caller shell. Do not
#   call them inside $(...) or a pipeline when the globals are needed.
#
# Used commands: socat, flock (via socat-link.sh), jq, date, locale, awk
#

. /usr/local/lib/kayra/socat-link.sh

LOCALE_SOCK=${LOCALE_SOCK:-/run/kayra-locale-services/locale.sock}
LOCALE_LOCK=${LOCALE_LOCK:-/run/kayra-locale-services/locale.lock}
LOCALE_DB=${LOCALE_DB:-/etc/default/libc-locales}

LOCALE_RES=""
LOCALE_EVENTS=()

LOCALE_JQ=${SL_JQ:-$(command -v jq 2>/dev/null || true)}

# _locale_key <locale> -> normalized key for archive comparison
_locale_key() {
    printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]' | sed 's/utf-8/utf8/g'
}

# locale_generated <locale>
locale_generated() {
    local want
    want=$(_locale_key "$1")
    [ -n "$want" ] || return 1
    locale -a 2>/dev/null |
        tr '[:upper:]' '[:lower:]' | sed 's/utf-8/utf8/g' |
        grep -qxF -- "$want"
}

# locale_supported <locale>
locale_supported() {
    local want=${1:-}
    [ -n "$want" ] || return 1
    [ -r "$LOCALE_DB" ] || return 1
    awk -v want="$want" '
        {
            line = $0
            sub(/^[ \t]*#?[ \t]*/, "", line)
            split(line, f, /[ \t]+/)
            if (f[1] == want) { found = 1; exit }
        }
        END { exit !found }
    ' "$LOCALE_DB"
}

locale_call() {  # locale_call <cmd> [parm-json] -> 0 res received, 1 error
    local cmd=${1:?command required}
    local parm=${2:-[]}
    local line type id req deadline rc=1

    LOCALE_RES=""
    LOCALE_EVENTS=()

    [ -n "$LOCALE_JQ" ] || return 1
    [ -n "$SL_SOCAT" ] || return 1
    [ -S "$LOCALE_SOCK" ] || return 1

    sl_wait "$LOCALE_LOCK" 10 || return 1
    sl_connect "$LOCALE_SOCK" || return 1

    id="$(date +%s%N)-$$"
    if ! req=$(sl_msg req id="$id" owner="$(sl_owner)" cmd="$cmd" parm="$parm"); then
        sl_close
        return 1
    fi

    if ! printf '%s\n' "$req" >&"$SL_OUT" 2>/dev/null; then
        sl_close
        return 1
    fi

    # xbps-reconfigure may compile all enabled locales; the handler bounds it
    # with a 300 second timeout, so the client deadline is slightly longer.
    deadline=$(( SECONDS + 340 ))
    while (( SECONDS < deadline )); do
        IFS= read -r -t 320 line <&"$SL_IN" || break
        type=$("$LOCALE_JQ" -r '.type // empty' <<<"$line" 2>/dev/null)
        case "$type" in
            evt) LOCALE_EVENTS+=("$line") ;;
            res) LOCALE_RES=$line; rc=0; break ;;
        esac
    done

    sl_close
    return "$rc"
}

locale_ensure() {  # locale_ensure <locale>
    local locale=${1:?locale required}
    local parm

    parm=$("$LOCALE_JQ" -cn --arg locale "$locale" '[$locale]') || return 1
    locale_call ensure "$parm"
}

locale_add() {  # locale_add <code> <locale> <language> <native> <name_en>
    local code=${1:?code required}
    local locale=${2:?locale required}
    local language=${3:?language list required}
    local native=${4:?native name required}
    local name_en=${5:?English name required}
    local parm

    parm=$("$LOCALE_JQ" -cn \
        --arg code "$code" \
        --arg locale "$locale" \
        --arg language "$language" \
        --arg native "$native" \
        --arg name_en "$name_en" \
        '[$code, $locale, $language, $native, $name_en]') || return 1
    locale_call add "$parm"
}

locale_result_ok() {
    [ -n "$LOCALE_RES" ] || return 1
    "$LOCALE_JQ" -e '.ok == true' <<<"$LOCALE_RES" >/dev/null 2>&1
}
