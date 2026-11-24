#!/bin/bash
#
# handler.sh - job handler of the Kayra power profile service
#              (kayra-power-services).
#
# socat-link.sh starts one handler per job socket connection, with the job
# lock already held. The handler reads one NDJSON request, validates the
# command and the profile, controls the TLP power profiles and answers with
# NDJSON event and result lines.
#
# Supported commands:
#   status                 report the active TLP profile and the known ids
#   profile <id>           set the TLP power profile
#
# Profile ids:
#   performance|balanced|power-saver   "tlpctl set <id>"
#   auto                               "tlp start" (AC/battery automatic mode)
#
# Every mutating command emits one terminal event before the response:
#   profile_set      level 1 (info)
#   profile_invalid  level 3 (warn)
#   profile_failed   level 4 (err)
#
# status is a read and is answered without an event. The event is appended to
# /run/kayra-power-services/events.ndjson and sent to the requesting client.
# The client is the user script (for example kayra-power-mode-menu.sh), so it
# can show its own notification; no separate monitor process is required.
#
# Response codes:
#   0 success, 3 operation failed, 4 invalid request
#
# Used commands: jq, logger, tlpctl, tlp
#

set -uo pipefail
trap '' PIPE

export LC_ALL=C.UTF-8
PATH=/usr/bin:/usr/sbin:/bin:/sbin
umask 027

EVENTS_FILE=${EVENTS_FILE:-/run/kayra-power-services/events.ndjson}

. /usr/local/lib/kayra/socat-link.sh

if ! command -v jq >/dev/null 2>&1; then
    logger -t kayra-power-services -p user.err "jq is not installed" 2>/dev/null || true
    exit 1
fi

if ! command -v tlpctl >/dev/null 2>&1; then
    logger -t kayra-power-services -p user.err "tlpctl is not installed" 2>/dev/null || true
    exit 1
fi

log_svc() {  # log_svc <level> <message>
    logger -t kayra-power-services -p "user.$1" -- "$2" 2>/dev/null || true
}

profile_data() {  # profile_data <profile>
    jq -cn --arg profile "$1" '{profile: $profile}'
}

emit_event() {  # emit_event <level> <event> <message> <data-json>
    local level=$1 event=$2 message=$3 data=${4:-'{}'} line

    line=$(sl_msg evt id="$id" owner="$owner" cmd="$cmd" parm="$parm" \
        level="$level" event="$event" msg="$message" data="$data") || return 1

    # Write the event stream before the client socket; ignore socket errors.
    printf '%s\n' "$line" >> "$EVENTS_FILE" 2>/dev/null || true
    printf '%s\n' "$line" 2>/dev/null || true
}

respond() {  # respond <ok> <code> <message> [data-json]
    local ok=$1 code=$2 message=$3 data=${4:-'{}'} line

    line=$(sl_msg res id="$id" owner="$owner" cmd="$cmd" parm="$parm" \
        ok="$ok" code="$code" msg="$message" data="$data") || return 1
    printf '%s\n' "$line" 2>/dev/null || true
}

active_profile() {  # prints the active profile, empty when it can not be read
    tlpctl get 2>/dev/null | head -n1 | tr -d '[:space:]'
}

handle_status() {
    local active data

    active=$(active_profile)
    data=$(jq -cn --arg profile "$active" \
        '{profile: $profile, profiles: ["performance", "balanced", "power-saver", "auto"]}')

    # status is a read: it is answered without an event so a menu open does
    # not fill the event log.
    respond true 0 "Power profile status" "$data"
}

handle_profile() {  # handle_profile <profile>
    local profile=$1 rc=0 data

    case "$profile" in
        performance|balanced|power-saver)
            data=$(profile_data "$profile")
            tlpctl set "$profile" >/dev/null 2>&1
            rc=$?
            ;;
        auto)
            data=$(profile_data "$profile")
            tlp start >/dev/null 2>&1
            rc=$?
            ;;
        *)
            log_svc warn "Invalid profile: ${profile:-<empty>}"
            emit_event "$SL_LVL_WARN" profile_invalid \
                "Invalid profile" "$(profile_data "$profile")"
            respond false 4 "Invalid profile" "$(profile_data "$profile")"
            return 0
            ;;
    esac

    if [ "$rc" -eq 0 ]; then
        log_svc info "Power profile set: $profile"
        emit_event "$SL_LVL_INFO" profile_set "Power profile set: $profile" "$data"
        respond true 0 "Power profile set: $profile" "$data"
    else
        log_svc err "Failed to set power profile: $profile"
        emit_event "$SL_LVL_ERR" profile_failed \
            "Failed to set power profile: $profile" "$data"
        respond false 3 "Failed to set power profile: $profile" "$data"
    fi
}

# ------------------------------------------------------------------
# Read and validate one request
# ------------------------------------------------------------------
IFS= read -r -t 10 -n 4097 req || exit 0
(( ${#req} <= 4096 )) || {
    log_svc warn "Request is too large"
    exit 0
}

req_type=$(jq -r '.type // empty' <<<"$req" 2>/dev/null)
[ "$req_type" = "req" ] || exit 0

id=$(jq -r '.id // empty' <<<"$req" 2>/dev/null)
owner=$(jq -r '.owner // "unknown"' <<<"$req" 2>/dev/null)
cmd=$(jq -r '.cmd // empty' <<<"$req" 2>/dev/null)
parm=$(jq -c 'if ((.parm | type) == "array") or ((.parm | type) == "object")
              then .parm else [] end' <<<"$req" 2>/dev/null)
[ -n "$parm" ] || parm='[]'

case "$cmd" in
    status)
        handle_status
        exit 0
        ;;
    profile)
        ;;
    *)
        log_svc warn "Invalid command: ${cmd:-<empty>}"
        respond false 4 "Invalid command" '{}'
        exit 0
        ;;
esac

profile=$(jq -r 'if (.parm | type) == "array" then (.parm[0] // "") else "" end' \
    <<<"$req" 2>/dev/null)

handle_profile "$profile"
exit 0
