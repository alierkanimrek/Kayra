#!/usr/bin/env bash
#
# services-client.sh - client helpers for the Kayra system service manager
#                      (source it; do not execute it).
#
# The library talks to the kayra-system-services job socket with socat-link.sh.
# It is meant for user scripts in the desktop session:
#
#     source /usr/local/lib/kayra/services-client.sh
#
#     if ! services_list > /tmp/services; then
#         echo "service manager is not running"
#     fi
#
#     services_action start sshd
#     for line in "${SERVICES_EVENTS[@]}"; do
#         echo "$line" | jq -r '.event'
#     done
#
# API
#   services_call <cmd> [parm-json]
#       Sends one request. Returns 0 when a res line was received, 1 on a
#       transport error. Sets the globals below.
#   services_list
#       Prints "<name><TAB><state><TAB><protected><TAB><boot>" for every
#       service. state: running, down, disabled, failed. boot: auto, manual.
#       Returns 1 when the manager is not reachable or the request failed.
#   services_action <cmd> <service>
#       Sends an action request. Returns 0 when a res line was received,
#       1 on a transport error. The caller reads the events/res globals.
#   services_detail <service>
#       Sends a detail request. Returns 0 when a res line was received,
#       1 on a transport error. The caller reads the res globals.
#   services_logs <service>
#       Streams the log of the service to stdout until the connection closes
#       (Ctrl+C in a terminal). Returns 1 when the log service is not running.
#   services_result_ok
#       Returns 0 when the last res has ok=true.
#
# GLOBALS
#   SERVICES_SOCK      job socket (default /run/kayra-system-services/job.sock)
#   SERVICES_LOCK      job lock   (default /run/kayra-system-services/job.lock)
#   SERVICES_LOG_SOCK  log socket (default /run/kayra-system-logs/log.sock)
#   SERVICES_RES       last res line, empty on a transport error
#   SERVICES_EVENTS    array of evt lines received for the last request
#
# IMPORTANT
#   services_call and services_action update globals in the caller shell.
#   Do not call them inside $(...) or a pipeline when the globals are needed;
#   the subshell would keep the changes. services_list is safe in $(...)
#   because it prints its result.
#
# Used commands: socat, flock (via socat-link.sh), jq, date, cat, printf
#

. /usr/local/lib/kayra/socat-link.sh

SERVICES_SOCK=${SERVICES_SOCK:-/run/kayra-system-services/job.sock}
SERVICES_LOCK=${SERVICES_LOCK:-/run/kayra-system-services/job.lock}
SERVICES_LOG_SOCK=${SERVICES_LOG_SOCK:-/run/kayra-system-logs/log.sock}

SERVICES_RES=""
SERVICES_EVENTS=()

JQ=${SL_JQ:-$(command -v jq 2>/dev/null || true)}

services_call() {  # services_call <cmd> [parm-json] -> 0 res received, 1 error
    local cmd=${1:?command required}
    local parm=${2:-[]}
    local line type id req deadline rc=1

    SERVICES_RES=""
    SERVICES_EVENTS=()

    [ -n "$JQ" ] || return 1
    [ -n "$SL_SOCAT" ] || return 1
    [ -S "$SERVICES_SOCK" ] || return 1

    sl_wait "$SERVICES_LOCK" 10 || return 1
    sl_connect "$SERVICES_SOCK" || return 1

    id="$(date +%s%N)-$$"
    if ! req=$(sl_msg req id="$id" owner="$(sl_owner)" cmd="$cmd" parm="$parm"); then
        sl_close
        return 1
    fi

    if ! printf '%s\n' "$req" >&"$SL_OUT" 2>/dev/null; then
        sl_close
        return 1
    fi

    # The handler may spend a few seconds in enable/start, so the per-read
    # timeout is generous; the deadline bounds the whole request.
    deadline=$(( SECONDS + 40 ))
    while (( SECONDS < deadline )); do
        IFS= read -r -t 20 line <&"$SL_IN" || break
        type=$("$JQ" -r '.type // empty' <<<"$line" 2>/dev/null)
        case "$type" in
            evt) SERVICES_EVENTS+=("$line") ;;
            res) SERVICES_RES=$line; rc=0; break ;;
        esac
    done

    sl_close
    return "$rc"
}

services_list() {
    services_call list '[]' || return 1

    "$JQ" -e '.ok == true' <<<"$SERVICES_RES" >/dev/null 2>&1 || return 1
    "$JQ" -r '
        (.data.services // [])[]
        | [.name, .state, ((.protected // false) | tostring),
           (.boot // "auto")]
        | @tsv
    ' <<<"$SERVICES_RES"
}

services_detail() {  # services_detail <service> -> 0 res received, 1 error
    local service=${1:?service required}
    local parm

    parm=$("$JQ" -cn --arg service "$service" '[$service]') || return 1
    services_call detail "$parm"
}

services_action() {  # services_action <cmd> <service> -> 0 res received, 1 error
    local cmd=${1:?command required}
    local service=${2:?service required}
    local parm

    parm=$("$JQ" -cn --arg service "$service" '[$service]') || return 1
    services_call "$cmd" "$parm"
}

services_logs() {  # services_logs <service> -> streams until disconnected
    local service=${1:?service required}

    [ -n "$SL_SOCAT" ] || return 1
    [ -S "$SERVICES_LOG_SOCK" ] || return 1

    # The service name is the only request line. The rest of the stdin stays
    # open (terminal input is forwarded and ignored by the handler), so the
    # stream does not end before the console is closed.
    "$SL_SOCAT" - "UNIX-CONNECT:$SERVICES_LOG_SOCK" \
        < <(printf '%s\n' "$service"; cat)
}

services_result_ok() {
    [ -n "$SERVICES_RES" ] || return 1
    "$JQ" -e '.ok == true' <<<"$SERVICES_RES" >/dev/null 2>&1
}
