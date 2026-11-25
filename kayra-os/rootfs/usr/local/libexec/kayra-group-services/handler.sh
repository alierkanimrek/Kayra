#!/bin/bash
#
# handler.sh - job handler of the Kayra group management service
#              (kayra-group-services).
#
# socat-link.sh starts one handler per job socket connection, with the job lock
# already held. The handler reads one NDJSON request, validates the command, the
# target user and the group, applies the change with usermod/gpasswd and answers
# with NDJSON event and result lines.
#
# Supported commands:
#   list   [user]         list groups with the membership and internal flags
#   add    [user group]   add the user to the group (usermod -aG)
#   remove [user group]   remove the user from the group (gpasswd -d)
#   fix    [user]         add the required groups from /etc/default/kayra.conf
#
# The required group list is system wide data read from /etc/default/kayra.conf
# (key: required_groups) with settings-conf.sh. The exception policy of the
# remove command (which groups a user may not leave) is handled by the client;
# the service only refuses the primary group. The list response still reports
# the required groups so the client can draw its menu consistently.
#
# Every mutating command emits one terminal event before the response:
#   added, removed, fixed       level 1 (info)
#   unchanged                   level 1 (info)
#   notfound                    level 3 (warn)
#   failed                      level 4 (err)
#
# Response codes:
#   0 success, 1 user or group not found, 3 operation failed,
#   4 invalid request, 5 target user not allowed
#
# Used commands: jq, usermod, gpasswd, id, getent, timeout, logger, awk,
#                settings-conf.sh (system_conf_get)
#

set -uo pipefail
trap '' PIPE

export LC_ALL=C.UTF-8
PATH=/usr/bin:/usr/sbin:/bin:/sbin
umask 027

EVENTS_FILE=${EVENTS_FILE:-/run/kayra-group-services/events.ndjson}

. /usr/local/lib/kayra/socat-link.sh
. /usr/local/lib/kayra/settings-conf.sh

if ! command -v jq >/dev/null 2>&1; then
    logger -t kayra-group-services -p user.err \
        "jq is not installed" 2>/dev/null || true
    exit 1
fi

# Regular user id range. login.defs is authoritative; the fallbacks keep the
# service working when the file is missing.
UID_MIN=$(awk '$1 == "UID_MIN" { print $2; exit }' /etc/login.defs 2>/dev/null)
UID_MAX=$(awk '$1 == "UID_MAX" { print $2; exit }' /etc/login.defs 2>/dev/null)
[[ $UID_MIN =~ ^[0-9]+$ ]] || UID_MIN=1000
[[ $UID_MAX =~ ^[0-9]+$ ]] || UID_MAX=65533

log_svc() {  # log_svc <level> <message>
    logger -t kayra-group-services -p "user.$1" -- "$2" 2>/dev/null || true
}

