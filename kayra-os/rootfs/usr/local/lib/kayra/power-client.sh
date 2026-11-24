#!/usr/bin/env bash
#
# power-client.sh - client helpers for the Kayra power profile service
#                   (source it; do not execute it).
#
# The library talks to the kayra-power-services job socket with socat-link.sh.
# It is meant for user scripts in the desktop session:
#
#     source /usr/local/lib/kayra/power-client.sh
#
#     if ! power_call status; then
#         echo "power service is not running"
#     fi
#
#     for line in "${POWER_EVENTS[@]}"; do
#         echo "$line" | jq -r '.event'
#     done
#
# API
#   power_call <cmd> [parm-json]
#       Sends one request. Returns 0 when a res line was received, 1 on a
#       transport error. Sets the globals below.
#   power_result_ok
#       Returns 0 when the last res has ok=true.
#
# GLOBALS
#   POWER_SOCK    job socket (default /run/kayra-power-services/power.sock)
#   POWER_LOCK    job lock   (default /run/kayra-power-services/power.lock)
#   POWER_RES     last res line, empty on a transport error
#   POWER_EVENTS  array of evt lines received for the last request
#
# IMPORTANT
#   power_call updates globals in the caller shell. Do not call it inside
#   $(...) or a pipeline when the globals are needed; the subshell would keep
#   the changes. power_result_ok is safe in $(...) because it only reads.
#
# Used commands: socat, flock (via socat-link.sh), jq, date
#

. /usr/local/lib/kayra/socat-link.sh

POWER_SOCK=${POWER_SOCK:-/run/kayra-power-services/power.sock}
POWER_LOCK=${POWER_LOCK:-/run/kayra-power-services/power.lock}

POWER_RES=""
POWER_EVENTS=()

POWER_JQ=${SL_JQ:-$(command -v jq 2>/dev/null || true)}

power_call() {  # power_call <cmd> [parm-json] -> 0 res received, 1 error
    local cmd=${1:?command required}
    local parm=${2:-[]}
    local line type id req deadline rc=1

    POWER_RES=""
    POWER_EVENTS=()

    [ -n "$POWER_JQ" ] || return 1
    [ -n "$SL_SOCAT" ] || return 1
    [ -S "$POWER_SOCK" ] || return 1

    sl_wait "$POWER_LOCK" 10 || return 1
    sl_connect "$POWER_SOCK" || return 1

    id="$(date +%s%N)-$$"
    if ! req=$(sl_msg req id="$id" owner="$(sl_owner)" cmd="$cmd" parm="$parm"); then
        sl_close
        return 1
    fi

    if ! printf '%s\n' "$req" >&"$SL_OUT" 2>/dev/null; then
        sl_close
        return 1
    fi

    # tlp start may take a moment, so the per-read timeout is generous; the
    # deadline bounds the whole request.
    deadline=$(( SECONDS + 30 ))
    while (( SECONDS < deadline )); do
        IFS= read -r -t 20 line <&"$SL_IN" || break
        type=$("$POWER_JQ" -r '.type // empty' <<<"$line" 2>/dev/null)
        case "$type" in
            evt) POWER_EVENTS+=("$line") ;;
            res) POWER_RES=$line; rc=0; break ;;
        esac
    done

    sl_close
    return "$rc"
}

power_result_ok() {
    [ -n "$POWER_RES" ] || return 1
    "$POWER_JQ" -e '.ok == true' <<<"$POWER_RES" >/dev/null 2>&1
}
