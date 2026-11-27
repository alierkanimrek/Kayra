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
# Commands:
#   list                 list the services in /etc/sv with state and boot policy
#   start <service>      "sv up" (the service must be enabled)
#   stop <service>       "sv down" now; it starts again at boot
#   restart <service>    "sv restart", with a down/up fallback
#   enable <service>     link /var/service, remove the down file, "sv up"
#   disable <service>    "sv down" and remove the /var/service link
#   boot-off <service>   create /etc/sv/<service>/down (no start at boot)
#   boot-on <service>    remove /etc/sv/<service>/down
#   check <service>      "sv check", read-only
#   once <service>       "sv once", run a stopped service once
#   detail <service>     state, pid, uptime and check result (no log lines)
#
# States:
#   running   the /var/service link exists, "sv status" reports run:
#   down      the link exists, "sv status" reports down:
#   failed    the link exists, "sv status" reports fail:/finish:
#   disabled  there is no /var/service link
#
# The boot policy is separate from the state: /etc/sv/<service>/down exists
# means the service does not start at boot ("manual"). "sv down" does NOT
# create that file, so a stopped service starts again at boot until boot-off
# is used.
#
# Every mutating command emits one terminal event before the response:
#   started, stopped, restarted, enabled, disabled   level 1 (info)
#   boot_off, boot_on, once                          level 1 (info)
#   protected, notfound                              level 3 (warn)
#   failed                                           level 4 (err)
#
# check and detail are read-only and emit no event.
#
# The event is appended to /run/kayra-system-services/events.ndjson and sent
# to the requesting client. The client is the user script (for example
# kayra-toggle-service.sh), so it can show its own notification; no separate
# monitor process is required.
#
# Response codes:
#   0 success, 1 not found, 2 protected, 3 operation failed, 4 invalid request
#
# Used commands: jq, sv, ln, rm, install, readlink, sleep, timeout, head,
#                awk, logger, settings-conf.sh (system_conf_get)
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
# stopped, restarted, disabled or set to a manual boot. kayra-system-services
# protects itself as well. The list is system wide data read from
# /etc/default/kayra.conf (key: protected_services) with settings-conf.sh, so
# it stays in sync with the deployed defaults. DEFAULT_PROTECTED_SERVICES is
# only a safety fallback used when the file or the key is missing, so a broken
# config never disables the protection.
DEFAULT_PROTECTED_SERVICES=(
    dbus
    greetd
    socklog-unix
    nanoklogd
    polkitd
    kayra-system-services
    kayra-system-logs
    kayra-group-services
    kayra-power-services
)

. /usr/local/lib/kayra/socat-link.sh
. /usr/local/lib/kayra/settings-conf.sh

# Service names never contain spaces, so splitting on whitespace is safe.
PROTECTED_SERVICES_STR="$(system_conf_get protected_services | head -n1 || true)"
if [ -n "$PROTECTED_SERVICES_STR" ]; then
    read -ra PROTECTED_SERVICES <<< "$PROTECTED_SERVICES_STR"
else
    PROTECTED_SERVICES=( "${DEFAULT_PROTECTED_SERVICES[@]}" )
fi

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

link_exists() {  # link_exists <service>
    [ -e "$SERVICE_DIR/$1" ] || [ -L "$SERVICE_DIR/$1" ]
}

down_file() {  # down_file <service>
    printf '%s/%s/down' "$SV_DIR" "$1"
}

service_status_line() {  # service_status_line <service>
    sv status "$SERVICE_DIR/$1" 2>/dev/null | head -n 1
}

service_state() {  # service_state <service> -> running|down|failed|disabled
    local service=$1 line

    if ! link_exists "$service"; then
        printf 'disabled\n'
        return 0
    fi

    line=$(service_status_line "$service")
    case "$line" in
        run:*)    printf 'running\n' ;;
        down:*)   printf 'down\n' ;;
        *)        printf 'failed\n' ;;
    esac
}

service_running() {  # service_running <service>
    [ "$(service_state "$1")" = "running" ]
}

