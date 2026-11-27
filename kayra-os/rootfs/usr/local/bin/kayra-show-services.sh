#!/usr/bin/env bash
#
# kayra-show-services.sh - Lists the system services in a fuzzel menu.
#
# The list and the service states come from the kayra-system-services job
# socket. The service runs as root and reads the runit control files, so this
# script needs neither pkexec nor a root helper.
#
# The services are read from the runit service directories by the service:
#   /etc/sv/<name>       installed service definitions
#   /var/service/<name>  enabled (supervised) service
#
# Every service is marked with a Material Symbols icon:
#   ▶  running   (the service is up)
#   ■  down      (the service is stopped now, starts at boot)
#   ⛔  disabled  (there is no /var/service link)
#   ⚠  failed    (the service could not be started)
#
# The suffix describes the state and the boot policy:
#   "(disabled)"           no /var/service link
#   "(failed)"             link exists, but "sv status" reports fail:
#   "(does not start at boot)"  the /etc/sv/<name>/down file exists
#
# Selecting a service runs
#   kayra-toggle-service.sh <service> <state> <protected> <boot>
# and the toggle script opens the action menu for that state.
#
# The service manager is only reachable for members of the fixed "kayra-admin"
# group (socket 0660 root:kayra-admin). A regular user exits silently.
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
# Usage: kayra-show-services.sh
#
# Used commands: awk, fuzzel, pkill (via services-client.sh: socat, flock, jq)
#

set -uo pipefail

export LC_ALL=C.UTF-8

source /usr/local/lib/kayra/admin.sh
require_kayra_admin

source /usr/local/lib/kayra/i18n.sh
declare -n MSG=i18n_SHOW_SERVICES

source /usr/local/lib/kayra/klog.sh
source /usr/local/lib/kayra/notify.sh
source /usr/local/lib/kayra/services-client.sh

# Returns the message of a key, the fallback is used when the key is
# missing. The fallback is passed as a separate argument, a placeholder
# inside a ${...:-default} expression would break the expansion.
msg_text() {
    local value="${MSG[$1]-}"
    [ -n "$value" ] || value="$2"
    printf '%s' "$value"
}

# Material Symbols icons of the service states.
declare -A ICONS=(
    [running]="E037"   # play_arrow
    [down]="E047"      # stop
    [disabled]="E14B"  # block
    [failed]="E000"    # error
)

ICON_RUNNING=$(printf '%b' "\U000${ICONS[running]}")
ICON_DOWN=$(printf '%b' "\U000${ICONS[down]}")
ICON_DISABLED=$(printf '%b' "\U000${ICONS[disabled]}")
ICON_FAILED=$(printf '%b' "\U000${ICONS[failed]}")
DISABLED_LABEL=$(msg_text LABEL_DISABLED 'disabled')
FAILED_LABEL=$(msg_text LABEL_FAILED 'failed')
BOOT_OFF_LABEL=$(msg_text LABEL_BOOT_OFF 'does not start at boot')

# ------------------------------------------------------------------
# Read the service list from the service manager
# ------------------------------------------------------------------
STATE_DATA=""

if ! STATE_DATA=$(services_list); then
    log ERROR "kayra-system-services is not reachable"
    notify_error "$(msg_text NOTIFY_TITLE 'Services')" \
        "$(msg_text MSG_MANAGER_UNAVAILABLE 'Service manager is not running')"
    exit 1
fi

# ------------------------------------------------------------------
# Build the menu entries
# ------------------------------------------------------------------
declare -a LINES=()
declare -a SERVICES=()
declare -a STATES=()
declare -a PROTECTED=()
declare -a BOOTS=()

mapfile -t LINES < <(awk -F'\t' \
    -v running="$ICON_RUNNING" \
    -v down="$ICON_DOWN" \
    -v disabled_icon="$ICON_DISABLED" \
    -v failed_icon="$ICON_FAILED" \
    -v disabled="$DISABLED_LABEL" \
    -v failed="$FAILED_LABEL" \
    -v boot_off="$BOOT_OFF_LABEL" '
    $1 == "" { next }
    {
        icon = down
        suffix = ""

        if ($2 == "running") {
            icon = running
        } else if ($2 == "disabled") {
            icon = disabled_icon
            suffix = "  (" disabled ")"
        } else if ($2 == "failed") {
            icon = failed_icon
            suffix = "  (" failed ")"
        }

        # The boot policy is shown for supervised services, including a
        # running service that will not come back after a reboot.
        if ($2 != "disabled" && $4 == "manual") {
            suffix = suffix "  (" boot_off ")"
        }

        print icon " " $1 suffix
    }
' <<< "$STATE_DATA")

mapfile -t SERVICES < <(awk -F'\t' '$1 != "" { print $1 }' <<< "$STATE_DATA")
mapfile -t STATES < <(awk -F'\t' '$1 != "" { print $2 }' <<< "$STATE_DATA")
mapfile -t PROTECTED < <(awk -F'\t' '$1 != "" { print ($3 == "true" ? "true" : "false") }' <<< "$STATE_DATA")
mapfile -t BOOTS < <(awk -F'\t' '$1 != "" { print ($4 == "manual" ? "manual" : "auto") }' <<< "$STATE_DATA")

if [ "${#LINES[@]}" -eq 0 ]; then
    log WARN "No services found in /etc/sv"
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
SERVICE_PROTECTED="${PROTECTED[$SELECTED_INDEX]:-false}"
SERVICE_BOOT="${BOOTS[$SELECTED_INDEX]:-auto}"

log INFO "Changing service: $SERVICE (state: ${STATE:-unknown}, boot: $SERVICE_BOOT)"

exec /usr/local/bin/kayra-toggle-service.sh \
    "$SERVICE" "$STATE" "$SERVICE_PROTECTED" "$SERVICE_BOOT"
