#!/usr/bin/env bash
#
# kayra-datetime-settings.sh - Date, time zone and NTP settings menu.
#
# Shows the current system time zone and the chrony/NTP state in a fuzzel
# menu. Members of kayra-admin can change the time zone and enable or disable
# the chronyd service. Other users get the same read-only status and the NTP
# details.
#
# Time zone:
#   The current zone is read from /etc/localtime. The list is built from
#   /usr/share/zoneinfo/zone.tab and always contains UTC. The selected zone is
#   sent to kayra-time-services, which validates it and updates /etc/localtime
#   atomically. An active TIMEZONE= line in /etc/rc.conf would override the
#   link at boot, so the service comments it out.
#
# NTP:
#   The state is read without root from /var/service/chronyd, the runit down
#   file and chronyc. Enabling or disabling uses the existing
#   kayra-system-services manager (enable/disable chronyd), so no service
#   control is duplicated here.
#
# Usage: kayra-datetime-settings.sh [fuzzel parameters...]
#
# Dependencies:
#   - fuzzel, jq, chrony (chronyc), tzdata
#   - libnotify (for notify-send, xbps-install -S libnotify)
#
# Used commands: fuzzel, pkill, awk, grep, readlink, date, timeout, head, tr,
#                jq (via time-client.sh and services-client.sh),
#                socat, flock, notify-send (via notify.sh)
#

set -uo pipefail
export LC_ALL=C.UTF-8

source /usr/local/lib/kayra/admin.sh

source /usr/local/lib/kayra/i18n.sh
declare -n MSG=i18n_DATETIME_SETTINGS

source /usr/local/lib/kayra/klog.sh
source /usr/local/lib/kayra/notify.sh
source /usr/local/lib/kayra/time-client.sh
source /usr/local/lib/kayra/services-client.sh

LOCALTIME=/etc/localtime
ZONEINFO=/usr/share/zoneinfo
ZONE_TAB="$ZONEINFO/zone.tab"
RC_CONF=/etc/rc.conf
CHRONY_SERVICE=chronyd
SERVICE_DIR=/var/service
SV_DIR=/etc/sv
SERVICE_RUNSVDIR=/etc/runit/runsvdir/current

# Material Symbols codepoints.
ICON_TIMEZONE=$(printf '%b' '\U0000E8B5')   # schedule
ICON_NTP=$(printf '%b' '\U0000E429')        # tune
ICON_DETAILS=$(printf '%b' '\U0000E88E')    # info
ICON_CHECK=$(printf '%b' '\U0000E5CA')      # check
NOTIFY_ICON="$ICON_TIMEZONE"

# Returns the message of a key, the fallback is used when the key is missing.
msg_text() {
    local value="${MSG[$1]-}"
    [ -n "$value" ] || value="$2"
    printf '%s' "$value"
}

# Returns the message of a key with placeholder replacements.
msg_format() {
    local key=$1 fallback=$2
    shift 2
    i18n_template "$(msg_text "$key" "$fallback")" "$@"
}

# ------------------------------------------------------------------
# Required commands
# ------------------------------------------------------------------
if ! command -v fuzzel >/dev/null 2>&1; then
    log ERROR "fuzzel is not installed"
    notify_error "$(msg_text NOTIFY_TITLE 'Date & Time')" \
        "$(msg_text MSG_NO_FUZZEL 'fuzzel is not installed')"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    log ERROR "jq is not installed"
    notify_error "$(msg_text NOTIFY_TITLE 'Date & Time')" \
        "$(msg_text MSG_NO_JQ 'jq is not installed')"
    exit 1
fi

# ------------------------------------------------------------------
# Current time zone
# ------------------------------------------------------------------
CURRENT_ZONE=""
CURRENT_ZONE_VALID=false
local_target=$(readlink -f -- "$LOCALTIME" 2>/dev/null || true)