wait_for_state() {  # wait_for_state <service> running|not-running <seconds>
    local service=$1 want=$2 seconds=$3 i=0

    while [ "$i" -lt "$seconds" ]; do
        case "$want" in
            running)
                service_running "$service" && return 0
                ;;
            not-running)
                service_running "$service" || return 0
                ;;
        esac
        sleep 1
        i=$((i + 1))
    done

    return 1
}

status_pid() {  # status_pid <sv-status-line>
    awk '{
        for (i = 1; i <= NF; i++) {
            if ($i == "(pid") {
                pid = $(i + 1)
                sub(/\)$/, "", pid)
                print pid
                exit
            }
        }
    }' <<<"$1"
}

status_uptime() {  # status_uptime <sv-status-line>
    awk '{
        for (i = 1; i <= NF; i++) {
            if ($i == "(pid") {
                uptime = $(i + 2)
                sub(/,$/, "", uptime)
                print uptime
                exit
            }
        }
    }' <<<"$1"
}

enable_link() {  # enable_link <service>
    local service=$1 link="$SERVICE_DIR/$1" i=0 expected target

    expected=$(readlink -f -- "$SV_DIR/$service" 2>/dev/null || true)
    [ -n "$expected" ] || return 1

    if [ -L "$link" ]; then
        target=$(readlink -f -- "$link" 2>/dev/null || true)
        [ "$target" = "$expected" ] && return 0
        rm -f -- "$link" || return 1
    elif [ -e "$link" ]; then
        # Never replace a real directory with a symlink.
        return 1
    fi

    ln -s "$SV_DIR/$service" "$link" || return 1

    # runsvdir needs a moment to pick up the new service directory.
    while [ "$i" -lt 6 ]; do
        [ -e "$link/supervise/ok" ] && return 0
        sleep 1
        i=$((i + 1))
    done

    return 1
}

disable_service() {  # disable_service <service>
    local service=$1 link="$SERVICE_DIR/$1" target expected i=0

    if ! link_exists "$service"; then
        return 0
    fi

    if [ ! -L "$link" ]; then
        log_svc err "Refusing to remove a non-symlink: $link"
        return 1
    fi

    target=$(readlink -f -- "$link" 2>/dev/null || true)
    expected=$(readlink -f -- "$SV_DIR/$service" 2>/dev/null || true)
    if [ -z "$target" ] || [ "$target" != "$expected" ]; then
        log_svc err "Refusing to remove a link outside $SV_DIR: $link"
        return 1
    fi

    # Stop the service before the link disappears; runsvdir terminates runsv
    # as soon as the link is gone, but this keeps the shutdown orderly.
    sv down "$link" >/dev/null 2>&1 || true

    while [ "$i" -lt 5 ]; do
        [ "$(service_state "$service")" != "running" ] && break
        sleep 1
        i=$((i + 1))
    done

    if [ "$(service_state "$service")" = "running" ]; then
        log_svc err "Service is still running, not disabling: $service"
        return 1
    fi

    rm -f -- "$link" || return 1

    if [ -e "$link" ] || [ -L "$link" ]; then
        log_svc err "Service link still exists: $link"
        return 1
    fi

    return 0
}

check_service() {  # check_service <service>; sets CHECK_OK and CHECK_MSG
    local service=$1 output rc

    if ! link_exists "$service"; then
        CHECK_OK=false
        CHECK_MSG="service is not enabled"
        return 0
    fi

    output=$(timeout 8 sv check "$SERVICE_DIR/$service" 2>&1)
    rc=$?

    if [ "$rc" -eq 0 ]; then
        CHECK_OK=true
        CHECK_MSG="$output"
    elif [ "$rc" -eq 124 ]; then
        CHECK_OK=false
        CHECK_MSG="check timed out"
    else
        CHECK_OK=false
        CHECK_MSG="$output"
    fi
}

list_services() {  # prints "name<TAB>state<TAB>protected<TAB>boot"
    local dir name state boot protected

    for dir in "$SV_DIR"/*; do
        [ -d "$dir" ] || continue
        name=${dir##*/}

        state=$(service_state "$name")

        if [ -e "$SV_DIR/$name/down" ]; then boot="manual"; else boot="auto"; fi
        if is_protected "$name"; then protected="true"; else protected="false"; fi
        printf '%s\t%s\t%s\t%s\n' "$name" "$state" "$protected" "$boot"
    done | sort
}

