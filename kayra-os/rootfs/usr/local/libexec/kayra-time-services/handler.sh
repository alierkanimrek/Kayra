#!/bin/bash
#
# handler.sh - job handler of the Kayra time service (kayra-time-services).
#
# socat-link.sh starts one handler per job socket connection, with the job
# lock already held. The handler reads one NDJSON request, validates the
# requested time zone and points /etc/localtime at the matching file below
# /usr/share/zoneinfo. Every other system time setting is left untouched:
# chronyd keeps running in UTC and the hardware clock is not rewritten.
#
# Supported commands:
#   timezone <zone>   set /etc/localtime to /usr/share/zoneinfo/<zone>
#
# The time zone is validated against the real file system. Only names made of
# safe path components are accepted and the resolved path must stay below
# /usr/share/zoneinfo. The new symlink is created next to /etc/localtime and
# moved into place, so there is no moment without a time zone file.
#
# Void documents /etc/localtime as the preferred time zone location, but an
# active TIMEZONE= line in /etc/rc.conf overrides it at boot. When such a line
# exists it is commented out after the symlink was changed. The response data
# reports this with rc_conf_updated.
#
# Events:
#   timezone_set      level 1  /etc/localtime was updated
#   timezone_invalid  level 3  the requested zone is not valid
#   timezone_failed   level 4  the symlink could not be updated
#
# Response codes:
#   0 success, 3 operation failed, 4 invalid request
#
# Used commands: jq, logger, realpath, ln, chown, mv, rm, sed, grep, printf
#

set -uo pipefail
trap '' PIPE

export LC_ALL=C.UTF-8
PATH=/usr/bin:/usr/sbin:/bin:/sbin
umask 027

RUN_DIR=${RUN_DIR:-/run/kayra-time-services}
EVENTS_FILE=${EVENTS_FILE:-$RUN_DIR/events.ndjson}
ZONEINFO=${ZONEINFO:-/usr/share/zoneinfo}
LOCALTIME=${LOCALTIME:-/etc/localtime}
RC_CONF=${RC_CONF:-/etc/rc.conf}

. /usr/local/lib/kayra/socat-link.sh

if ! command -v jq >/dev/null 2>&1; then
    logger -t kayra-time-services -p user.err \
        "jq is not installed" 2>/dev/null || true
    exit 1
fi

log_svc() {  # log_svc <level> <message>
    logger -t kayra-time-services -p "user.$1" -- "$2" 2>/dev/null || true
}

timezone_data() {  # timezone_data <zone> <target> <rc-conf-updated>
    jq -cn --arg zone "$1" --arg target "$2" --argjson updated "$3" \
        '{timezone: $zone, target: $target, rc_conf_updated: $updated}'
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

invalid_request() {  # invalid_request <message>
    log_svc warn "$1"
    respond false 4 "$1" '{}'
    exit 0
}

valid_timezone() {  # valid_timezone <zone>
    local zone=${1:-} path

    [ -n "$zone" ] && (( ${#zone} <= 128 )) || return 1

    # Reject absolute paths, empty components and traversal. The regex below
    # already limits the characters; these checks make the intent explicit.
    case "$zone" in
        /*|*/|*//*|*..*|*$'\n'*|*$'\r'*) return 1 ;;
    esac
    case "/$zone/" in
        */../*|*/./*) return 1 ;;
    esac

    [[ $zone =~ ^[A-Za-z0-9._+-]+(/[A-Za-z0-9._+-]+)*$ ]] || return 1

    path=$(realpath -m -- "$ZONEINFO/$zone" 2>/dev/null) || return 1
    [ -f "$path" ] || return 1

    case "$path" in
        "$ZONEINFO"/*) ;;
        *) return 1 ;;
    esac

    return 0
}

comment_rc_conf_override() {  # prints true when the line was changed
    local changed=false

    if [ -f "$RC_CONF" ] &&
        grep -qE '^[[:space:]]*(export[[:space:]]+)?TIMEZONE=' "$RC_CONF" 2>/dev/null; then
        if sed -i -E \
            's/^([[:space:]]*)(export[[:space:]]+)?TIMEZONE=/\1#TIMEZONE=/' \
            "$RC_CONF" 2>/dev/null; then
            changed=true
        else
            log_svc warn "Could not remove the TIMEZONE override from $RC_CONF"
        fi
    fi

    printf '%s' "$changed"
}

handle_timezone() {  # handle_timezone <zone>
    local zone=$1 target tmp updated

    if ! valid_timezone "$zone"; then
        log_svc warn "Invalid time zone: ${zone:-<empty>}"
        emit_event "$SL_LVL_WARN" timezone_invalid "Invalid time zone" \
            "$(timezone_data "$zone" "" false)"
        respond false 4 "Invalid time zone" \
            "$(timezone_data "$zone" "" false)"
        return 0
    fi

    target="$ZONEINFO/$zone"
    tmp="$LOCALTIME.kayra.$$"

    rm -f -- "$tmp" 2>/dev/null || true
    if ! ln -s -- "$target" "$tmp" 2>/dev/null; then
        log_svc err "Could not create the localtime symlink"
        emit_event "$SL_LVL_ERR" timezone_failed \
            "Could not create the localtime symlink" \
            "$(timezone_data "$zone" "$target" false)"
        respond false 3 "Could not create the localtime symlink" \
            "$(timezone_data "$zone" "$target" false)"
        return 0
    fi

    # The service runs as root, so the symlink is already root owned. Keep the
    # explicit chown as a safe guard for a different service account.
    chown -h root:root "$tmp" 2>/dev/null || true

    if ! mv -Tf -- "$tmp" "$LOCALTIME" 2>/dev/null; then
        rm -f -- "$tmp" 2>/dev/null || true
        log_svc err "Could not replace $LOCALTIME"
        emit_event "$SL_LVL_ERR" timezone_failed \
            "Could not replace $LOCALTIME" \
            "$(timezone_data "$zone" "$target" false)"
        respond false 3 "Could not replace $LOCALTIME" \
            "$(timezone_data "$zone" "$target" false)"
        return 0
    fi

    updated=$(comment_rc_conf_override)

    log_svc info "Time zone set: $zone"
    emit_event "$SL_LVL_INFO" timezone_set "Time zone set: $zone" \
        "$(timezone_data "$zone" "$target" "$updated")"
    respond true 0 "Time zone set" \
        "$(timezone_data "$zone" "$target" "$updated")"
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
    timezone) need=1 ;;
    *) invalid_request "Invalid command" ;;
esac

parm_len=$(jq -r 'if (.parm | type) == "array" then (.parm | length) else -1 end' \
    <<<"$req" 2>/dev/null)
[ "$parm_len" = "$need" ] || invalid_request "Invalid request parameters"

zone=$(jq -r --argjson i 0 \
    '.parm[0] | if type == "string" then . else "" end' \
    <<<"$req" 2>/dev/null)

handle_timezone "$zone"
exit 0
