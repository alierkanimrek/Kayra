#!/usr/bin/env bash
#
# time-client.sh - client helpers for the Kayra time service
#                  (source it; do not execute it).
#
# The library talks to the kayra-time-services job socket with socat-link.sh.
# It is meant for user scripts in the desktop session:
#
#     source /usr/local/lib/kayra/time-client.sh
#
#     if time_set_timezone Europe/Istanbul; then
#         time_result_ok && echo "time zone changed"
#     fi
#
#   time_call <cmd> [parm-json]
#       Sends one request. Returns 0 when a res line was received, 1 on a
#       transport error. Sets the globals below.
#   time_set_timezone <zone>
#       Asks the service to point /etc/localtime at
#       /usr/share/zoneinfo/<zone>. Returns 0 when a res line was received,
#       1 on a transport error. Check time_result_ok afterwards.
#   time_result_ok
#       Returns 0 when the last res has ok=true.
#
# GLOBALS
#   TIME_SOCK   job socket (default /run/kayra-time-services/time.sock)
#   TIME_LOCK   job lock   (default /run/kayra-time-services/time.lock)
#   TIME_RES    last res line, empty on a transport error
#   TIME_EVENTS array of evt lines received for the last request
#
# IMPORTANT
#   time_call and time_set_timezone update globals in the caller shell. Do not
#   call them inside $(...) or a pipeline when the globals are needed.
#
# Used commands: socat, flock (via socat-link.sh), jq, date
#

. /usr/local/lib/kayra/socat-link.sh

TIME_SOCK=${TIME_SOCK:-/run/kayra-time-services/time.sock}
TIME_LOCK=${TIME_LOCK:-/run/kayra-time-services/time.lock}

TIME_RES=""
TIME_EVENTS=()

TIME_JQ=${SL_JQ:-$(command -v jq 2>/dev/null || true)}

time_call() {  # time_call <cmd> [parm-json] -> 0 res received, 1 error
    local cmd=${1:?command required}
    local parm=${2:-[]}
    local line type id req deadline rc=1

    TIME_RES=""
    TIME_EVENTS=()

    [ -n "$TIME_JQ" ] || return 1
    [ -n "$SL_SOCAT" ] || return 1
    [ -S "$TIME_SOCK" ] || return 1

    sl_wait "$TIME_LOCK" 10 || return 1
    sl_connect "$TIME_SOCK" || return 1

    id="$(date +%s%N)-$$"
    if ! req=$(sl_msg req id="$id" owner="$(sl_owner)" cmd="$cmd" parm="$parm"); then
        sl_close
        return 1
    fi

    if ! printf '%s\n' "$req" >&"$SL_OUT" 2>/dev/null; then
        sl_close
        return 1
    fi

    # The handler only updates one symlink, a short deadline is enough.
    deadline=$(( SECONDS + 20 ))
    while (( SECONDS < deadline )); do
        IFS= read -r -t 10 line <&"$SL_IN" || break
        type=$("$TIME_JQ" -r '.type // empty' <<<"$line" 2>/dev/null)
        case "$type" in
            evt) TIME_EVENTS+=("$line") ;;
            res) TIME_RES=$line; rc=0; break ;;
        esac
    done

    sl_close
    return "$rc"
}

time_set_timezone() {  # time_set_timezone <zone>
    local zone=${1:?time zone required}
    local parm

    parm=$("$TIME_JQ" -cn --arg zone "$zone" '[$zone]') || return 1
    time_call timezone "$parm"
}

time_result_ok() {
    [ -n "$TIME_RES" ] || return 1
    "$TIME_JQ" -e '.ok == true' <<<"$TIME_RES" >/dev/null 2>&1
}