handle_list() {
    local list resp_data

    list=$(list_services)
    resp_data=$(printf '%s\n' "$list" | jq -R -s '
        split("\n")
        | map(select(length > 0) | split("\t") |
              {name: .[0], state: .[1], protected: (.[2] == "true"),
               boot: (.[3] // "auto")})
        | {services: .}
    ') || resp_data='{"services":[]}'

    respond true 0 "" "$resp_data"
}

handle_check() {  # handle_check <service>
    local service=$1 data

    if [ ! -d "$SV_DIR/$service" ]; then
        log_svc warn "Service not found: $service"
        respond false 1 "Service not found: $service" \
            "$(event_data "$service" "check")"
        return 0
    fi

    check_service "$service"
    data=$(jq -cn --arg service "$service" \
        --argjson ok "$CHECK_OK" --arg message "$CHECK_MSG" \
        '{service: $service, ok: $ok, message: $message}')

    respond true 0 "" "$data"
}

handle_detail() {  # handle_detail <service>
    local service=$1
    local state boot status_line pid uptime protected_flag detail

    if [ ! -d "$SV_DIR/$service" ]; then
        log_svc warn "Service not found: $service"
        respond false 1 "Service not found: $service" \
            "$(event_data "$service" "detail")"
        return 0
    fi

    state=$(service_state "$service")
    if [ -e "$SV_DIR/$service/down" ]; then boot="manual"; else boot="auto"; fi
    status_line=$(service_status_line "$service")

    # "(pid 0)" and the time in a down: line are not a running process.
    if [ "$state" = "running" ]; then
        pid=$(status_pid "$status_line")
        uptime=$(status_uptime "$status_line")
    else
        pid=""
        uptime=""
    fi

    check_service "$service"

    if is_protected "$service"; then protected_flag=true; else protected_flag=false; fi

    detail=$(jq -cn \
        --arg name "$service" \
        --arg state "$state" \
        --arg boot "$boot" \
        --arg status "$status_line" \
        --arg pid "$pid" \
        --arg uptime "$uptime" \
        --argjson check_ok "$CHECK_OK" \
        --arg check_message "$CHECK_MSG" \
        --argjson protected "$protected_flag" \
        '{
            name: $name,
            state: $state,
            boot: $boot,
            status: $status,
            pid: $pid,
            uptime: $uptime,
            protected: $protected,
            check: {ok: $check_ok, message: $check_message}
        }')

    respond true 0 "" "$detail"
}

handle_action() {  # handle_action <action> <service>
    local action=$1 service=$2
    local data state restarted_ok had_down

    data=$(event_data "$service" "$action")

    if [ ! -d "$SV_DIR/$service" ]; then
        log_svc warn "Service not found: $service"
        emit_event "$SL_LVL_WARN" notfound "Service not found: $service" "$data"
        respond false 1 "Service not found: $service" "$data"
        return 0
    fi

    case "$action" in
        stop|restart|disable|boot-off|once)
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
            if ! link_exists "$service"; then
                fail_action "$action" "$service" "service is not enabled"
                return 0
            fi
            sv up "$SERVICE_DIR/$service" >/dev/null 2>&1 || true
            if wait_for_state "$service" running 6; then
                log_svc info "Service started: $service"
                emit_event "$SL_LVL_INFO" started \
                    "Service started: $service" "$data"
                respond true 0 "Service started: $service" "$data"
            else
                fail_action "$action" "$service" "sv up failed"
            fi
            ;;
        stop)
            if ! link_exists "$service"; then
                fail_action "$action" "$service" "service is not enabled"
                return 0
            fi
            sv down "$SERVICE_DIR/$service" >/dev/null 2>&1 || true
            if wait_for_state "$service" not-running 6; then
                log_svc info "Service stopped: $service"
                emit_event "$SL_LVL_INFO" stopped \
                    "Service stopped: $service" "$data"
                respond true 0 "Service stopped: $service" "$data"
            else
                fail_action "$action" "$service" "sv down failed"
            fi
            ;;
        restart)
            if ! link_exists "$service"; then
                fail_action "$action" "$service" "service is not enabled"
                return 0
            fi
            restarted_ok=0
            if sv restart "$SERVICE_DIR/$service" >/dev/null 2>&1; then
                wait_for_state "$service" running 6 && restarted_ok=1
            fi
            if [ "$restarted_ok" -eq 0 ]; then
                # Fall back to a manual down + up when "sv restart" fails.
                sv down "$SERVICE_DIR/$service" >/dev/null 2>&1 || true
                sleep 1
                sv up "$SERVICE_DIR/$service" >/dev/null 2>&1 || true
                wait_for_state "$service" running 6 && restarted_ok=1
            fi
            if [ "$restarted_ok" -eq 1 ]; then
                log_svc info "Service restarted: $service"
                emit_event "$SL_LVL_INFO" restarted \
                    "Service restarted: $service" "$data"
                respond true 0 "Service restarted: $service" "$data"
            else
                fail_action "$action" "$service" "sv restart failed"
            fi
            ;;
        enable)
            if ! enable_link "$service"; then
                fail_action "$action" "$service" "could not enable the service"
                return 0
            fi
            if ! rm -f -- "$(down_file "$service")"; then
                fail_action "$action" "$service" "could not remove the down file"
                return 0
            fi
            sv up "$SERVICE_DIR/$service" >/dev/null 2>&1 || true
            if wait_for_state "$service" running 6; then
                log_svc info "Service enabled and started: $service"
                emit_event "$SL_LVL_INFO" enabled \
                    "Service enabled and started: $service" "$data"
                respond true 0 "Service enabled and started: $service" "$data"
            else
                fail_action "$action" "$service" "sv up failed after enabling"
            fi
            ;;
        disable)
            if disable_service "$service"; then
                log_svc info "Service disabled: $service"
                emit_event "$SL_LVL_INFO" disabled \
                    "Service disabled: $service" "$data"
                respond true 0 "Service disabled: $service" "$data"
            else
                fail_action "$action" "$service" "could not disable the service"
            fi
            ;;
        boot-off)
            had_down=0
            [ -e "$(down_file "$service")" ] && had_down=1

            if install -m 0644 -o root -g root /dev/null \
                "$(down_file "$service")" 2>/dev/null; then
                log_svc info "Service set to manual boot: $service"
                emit_event "$SL_LVL_INFO" boot_off \
                    "Service will not start at boot: $service" "$data"
                respond true 0 "Service will not start at boot: $service" "$data"
            else
                # Do not leave a half-created down file behind.
                if [ "$had_down" -eq 0 ]; then
                    rm -f -- "$(down_file "$service")" 2>/dev/null || true
                fi
                fail_action "$action" "$service" "could not create the down file"
            fi
            ;;
        boot-on)
            if rm -f -- "$(down_file "$service")" 2>/dev/null; then
                log_svc info "Service set to automatic boot: $service"
                emit_event "$SL_LVL_INFO" boot_on \
                    "Service will start at boot: $service" "$data"
                respond true 0 "Service will start at boot: $service" "$data"
            else
                fail_action "$action" "$service" "could not remove the down file"
            fi
            ;;
        once)
            state=$(service_state "$service")
            case "$state" in
                disabled)
                    fail_action "$action" "$service" "service is not enabled"
                    return 0
                    ;;
                running)
                    fail_action "$action" "$service" "service is already running"
                    return 0
                    ;;
            esac
            if sv once "$SERVICE_DIR/$service" >/dev/null 2>&1; then
                log_svc info "Service run once: $service"
                emit_event "$SL_LVL_INFO" once \
                    "Service run once: $service" "$data"
                respond true 0 "Service run once: $service" "$data"
            else
                fail_action "$action" "$service" "sv once failed"
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
    start|stop|restart|enable|disable|boot-off|boot-on|check|once|detail)
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

case "$cmd" in
    check)
        handle_check "$service"
        ;;
    detail)
        handle_detail "$service"
        ;;
    *)
        handle_action "$cmd" "$service"
        ;;
esac

exit 0
