#!/bin/bash
#
# handler.sh - job handler of the Kayra system service manager
#              (kayra-system-services).
#
# socat-link.sh starts one handler per job socket connection, with the job
# lock already held. The handler reads one NDJSON request, validates the
# command and the service name, runs the runit command and answers with NDJSON
# event and result lines.
#
# Supported commands:
#   list                 list the services in /etc/sv with their state
#   start <service>      enable the service link when needed and "sv up"
#   stop <service>       "sv down"
#   restart <service>    "sv restart", with a down/up fallback
#   enable <service>     create the service link and "sv up"
#
# Every mutating command emits one terminal event before the response:
#   started, stopped, restarted, enabled   level 1 (info)
#   protected, notfound                    level 3 (warn)
#   failed                                 level 4 (err)
#
# The event is appended to /run/kayra-system-services/events.ndjson and sent
# to the requesting client. The client is the user script (for example
# kayra-toggle-service.sh), so it can show its own notification; no separate
# monitor process is required.
#
# Response codes:
#   0 success, 1 not found, 2 protected, 3 operation failed, 4 invalid request
#
# Used commands: jq, sv, ln, sleep, head, logger
#

set -uo pipefail
trap '' PIPE

export LC_ALL=C.UTF-8
PATH=/usr/bin:/usr/sbin:/bin:/sbin
umask 027

SV_DIR=${SV_DIR:-/etc/sv}
SERVICE_DIR=${SERVICE_DIR:-/var/service}
EVENTS_FILE=${EVENTS_FILE:-/run/kayra-system-services/events.ndjson}

# Services that must stay running. They can be started or enabled, but not
# stopped or restarted. kayra-system-services protects itself as well.
PROTECTED_SERVICES=(
    dbus
    greetd
    socklog-unix
    nanoklogd
    polkitd
    kayra-system-services
)

. /usr/local/lib/kayra/socat-link.sh

if ! command -v jq >/dev/null 2>&1; then
    logger -t kayra-system-services -p user.err "jq is not installed" 2>/dev/null || true
    exit 1
fi

log_svc() {  # log_svc <level> <message>
    logger -t kayra-system-services -p "user.$1" -- "$2" 2>/dev/null || true
}

is_protected() {  # is_protected <service>
    local service=$1 protected
    for protected in "${PROTECTED_SERVICES[@]}"; do
        [ "$protected" = "$service" ] && return 0
    done
    return 1
}

valid_service_name() {  # valid_service_name <service>
    local name=$1

    [[ $name =~ ^[A-Za-z0-9._@+-]+$ ]] || return 1
    [ "$name" != "." ] && [ "$name" != ".." ] || return 1
    (( ${#name} <= 64 )) || return 1
    return 0
}

event_data() {  # event_data <service> <action>
    jq -cn --arg service "$1" --arg action "$2" \
        '{service: $service, action: $action}'
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

fail_action() {  # fail_action <action> <service> <reason>
    local action=$1 service=$2 reason=$3
    local message="Failed to $action service $service"

    [ -n "$reason" ] && message="$message: $reason"
    log_svc err "$message"
    emit_event "$SL_LVL_ERR" failed "$message" "$(event_data "$service" "$action")"
    respond false 3 "$message" "$(event_data "$service" "$action")"
}

service_running() {  # service_running <service>
    local status_line
    status_line=$(sv status "$SERVICE_DIR/$1" 2>/dev/null | head -n 1)
    case "$status_line" in
        run:*) return 0 ;;
        *)     return 1 ;;
    esac
}

enable_link() {  # enable_link <service>
    local service=$1 link="$SERVICE_DIR/$1" i=0

    [ -e "$link" ] && return 0

    ln -sfn "$SV_DIR/$service" "$link" || return 1

    # runsvdir needs a moment to pick up the new service directory.
    while [ "$i" -lt 6 ]; do
        [ -e "$link/supervise/ok" ] && break
        sleep 1
        i=$((i + 1))
    done

    return 0
}

list_services() {  # prints "name<TAB>state<TAB>protected", sorted by name
    local dir name state status_line protected

    for dir in "$SV_DIR"/*; do
        [ -d "$dir" ] || continue
        name=${dir##*/}

        if [ -e "$SERVICE_DIR/$name" ]; then
            status_line=$(sv status "$SERVICE_DIR/$name" 2>/dev/null | head -n 1)
            case "$status_line" in
                run:*) state="running" ;;
                *)     state="stopped" ;;
            esac
        else
            state="disabled"
        fi

        if is_protected "$name"; then protected="true"; else protected="false"; fi
        printf '%s\t%s\t%s\n' "$name" "$state" "$protected"
    done | sort
}

