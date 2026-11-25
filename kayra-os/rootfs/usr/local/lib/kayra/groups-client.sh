#!/usr/bin/env bash
#
# groups-client.sh - client helpers for the Kayra group management service
#                    (source it; do not execute it).
#
# The library talks to the kayra-group-services job socket with socat-link.sh.
# It is meant for user scripts in the desktop session:
#
#     source /usr/local/lib/kayra/groups-client.sh
#
#     if ! groups_list "$USER" > /tmp/groups; then
#         echo "group service is not running"
#     fi
#
#     groups_add "$USER" video
#     for line in "${GROUPS_EVENTS[@]}"; do
#         echo "$line" | jq -r '.event'
#     done
#
# API
#   groups_call <cmd> [parm-json]
#       Sends one request. Returns 0 when a res line was received, 1 on a
#       transport error. Sets the globals below.
#   groups_list <user>
#       Prints "<name><TAB><member 0|1><TAB><hidden 0|1>" for every group.
#       Returns 1 when the service is not reachable or the request failed.
#   groups_add <user> <group>
#   groups_remove <user> <group>
#   groups_fix <user>
#       Send a mutation request. Return 0 when a res line was received, 1 on a
#       transport error. The caller reads the events/res globals.
#   groups_result_ok
#       Returns 0 when the last res has ok=true.
#
# GLOBALS
#   GROUPS_SOCK    job socket (default /run/kayra-group-services/groups.sock)
#   GROUPS_LOCK    job lock   (default /run/kayra-group-services/groups.lock)
#   GROUPS_RES     last res line, empty on a transport error
#   GROUPS_EVENTS  array of evt lines received for the last request
#
# IMPORTANT
#   groups_call, groups_add, groups_remove and groups_fix update globals in the
#   caller shell. Do not call them inside $(...) or a pipeline when the globals
#   are needed; the subshell would keep the changes. groups_list is safe in
#   $(...) because it prints its result.
#
# Used commands: socat, flock (via socat-link.sh), jq, date
#

. /usr/local/lib/kayra/socat-link.sh

GROUPS_SOCK=${GROUPS_SOCK:-/run/kayra-group-services/groups.sock}
GROUPS_LOCK=${GROUPS_LOCK:-/run/kayra-group-services/groups.lock}

GROUPS_RES=""
GROUPS_EVENTS=()

GROUPS_JQ=${SL_JQ:-$(command -v jq 2>/dev/null || true)}

groups_call() {  # groups_call <cmd> [parm-json] -> 0 res received, 1 error
    local cmd=${1:?command required}
    local parm=${2:-[]}
    local line type id req deadline rc=1

    GROUPS_RES=""
    GROUPS_EVENTS=()

    [ -n "$GROUPS_JQ" ] || return 1
    [ -n "$SL_SOCAT" ] || return 1
    [ -S "$GROUPS_SOCK" ] || return 1

    sl_wait "$GROUPS_LOCK" 10 || return 1
    sl_connect "$GROUPS_SOCK" || return 1

    id="$(date +%s%N)-$$"
    if ! req=$(sl_msg req id="$id" owner="$(sl_owner)" cmd="$cmd" parm="$parm"); then
        sl_close
        return 1
    fi

    if ! printf '%s\n' "$req" >&"$SL_OUT" 2>/dev/null; then
        sl_close
        return 1
    fi

    # A fix job may run usermod for several groups, so the per-read timeout is
    # generous; the deadline bounds the whole request.
    deadline=$(( SECONDS + 150 ))
    while (( SECONDS < deadline )); do
        IFS= read -r -t 30 line <&"$SL_IN" || break
        type=$("$GROUPS_JQ" -r '.type // empty' <<<"$line" 2>/dev/null)
        case "$type" in
            evt) GROUPS_EVENTS+=("$line") ;;
            res) GROUPS_RES=$line; rc=0; break ;;
        esac
    done

    sl_close
    return "$rc"
}

groups_list() {  # groups_list <user> -> TSV name, member, hidden
    local user=${1:?user required}
    local parm

    parm=$("$GROUPS_JQ" -cn --arg user "$user" '[$user]') || return 1
    groups_call list "$parm" || return 1

    "$GROUPS_JQ" -e '.ok == true' <<<"$GROUPS_RES" >/dev/null 2>&1 || return 1
    "$GROUPS_JQ" -r '
        (.data.groups // [])[]
        | [.name,
           (if .member then "1" else "0" end),
           (if .hidden then "1" else "0" end)]
        | @tsv
    ' <<<"$GROUPS_RES"
}

groups_add() {  # groups_add <user> <group>
    local user=${1:?user required}
    local group=${2:?group required}
    local parm

    parm=$("$GROUPS_JQ" -cn --arg user "$user" --arg group "$group" \
        '[$user, $group]') || return 1
    groups_call add "$parm"
}

groups_remove() {  # groups_remove <user> <group>
    local user=${1:?user required}
    local group=${2:?group required}
    local parm

    parm=$("$GROUPS_JQ" -cn --arg user "$user" --arg group "$group" \
        '[$user, $group]') || return 1
    groups_call remove "$parm"
}

groups_fix() {  # groups_fix <user>
    local user=${1:?user required}
    local parm

    parm=$("$GROUPS_JQ" -cn --arg user "$user" '[$user]') || return 1
    groups_call fix "$parm"
}

groups_result_ok() {
    [ -n "$GROUPS_RES" ] || return 1
    "$GROUPS_JQ" -e '.ok == true' <<<"$GROUPS_RES" >/dev/null 2>&1
}
