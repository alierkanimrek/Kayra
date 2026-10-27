#!/usr/bin/env bash
#
# show-services.sh - Lists the system services in a fuzzel menu.
#
# Services are read from the runit service directories:
#   /etc/sv/<name>       installed service definitions
#   /var/service/<name>  enabled (supervised) service
#
# Every service is marked the same way as show-device-mods.sh does:
#   ●  running   (the service is up)
#   ○  stopped   (the service is not running)
# Services that are not supervised are marked with the "(disabled)" suffix.
#
# Selecting a service runs toggle-service.sh <service>, which stops a
# running service, starts a stopped one or enables + starts a disabled one.
#
# The service states are read through a root helper (pkexec), because the
# runit control files are only readable by root. If the helper cannot be
# used, the states are guessed from the running processes.
#
# Usage: show-services.sh
#
export LC_ALL=C.UTF-8
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "$0")")" && pwd)"
SV_DIR="/etc/sv"
SERVICE_DIR="/var/service"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/i18n.sh"
declare -n MSG=i18n_SHOW_SERVICES

# shellcheck source=/dev/null
[ -f "$SCRIPT_DIR/klog.sh" ] && . "$SCRIPT_DIR/klog.sh"
if ! command -v log >/dev/null 2>&1; then
    log() { printf '%s\n' "$*"; }
fi

command -v fuzzel >/dev/null 2>&1 || { echo "${MSG[MSG_NO_FUZZEL]:-fuzzel is not installed}" >&2; exit 1; }

if [ ! -d "$SV_DIR" ]; then
    log ERROR "Service directory not found: $SV_DIR"
    echo "${MSG[MSG_NO_SERVICES]:-No services found}" >&2
    exit 1
fi

# ------------------------------------------------------------------
# Service states
# ------------------------------------------------------------------
# State file format: "<service-name><TAB><running|stopped|disabled>"

# Reads the states with a root helper: "sv status" needs root access.
collect_states_root() {
    local helper out result
    helper=$(mktemp) || return 1
    out=$(mktemp) || { rm -f "$helper"; return 1; }

    cat >"$helper" <<'ROOT_HELPER'
#!/bin/sh
# Prints "<service-name><TAB><state>" for every runit service.
sv_dir="/etc/sv"
service_dir="/var/service"

for dir in "$sv_dir"/*; do
    [ -d "$dir" ] || continue
    name=${dir##*/}

    if [ -e "$service_dir/$name" ]; then
        state=$(sv status "$service_dir/$name" 2>&1 | head -n 1)
        case "$state" in
            run:*)  state="running" ;;
            *)      state="stopped" ;;
        esac
    else
        state="disabled"
    fi

    printf '%s\t%s\n' "$name" "$state"
done
ROOT_HELPER

    command -v pkexec >/dev/null 2>&1 || { rm -f "$helper" "$out"; return 1; }

    result=$(pkexec /bin/sh "$helper" 2>/dev/null)
    if [ -z "$result" ]; then
        rm -f "$helper" "$out"
        return 1
    fi

    printf '%s\n' "$result" >"$out"
    rm -f "$helper"
    cat "$out"
    rm -f "$out"
    return 0
}

# Fallback: guess the state from the process table (no root needed).
# The program that the run script starts is searched in the process list.
guess_state() {
    local name="$1" dir="$SV_DIR/$1" run_file line token base

    if [ ! -e "$SERVICE_DIR/$name" ]; then
        printf 'disabled\n'
        return 0
    fi

    run_file="$dir/run"
    if [ ! -r "$run_file" ]; then
        printf 'stopped\n'
        return 0
    fi

    # The last exec line of the run script holds the started program.
    line=$(grep -E '^[[:space:]]*exec[[:space:]]+' "$run_file" 2>/dev/null | tail -n 1)
    [ -n "$line" ] || { printf 'stopped\n'; return 0; }
    line="${line#exec }"

    for token in $line; do
        # Skip redirections, options, user:group pairs and wrappers.
        case "$token" in
            *'>'*|'<'*) continue ;;
            -*) continue ;;
            *:*) continue ;;
            /*) base="${token##*/}" ;;
            *) base="$token" ;;
        esac
        case "$base" in
            exec|chpst|env|set|su|sh|bash) continue ;;
        esac

        if pgrep -x "$base" >/dev/null 2>&1; then
            printf 'running\n'
            return 0
        fi
    done

    printf 'stopped\n'
}

STATE_DATA=$(collect_states_root)
if [ -z "$STATE_DATA" ]; then
    log WARN "Could not read service states with root helper, guessing from processes"
    STATE_DATA=""
    for dir in "$SV_DIR"/*; do
        [ -d "$dir" ] || continue
        name="${dir##*/}"
        STATE_DATA+="$name"$'\t'"$(guess_state "$name")"$'\n'
    done
fi

# ------------------------------------------------------------------
# Build the menu entries
# ------------------------------------------------------------------
ICON_RUNNING=$(LC_ALL=C.UTF-8 printf '%b' '\U000025CF')   # ● running
ICON_STOPPED=$(LC_ALL=C.UTF-8 printf '%b' '\U000025CB')   # ○ stopped

declare -a MENU_LINES=()
declare -a MENU_SERVICES=()

while IFS=$'\t' read -r name state; do
    [ -n "$name" ] || continue
    case "$state" in
        running)
            MENU_LINES+=("$ICON_RUNNING $name")
            ;;
        disabled)
            MENU_LINES+=("$ICON_STOPPED $name  (${MSG[LABEL_DISABLED]:-disabled})")
            ;;
        *)
            MENU_LINES+=("$ICON_STOPPED $name")
            ;;
    esac
    MENU_SERVICES+=("$name")
done <<< "$STATE_DATA"

if [ "${#MENU_LINES[@]}" -eq 0 ]; then
    log WARN "No services found in $SV_DIR"
    echo "${MSG[MSG_NO_SERVICES]:-No services found}" >&2
    exit 0
fi

# ------------------------------------------------------------------
# Show the menu
# ------------------------------------------------------------------
pkill -x fuzzel 2>/dev/null || true

SELECTED=$(printf '%s\n' "${MENU_LINES[@]}" | fuzzel --dmenu --log-no-syslog --hide-prompt \
    --width 60 --lines 20 --mesg="${MSG[MSG_MESG]:-Services}" \
    --prompt="${MSG[PROMPT_SERVICE]:-Service: }") || true

[ -z "$SELECTED" ] && exit 0

SELECTED_INDEX=-1
for i in "${!MENU_LINES[@]}"; do
    if [ "${MENU_LINES[$i]}" = "$SELECTED" ]; then
        SELECTED_INDEX=$i
        break
    fi
done

[ "$SELECTED_INDEX" -lt 0 ] && exit 0

SERVICE="${MENU_SERVICES[$SELECTED_INDEX]}"

log INFO "Toggling service: $SERVICE"

exec "$SCRIPT_DIR/toggle-service.sh" "$SERVICE"