case "$local_target" in
    "$ZONEINFO"/*)
        CURRENT_ZONE=${local_target#"$ZONEINFO/"}
        CURRENT_ZONE_VALID=true
        ;;
esac

if [ -z "$CURRENT_ZONE" ] && [ -r /etc/timezone ]; then
    CURRENT_ZONE=$(head -n1 /etc/timezone 2>/dev/null | tr -d '[:space:]')
fi

if [ -z "$CURRENT_ZONE" ]; then
    CURRENT_ZONE=$(date +%Z 2>/dev/null || true)
fi

[ -n "$CURRENT_ZONE" ] || CURRENT_ZONE=$(msg_text ZONE_UNKNOWN 'unknown')

# An active TIMEZONE in /etc/rc.conf overrides /etc/localtime at boot.
RC_CONF_OVERRIDE=false
if [ -f "$RC_CONF" ] &&
    grep -qE '^[[:space:]]*(export[[:space:]]+)?TIMEZONE=' "$RC_CONF" 2>/dev/null; then
    RC_CONF_OVERRIDE=true
fi

# ------------------------------------------------------------------
# NTP / chrony state
# ------------------------------------------------------------------
NTP_ENABLED=false
if [ -e "$SERVICE_DIR/$CHRONY_SERVICE" ] ||
    [ -L "$SERVICE_DIR/$CHRONY_SERVICE" ] ||
    [ -e "$SERVICE_RUNSVDIR/$CHRONY_SERVICE" ] ||
    [ -L "$SERVICE_RUNSVDIR/$CHRONY_SERVICE" ]; then
    NTP_ENABLED=true
fi

NTP_INSTALLED=false
command -v chronyc >/dev/null 2>&1 && NTP_INSTALLED=true

NTP_QUERY_OK=false
NTP_SYNCED=false
NTP_REFERENCE=""
NTP_STRATUM=""
NTP_OFFSET=""
NTP_LEAP=""
NTP_SOURCES=""

if $NTP_INSTALLED; then
    tracking=$(timeout 5 chronyc -c tracking 2>/dev/null || true)
    if [ -n "$tracking" ]; then
        NTP_QUERY_OK=true
        IFS=, read -r refid refip stratum reftime systime lastoff rmsoff \
            freq residual skew rootdelay rootdisp update leap <<<"$tracking"
        NTP_REFERENCE=${refip:-$refid}
        NTP_STRATUM=$stratum
        NTP_OFFSET=$systime
        NTP_LEAP=$leap
        if [ "$leap" = "Normal" ] &&
            [[ $stratum =~ ^[0-9]+$ ]] && (( stratum > 0 )); then
            NTP_SYNCED=true
        fi
    fi

    activity=$(timeout 5 chronyc -c activity 2>/dev/null || true)
    [ -n "$activity" ] && NTP_SOURCES=${activity%%,*}
fi

ntp_state_label() {
    if ! $NTP_ENABLED; then
        msg_text STATE_OFF 'off'
    elif ! $NTP_QUERY_OK; then
        msg_text STATE_ON_UNAVAILABLE 'on, status unavailable'
    elif $NTP_SYNCED; then
        msg_text STATE_ON_SYNCED 'on, synchronized'
    else
        msg_text STATE_ON_NOT_SYNCED 'on, not synchronized'
    fi
}

# ------------------------------------------------------------------
# Time zone list
# ------------------------------------------------------------------
TZ_LINES=()
TZ_ZONES=()
declare -A TZ_SEEN=()

add_zone_line() {  # add_zone_line <zone> [comment]
    local zone=$1 comment=${2:-} label

    [ -n "$zone" ] || return 0
    [ -z "${TZ_SEEN[$zone]:-}" ] || return 0
    TZ_SEEN[$zone]=1

    label=$zone
    [ -n "$comment" ] && label="$zone  ($comment)"
    if [ "$zone" = "$CURRENT_ZONE" ]; then
        label="$ICON_CHECK $label"
    fi

    TZ_LINES+=("$label")
    TZ_ZONES+=("$zone")
}

build_timezone_list() {
    TZ_LINES=()
    TZ_ZONES=()
    TZ_SEEN=()

    add_zone_line UTC

    if [ -r "$ZONE_TAB" ]; then
        while IFS=$'\t' read -r zone comment; do
            add_zone_line "$zone" "$comment"
        done < <(awk -F'\t' 'BEGIN { OFS = "\t" }
            !/^#/ && NF >= 3 { print $3, $4 }' "$ZONE_TAB")
    fi

    # Keep aliases or a time zone that is not in zone.tab selectable.
    if $CURRENT_ZONE_VALID; then
        add_zone_line "$CURRENT_ZONE"
    fi
}

choose_timezone() {
    local max_width selected index=-1 zone

    build_timezone_list

    if (( ${#TZ_LINES[@]} == 0 )); then
        log ERROR "No time zones found"
        notify_error "$(msg_text NOTIFY_TITLE 'Date & Time')" \
            "$(msg_text MSG_NO_ZONES 'No time zones found')"
        return 1
    fi

    pkill -x fuzzel 2>/dev/null || true

    max_width=$(printf '%s\n' "${TZ_LINES[@]}" \
        | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')

    # Long, searchable list: a translated prompt and fuzzel's own height.
    selected=$(printf '%s\n' "${TZ_LINES[@]}" \
        | fuzzel --dmenu --anchor=top-right --log-no-syslog \
            --prompt="$(msg_text PROMPT_TIMEZONE 'Time zone: ')" \
            --width="$max_width" "$@") || true

    [ -n "$selected" ] || return 0

    for i in "${!TZ_LINES[@]}"; do
        if [ "${TZ_LINES[$i]}" = "$selected" ]; then
            index=$i
            break
        fi
    done

    (( index >= 0 )) || return 0
    zone="${TZ_ZONES[$index]}"

    log INFO "Changing the time zone to $zone"

    if ! time_set_timezone "$zone"; then
        log ERROR "kayra-time-services is not reachable"
        notify_error "$(msg_text NOTIFY_TITLE 'Date & Time')" \
            "$(msg_text MSG_SERVICE_UNAVAILABLE 'Time service is not running')"
        return 1
    fi

    if ! time_result_ok; then
        log ERROR "Failed to change the time zone to $zone"
        notify_error "$(msg_text NOTIFY_TITLE 'Date & Time')" \
            "$(msg_format MSG_TIMEZONE_FAILED \
                'Could not set the time zone to {ZONE}' "ZONE=$zone")"
        return 1
    fi

    rc_updated=$("$TIME_JQ" -r '.data.rc_conf_updated // false' \
        <<<"$TIME_RES" 2>/dev/null)

    if $RC_CONF_OVERRIDE && [ "$rc_updated" != "true" ]; then
        log WARN "Time zone changed but the TIMEZONE override remains in $RC_CONF"
        notify_warn "$(msg_text NOTIFY_TITLE 'Date & Time')" \
            "$(msg_format MSG_TIMEZONE_PARTIAL \
                'Time zone set to {ZONE}, but the TIMEZONE override in /etc/rc.conf could not be removed.' \
                "ZONE=$zone")"
    else
        log INFO "Time zone changed to $zone"
        notify_ok "$(msg_text NOTIFY_TITLE 'Date & Time')" \
            "$(msg_format MSG_TIMEZONE_CHANGED 'Time zone set to {ZONE}' \
                "ZONE=$zone")"
    fi

    return 0
}

# ------------------------------------------------------------------
# NTP actions and details
# ------------------------------------------------------------------
ntp_action() {
    local action

    if $NTP_ENABLED; then
        action=disable
    else
        action=enable
    fi

    log INFO "NTP action: $action $CHRONY_SERVICE"

    if ! services_action "$action" "$CHRONY_SERVICE"; then
        log ERROR "kayra-system-services is not reachable"
        notify_error "$(msg_text NOTIFY_TITLE 'Date & Time')" \
            "$(msg_text MSG_NTP_FAILED 'Could not change the NTP setting')"
        return 1
    fi

    if services_result_ok; then
        if [ "$action" = "disable" ]; then
            log INFO "NTP disabled"
            notify_ok "$(msg_text NOTIFY_TITLE 'Date & Time')" \
                "$(msg_text MSG_NTP_DISABLED 'Automatic time (NTP) disabled')"
        else
            log INFO "NTP enabled"
            notify_ok "$(msg_text NOTIFY_TITLE 'Date & Time')" \
                "$(msg_text MSG_NTP_ENABLED 'Automatic time (NTP) enabled')"
        fi
    else
        log ERROR "Failed to change the NTP setting"
        notify_error "$(msg_text NOTIFY_TITLE 'Date & Time')" \
            "$(msg_text MSG_NTP_FAILED 'Could not change the NTP setting')"
    fi

    return 0
}

show_ntp_details() {
    local body

    if ! $NTP_INSTALLED; then
        log WARN "chronyc is not installed"
        notify_warn "$(msg_text NOTIFY_TITLE 'Date & Time')" \
            "$(msg_text MSG_CHRONY_MISSING 'chronyc is not installed; NTP status is unavailable')"
        return 0
    fi

    if ! $NTP_QUERY_OK; then
        log WARN "NTP status is not available"
        notify_warn "$(msg_text NOTIFY_TITLE 'Date & Time')" \
            "$(msg_text MSG_NTP_UNAVAILABLE 'NTP status is not available')"
        return 0
    fi

    body=$(msg_format MSG_NTP_DETAILS \
        $'Reference: {REFERENCE}\nStratum: {STRATUM}\nSystem offset: {OFFSET} s\nSources online: {SOURCES}\nLeap status: {LEAP}' \
        "REFERENCE=${NTP_REFERENCE:--}" \
        "STRATUM=${NTP_STRATUM:--}" \
        "OFFSET=${NTP_OFFSET:--}" \
        "SOURCES=${NTP_SOURCES:--}" \
        "LEAP=${NTP_LEAP:--}")

    notify_info "$(msg_text NOTIFY_TITLE 'Date & Time')" "$body"
}

# ------------------------------------------------------------------
# Main menu
# ------------------------------------------------------------------
MAIN_LINES=()
MAIN_ACTIONS=()

build_main_menu() {
    local timezone_label ntp_label

    MAIN_LINES=()
    MAIN_ACTIONS=()

    timezone_label=$(msg_format LABEL_TIMEZONE 'Time zone: {ZONE}' \
        "ZONE=$CURRENT_ZONE")
    ntp_label=$(msg_format LABEL_NTP 'Automatic time (NTP): {STATE}' \
        "STATE=$(ntp_state_label)")

    if is_kayra_admin; then
        MAIN_LINES+=("$ICON_TIMEZONE  $timezone_label")
        MAIN_ACTIONS+=("timezone")
        MAIN_LINES+=("$ICON_NTP  $ntp_label")
        MAIN_ACTIONS+=("ntp")
    fi

    MAIN_LINES+=("$ICON_DETAILS  $(msg_text LABEL_NTP_DETAILS 'NTP details')")
    MAIN_ACTIONS+=("details")
}

build_status_line() {
    local line

    line=$(msg_format MSG_STATUS \
        'Current time: {TIME}  |  {ZONE}  |  NTP: {NTP}' \
        "TIME=$(date '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null)" \
        "ZONE=$CURRENT_ZONE" \
        "NTP=$(ntp_state_label)")

    if $RC_CONF_OVERRIDE; then
        line="$line  |  $(msg_text MSG_RC_CONF_OVERRIDE \
            '/etc/rc.conf still sets TIMEZONE; it will override the selection at boot.')"
    fi

    printf '%s' "$line"
}

build_main_menu

if (( ${#MAIN_LINES[@]} == 0 )); then
    log ERROR "No date/time menu entries"
    notify_error "$(msg_text NOTIFY_TITLE 'Date & Time')" \
        "$(msg_text MSG_NO_ITEMS 'No items found')"
    exit 1
fi

pkill -x fuzzel 2>/dev/null || true

MAX_WIDTH=$(printf '%s\n' "${MAIN_LINES[@]}" \
    | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')

SELECTED=$(printf '%s\n' "${MAIN_LINES[@]}" \
    | fuzzel --dmenu --anchor=top-right --log-no-syslog \
        --minimal-lines --lines="${#MAIN_LINES[@]}" \
        --width="$MAX_WIDTH" --hide-prompt \
        --mesg="$(build_status_line)" "$@") || true

[ -n "$SELECTED" ] || exit 0

SELECTED_INDEX=-1
for i in "${!MAIN_LINES[@]}"; do
    if [ "${MAIN_LINES[$i]}" = "$SELECTED" ]; then
        SELECTED_INDEX=$i
        break
    fi
done

(( SELECTED_INDEX >= 0 )) || exit 0

case "${MAIN_ACTIONS[$SELECTED_INDEX]}" in
    timezone)
        choose_timezone
        ;;
    ntp)
        ntp_action
        ;;
    details)
        show_ntp_details
        ;;
esac

exit 0