valid_user_name() {  # valid_user_name <user>
    local name=$1

    [[ $name =~ ^[a-z_][a-z0-9_-]*$ ]] || return 1
    (( ${#name} <= 32 )) || return 1
    return 0
}

valid_group_name() {  # valid_group_name <group>
    local name=$1

    # The first character may not be "-", so the name can never be read as an
    # option by usermod or gpasswd.
    [[ $name =~ ^[A-Za-z0-9._][A-Za-z0-9._-]*$ ]] || return 1
    (( ${#name} <= 32 )) || return 1
    return 0
}

user_uid() {  # user_uid <user>
    getent passwd "$1" 2>/dev/null |
        awk -F: -v user="$1" '$1 == user { print $3; exit }'
}

user_primary_group() {  # user_primary_group <user>
    local gid

    gid=$(getent passwd "$1" 2>/dev/null |
        awk -F: -v user="$1" '$1 == user { print $4; exit }')
    [ -n "$gid" ] || return 1
    getent group "$gid" 2>/dev/null | awk -F: '{ print $1; exit }'
}

user_group_list() {  # user_group_list <user> -> " g1 g2 g3 "
    printf ' %s ' "$(id -Gn "$1" 2>/dev/null | tr ' ' '\n' | sort -u | tr '\n' ' ')"
}

user_is_member() {  # user_is_member <user> <group>
    local user=$1 group=$2 primary members

    primary=$(user_primary_group "$user" 2>/dev/null || true)
    [ "$primary" = "$group" ] && return 0

    members=$(user_group_list "$user")
    [[ $members == *" $group "* ]]
}

group_exists() {  # group_exists <group>
    getent group "$1" >/dev/null 2>&1
}

target_user_allowed() {  # target_user_allowed <user>
    local user=$1 uid

    valid_user_name "$user" || return 1
    uid=$(user_uid "$user")
    [ -n "$uid" ] || return 1
    (( uid != 0 )) || return 1
    (( uid >= UID_MIN && uid <= UID_MAX )) || return 1
    return 0
}

event_data() {  # event_data <user> [group]
    jq -cn --arg user "$1" --arg group "${2:-}" '
        {user: $user} + (if $group == "" then {} else {group: $group} end)
    '
}

required_groups_json() {
    local str

    str=$(system_conf_get required_groups | head -n1 || true)
    jq -cn --arg str "$str" '$str | split(" ") | map(select(length > 0))'
}

groups_json() {  # groups_json <user> -> array of the current group names
    jq -cn --arg str "$(id -Gn "$1" 2>/dev/null | tr ' ' '\n' | sort -u | tr '\n' ' ')" '
        $str | split(" ") | map(select(length > 0))
    '
}

list_groups_json() {  # list_groups_json <user>
    local user=$1 primary members

    primary=$(user_primary_group "$user" 2>/dev/null || true)
    members=$(user_group_list "$user")

    getent group 2>/dev/null | awk -F: -v members="$members" -v primary="$primary" '
        $1 == "" { next }
        {
            member = ($1 == primary || index(members, " " $1 " ") > 0) ? 1 : 0
            hidden = ($1 ~ /^_/) ? 1 : 0
            print $1 "\t" member "\t" hidden
        }
    ' | jq -R -s '
        split("\n")
        | map(select(length > 0) | split("\t") |
              {name: .[0], member: (.[1] == "1"), hidden: (.[2] == "1")})
    '
}

result_data() {  # result_data <user> <group> <changed>
    jq -cn --arg user "$1" --arg group "$2" --argjson changed "$3" \
        --argjson groups "$(groups_json "$1")" '
        {user: $user, group: $group, changed: $changed, groups: $groups}
    '
}

fix_data() {  # fix_data <user> <added-json> <skipped-json>
    jq -cn --arg user "$1" --argjson added "$2" --argjson skipped "$3" \
        --argjson groups "$(groups_json "$1")" '
        {user: $user, added: $added, skipped: $skipped, groups: $groups}
    '
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

fail_action() {  # fail_action <action> <user> <group> <reason>
    local action=$1 user=$2 group=$3 reason=$4 message

    if [ -n "$group" ]; then
        message="Failed to $action group $group for user $user"
    else
        message="Failed to $action groups for user $user"
    fi
    [ -n "$reason" ] && message="$message: $reason"

    log_svc err "$message"
    emit_event "$SL_LVL_ERR" failed "$message" "$(event_data "$user" "$group")"
    respond false 3 "$message" "$(event_data "$user" "$group")"
}

# ------------------------------------------------------------------
# Command handlers
# ------------------------------------------------------------------
handle_list() {  # handle_list <user>
    local user=$1 groups required primary data

    groups=$(list_groups_json "$user") || groups='[]'
    required=$(required_groups_json) || required='[]'
    primary=$(user_primary_group "$user" 2>/dev/null || true)

    data=$(jq -cn --arg user "$user" --arg primary "$primary" \
        --argjson required "$required" --argjson groups "$groups" '
        {user: $user, primary: $primary, required: $required, groups: $groups}
    ') || data='{"groups":[],"required":[]}'

    respond true 0 "" "$data"
}

handle_add() {  # handle_add <user> <group>
    local user=$1 group=$2

    if ! group_exists "$group"; then
        log_svc warn "Group not found: $group"
        emit_event "$SL_LVL_WARN" notfound "Group not found: $group" \
            "$(event_data "$user" "$group")"
        respond false 1 "Group not found: $group" "$(event_data "$user" "$group")"
        return 0
    fi

    # Groups starting with "_" are allocated system groups; they are never
    # offered to or accepted from a desktop user.
    if [[ $group == _* ]]; then
        log_svc warn "Internal group can not be added: $group"
        respond false 4 "Internal group can not be added" \
            "$(event_data "$user" "$group")"
        return 0
    fi

    if user_is_member "$user" "$group"; then
        log_svc info "User $user is already a member of $group"
        emit_event "$SL_LVL_INFO" unchanged \
            "User $user is already a member of group $group" \
            "$(event_data "$user" "$group")"
        respond true 0 "User is already a member of the group" \
            "$(result_data "$user" "$group" false)"
        return 0
    fi

    if ! timeout 60 usermod -aG "$group" "$user" >/dev/null 2>&1; then
        fail_action add "$user" "$group" "usermod failed"
        return 0
    fi

    log_svc info "User $user added to group $group"
    emit_event "$SL_LVL_INFO" added "User $user added to group $group" \
        "$(event_data "$user" "$group")"
    respond true 0 "User added to group" "$(result_data "$user" "$group" true)"
}

handle_remove() {  # handle_remove <user> <group>
    local user=$1 group=$2 primary

    if ! group_exists "$group"; then
        log_svc warn "Group not found: $group"
        emit_event "$SL_LVL_WARN" notfound "Group not found: $group" \
            "$(event_data "$user" "$group")"
        respond false 1 "Group not found: $group" "$(event_data "$user" "$group")"
        return 0
    fi

    primary=$(user_primary_group "$user" 2>/dev/null || true)
    if [ "$primary" = "$group" ]; then
        log_svc warn "The primary group can not be removed: $group"
        respond false 4 "The primary group can not be removed" \
            "$(event_data "$user" "$group")"
        return 0
    fi

    if ! user_is_member "$user" "$group"; then
        log_svc info "User $user is not a member of $group"
        emit_event "$SL_LVL_INFO" unchanged \
            "User $user is not a member of group $group" \
            "$(event_data "$user" "$group")"
        respond true 0 "User is not a member of the group" \
            "$(result_data "$user" "$group" false)"
        return 0
    fi

    # gpasswd -d only touches this one group record, so the other group
    # memberships can not be lost by a stale list.
    if ! timeout 60 gpasswd -d "$user" "$group" >/dev/null 2>&1; then
        fail_action remove "$user" "$group" "gpasswd failed"
        return 0
    fi

    log_svc info "User $user removed from group $group"
    emit_event "$SL_LVL_INFO" removed "User $user removed from group $group" \
        "$(event_data "$user" "$group")"
    respond true 0 "User removed from group" \
        "$(result_data "$user" "$group" true)"
}

handle_fix() {  # handle_fix <user>
    local user=$1 required available members plan status group
    local -a add_groups=() skip_groups=()
    local added_json skipped_json missing_csv

    required=$(required_groups_json) || required='[]'
    available=$(getent group 2>/dev/null | cut -d: -f1 | sort -u | tr '\n' ' ')
    available=" $available "
    members=$(user_group_list "$user")

    # One line per required group: "add<TAB>name" or "skip<TAB>name".
    mapfile -t plan < <(
        jq -r '.[]' <<<"$required" | awk -F'\t' \
            -v available="$available" -v members="$members" '
            NF == 0 { next }
            index(available, " " $0 " ") == 0 { print "skip\t" $0; next }
            index(members, " " $0 " ") == 0 { print "add\t" $0 }
        '
    )

    for line in "${plan[@]}"; do
        [ -n "$line" ] || continue
        status=${line%%$'\t'*}
        group=${line#*$'\t'}
        valid_group_name "$group" || continue
        case "$status" in
            add)  add_groups+=("$group") ;;
            skip) skip_groups+=("$group") ;;
        esac
    done

    added_json=$(printf '%s\n' "${add_groups[@]+"${add_groups[@]}"}" |
        jq -R -s 'split("\n") | map(select(length > 0))')
    skipped_json=$(printf '%s\n' "${skip_groups[@]+"${skip_groups[@]}"}" |
        jq -R -s 'split("\n") | map(select(length > 0))')

    if (( ${#add_groups[@]} == 0 )); then
        log_svc info "No missing required groups for user $user"
        respond true 0 "No missing required groups" \
            "$(fix_data "$user" "$added_json" "$skipped_json")"
        return 0
    fi

    missing_csv=$(IFS=,; printf '%s' "${add_groups[*]}")
    if ! timeout 120 usermod -aG "$missing_csv" "$user" >/dev/null 2>&1; then
        fail_action fix "$user" "" "usermod failed"
        return 0
    fi

    log_svc info "Required groups added for user $user: $missing_csv"
    emit_event "$SL_LVL_INFO" fixed \
        "Required groups added for user $user: $missing_csv" \
        "$(jq -cn --arg user "$user" --argjson added "$added_json" \
            '{user: $user, added: $added}')"
    respond true 0 "Required groups added" \
        "$(fix_data "$user" "$added_json" "$skipped_json")"
}

invalid_request() {  # invalid_request <message>
    log_svc warn "$1"
    respond false 4 "$1" '{}'
    exit 0
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
    list|fix)   need=1 ;;
    add|remove) need=2 ;;
    *)
        invalid_request "Invalid command"
        ;;
esac

parm_len=$(jq -r 'if (.parm | type) == "array" then (.parm | length) else -1 end' \
    <<<"$req" 2>/dev/null)
[ "$parm_len" = "$need" ] || invalid_request "Invalid request parameters"

parm_str() {  # parm_str <index>
    jq -r --argjson i "$1" \
        '.parm[$i] | if type == "string" then . else "" end' \
        <<<"$req" 2>/dev/null
}

user=$(parm_str 0)
if ! target_user_allowed "$user"; then
    log_svc warn "Target user is not allowed: ${user:-<empty>}"
    respond false 5 "Target user is not allowed" '{}'
    exit 0
fi

case "$cmd" in
    list)
        handle_list "$user"
        ;;
    fix)
        handle_fix "$user"
        ;;
    add|remove)
        group=$(parm_str 1)
        if ! valid_group_name "$group"; then
            log_svc warn "Invalid group name: ${group:-<empty>}"
            respond false 4 "Invalid group name" '{}'
            exit 0
        fi
        if [ "$cmd" = "add" ]; then
            handle_add "$user" "$group"
        else
            handle_remove "$user" "$group"
        fi
        ;;
esac

exit 0
