#!/usr/bin/env bash
#
# show-services.sh - Lists the system services in a fuzzel menu.
#
# The services are read from the runit service directories:
#   /etc/sv/<name>       installed service definitions
#   /var/service/<name>  enabled (supervised) service
#
# Every service is marked with a Material Symbols icon:
#   ▶  running   (the service is up)
#   ■  stopped   (the service is not running)
# Services that are not supervised are marked with the "(disabled)" suffix.
#
# Selecting a service runs toggle-service.sh <service> <state>:
#   * a running service opens an actionable notification with a "Stop" and a
#     "Restart" button,
#   * a stopped service is started,
#   * a disabled service is enabled and started.
#
# The service states are read with the root helper sv-status-helper.sh,
# because the runit control files are only readable by root. If the helper
# cannot be used, the states are guessed from the running processes.
#
# Important instructions:
#   * The prompt line is shown, so the service can be searched by typing a
#     part of its name. The prompt text comes from the language file.
#   * The menu needs a terminal on the standard input. The dmenu protocol
#     reads the menu entries from the standard input, so a closed standard
#     input makes fuzzel select the first entry right away and that service
#     would be toggled. The script is therefore meant to be started from a
#     keybinding or from a terminal.
#   * The icons are Material Symbols codepoints, they need the Material
#     Symbols font. The fontconfig fallback of the menu font renders them.
#
# Usage: show-services.sh
#
# Used commands: awk, grep, pgrep, pkexec, fuzzel, pkill
#                (state helpers in sv-lib.sh)
#

set -uo pipefail

export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "$0")")" && pwd)"

SV_DIR="/etc/sv"
SERVICE_DIR="/var/service"
HELPER="$SCRIPT_DIR/sv-status-helper.sh"

source "$SCRIPT_DIR/i18n.sh"
declare -n MSG=i18n_SHOW_SERVICES

source "$SCRIPT_DIR/klog.sh"
source "$SCRIPT_DIR/sv-lib.sh"

# Returns the message of a key, the fallback is used when the key is
# missing. The fallback is passed as a separate argument, a placeholder
# inside a ${...:-default} expression would break the expansion.
msg_text() {
    local value="${MSG[$1]}"
    [ -n "$value" ] || value="$2"
    printf '%s' "$value"
}

# Material Symbols icons of the service states.
declare -A ICONS=(
    [running]="E037"   # play_arrow
    [stopped]="E047"   # stop
)

ICON_RUNNING=$(printf '%b' "\U000${ICONS[running]}")
ICON_STOPPED=$(printf '%b' "\U000${ICONS[stopped]}")
DISABLED_LABEL=$(msg_text LABEL_DISABLED 'disabled')

if ! command -v fuzzel >/dev/null 2>&1; then
    log ERROR "fuzzel is not installed"
    echo "$(msg_text MSG_NO_FUZZEL 'fuzzel is not installed')" >&2
    exit 1
fi

if [ ! -d "$SV_DIR" ]; then
    log ERROR "Service directory not found: $SV_DIR"
    echo "$(msg_text MSG_NO_SERVICES 'No services found')" >&2
    exit 1
fi

# ------------------------------------------------------------------
# Service states
# ------------------------------------------------------------------
# The state file format is: "<service-name><TAB><running|stopped|disabled>"

# Fallback without root: the state is guessed from the process table, the
# program that the run script starts is searched in the process list.
guess_states() {
    local name dir

    for dir in "$SV_DIR"/*; do
        [ -d "$dir" ] || continue
        name="${dir##*/}"
        printf '%s\t%s\n' "$name" "$(sv_guess_state "$name")"
    done
}

STATE_DATA=""

if [ -r "$HELPER" ] && command -v pkexec >/dev/null 2>&1; then
    STATE_DATA=$(pkexec /bin/sh "$HELPER" 2>/dev/null)
fi

if [ -z "$STATE_DATA" ]; then
    log WARN "Could not read the service states with the root helper, guessing from the processes"
    STATE_DATA=$(guess_states)
fi

# ------------------------------------------------------------------
# Build the menu entries
# ------------------------------------------------------------------
declare -a LINES=()
declare -a SERVICES=()
declare -a STATES=()

mapfile -t LINES < <(awk -F'\t' \
    -v running="$ICON_RUNNING" \
    -v stopped="$ICON_STOPPED" \
    -v disabled="$DISABLED_LABEL" '
    $1 == "" { next }
    $2 == "running"  { print running " " $1; next }
    $2 == "disabled" { print stopped " " $1 "  (" disabled ")"; next }
    { print stopped " " $1 }
' <<< "$STATE_DATA")

mapfile -t SERVICES < <(awk -F'\t' '$1 != "" { print $1 }' <<< "$STATE_DATA")
mapfile -t STATES < <(awk -F'\t' '$1 != "" { print $2 }' <<< "$STATE_DATA")

if [ "${#LINES[@]}" -eq 0 ]; then
    log WARN "No services found in $SV_DIR"
    echo "$(msg_text MSG_NO_SERVICES 'No services found')" >&2
    exit 0
fi

# ------------------------------------------------------------------
# Show the menu
# ------------------------------------------------------------------
# Close any open menus
pkill -x fuzzel 2>/dev/null || true

# Window width of the longest menu entry (icon counted as 3 characters)
MAX_WIDTH=$(printf '%s\n' "${LINES[@]}" | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')

SELECTED=$(printf '%s\n' "${LINES[@]}" | fuzzel --dmenu --anchor=top-right \
    --log-no-syslog --minimal-lines \
    --width="$MAX_WIDTH" --lines 20 \
    --mesg="$(msg_text MSG_MESG 'Services')" \
    --prompt="$(msg_text PROMPT_SERVICE 'Service: ')") || true

[ -z "$SELECTED" ] && exit 0

SELECTED_INDEX=-1
for i in "${!LINES[@]}"; do
    if [ "${LINES[$i]}" = "$SELECTED" ]; then
        SELECTED_INDEX=$i
        break
    fi
done

[ "$SELECTED_INDEX" -lt 0 ] && exit 0

SERVICE="${SERVICES[$SELECTED_INDEX]}"
STATE="${STATES[$SELECTED_INDEX]:-}"

log INFO "Changing service: $SERVICE (state: ${STATE:-unknown})"

exec "$SCRIPT_DIR/toggle-service.sh" "$SERVICE" "$STATE"