handle_list() {
    local list resp_data

    list=$(list_services)
    resp_data=$(printf '%s\n' "$list" | jq -R -s '
        split("\n")
        | map(select(length > 0) | split("\t") |
              {name: .[0], state: .[1], protected: (.[2] == "true")})
        | {services: .}
    ') || resp_data='{"services":[]}'

    respond true 0 "" "$resp_data"
}

handle_action() {  # handle_action <action> <service>
    local action=$1 service=$2
    local data

    data=$(event_data "$service" "$action")

    if [ ! -d "$SV_DIR/$service" ]; then
        log_svc warn "Service not found: $service"
        emit_event "$SL_LVL_WARN" notfound "Service not found: $service" "$data"
        respond false 1 "Service not found: $service" "$data"
        return 0
    fi

    case "$action" in
        stop|restart)
            if is_protected "$service"; then
                log_svc warn "Service is protected: $service"
                emit_event "$SL_LVL_WARN" protected \
                    "Service is protected: $service" "$data"
                respond false 2 "Service is protected: $service" "$data"
                return 0
            fi
            ;;
    esac

    case "$action" in
        start)
            if ! enable_link "$service"; then
                fail_action "$action" "$service" "could not enable the service"
                return 0
            fi
            sv up "$SERVICE_DIR/$service" >/dev/null 2>&1 || true
            sleep 1
            if service_running "$service"; then
                log_svc info "Service started: $service"
                emit_event "$SL_LVL_INFO" started \
                    "Service started: $service" "$data"
                respond true 0 "Service started: $service" "$data"
            else
                fail_action "$action" "$service" "sv up failed"
            fi
            ;;
        stop)
            if sv down "$SERVICE_DIR/$service" >/dev/null 2>&1; then
                log_svc info "Service stopped: $service"
                emit_event "$SL_LVL_INFO" stopped \
                    "Service stopped: $service" "$data"
                respond true 0 "Service stopped: $service" "$data"
            else
                sleep 1
                if ! service_running "$service"; then
                    log_svc info "Service stopped: $service"
                    emit_event "$SL_LVL_INFO" stopped \
                        "Service stopped: $service" "$data"
                    respond true 0 "Service stopped: $service" "$data"
                else
                    fail_action "$action" "$service" "sv down failed"
                fi
            fi
            ;;
        restart)
            if sv restart "$SERVICE_DIR/$service" >/dev/null 2>&1; then
                log_svc info "Service restarted: $service"
                emit_event "$SL_LVL_INFO" restarted \
                    "Service restarted: $service" "$data"
                respond true 0 "Service restarted: $service" "$data"
            else
                # Fall back to a manual down + up when "sv restart" fails.
                sv down "$SERVICE_DIR/$service" >/dev/null 2>&1 || true
                sleep 1
                sv up "$SERVICE_DIR/$service" >/dev/null 2>&1 || true
                sleep 1
                if service_running "$service"; then
                    log_svc info "Service restarted: $service"
                    emit_event "$SL_LVL_INFO" restarted \
                        "Service restarted: $service" "$data"
                    respond true 0 "Service restarted: $service" "$data"
                else
                    fail_action "$action" "$service" "sv restart failed"
                fi
            fi
            ;;
        enable)
            if ! enable_link "$service"; then
                fail_action "$action" "$service" "could not enable the service"
                return 0
            fi
            sv up "$SERVICE_DIR/$service" >/dev/null 2>&1 || true
            sleep 1
            if service_running "$service"; then
                log_svc info "Service enabled and started: $service"
                emit_event "$SL_LVL_INFO" enabled \
                    "Service enabled and started: $service" "$data"
                respond true 0 "Service enabled and started: $service" "$data"
            else
                fail_action "$action" "$service" "sv up failed after enabling"
            fi
            ;;
    esac
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
    list)
        handle_list
        exit 0
        ;;
    start|stop|restart|enable)
        ;;
    *)
        log_svc warn "Invalid command: ${cmd:-<empty>}"
        respond false 4 "Invalid command" '{}'
        exit 0
        ;;
esac

service=$(jq -r 'if (.parm | type) == "array" then (.parm[0] // "") else "" end' \
    <<<"$req" 2>/dev/null)

if ! valid_service_name "$service"; then
    log_svc warn "Invalid service name: ${service:-<empty>}"
    respond false 4 "Invalid service name" '{}'
    exit 0
fi

handle_action "$cmd" "$service"
exit 0
