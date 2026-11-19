#!/usr/bin/env bash
#
# kayra-display-settings.sh - Configure the sway outputs from a fuzzel menu.
#
# Lists the active sway outputs, then offers the available modes
# (resolution@refresh) and scales of the selected output. Changes are applied
# live with swaymsg; they are not written back to the sway configuration.
#
# Usage: kayra-display-settings.sh [fuzzel parameters...]
#
# Used libraries: i18n.sh, klog.sh, notify.sh.
# Used commands: swaymsg, jq, fuzzel, pkill, awk.
#
set -uo pipefail
export LC_ALL=C.UTF-8

source /usr/local/lib/kayra/i18n.sh
declare -n MSG=i18n_DISPLAY_SETTINGS

source /usr/local/lib/kayra/klog.sh
source /usr/local/lib/kayra/notify.sh

# Monitor icon (Material Symbols codepoint).
ICON=$(printf '%b' '\U000E30C')

for cmd in swaymsg jq fuzzel; do
    command -v "$cmd" >/dev/null 2>&1 || {
        log ERROR "Required command not found: $cmd"
        notify_error "${MSG[NOTIFY_TITLE]}" \
            "$(i18n_template "${MSG[MSG_MISSING_CMD]}" CMD="$cmd")"
        exit 1
    }
done

outputs_json=$(swaymsg -t get_outputs -r 2>/dev/null) || {
    log ERROR "swaymsg -t get_outputs failed"
    notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_NO_SWAY]}"
    exit 1
}

# --- Output selection menu ----------------------------------------------
declare -a LINES=()
while IFS=$'\t' read -r name w h r s; do
    [ -n "$name" ] || continue
    info=$(i18n_template "${MSG[MSG_OUTPUT_INFO]}" MODE="${w}x${h}" REFRESH="$r" SCALE="$s")
    LINES+=("$ICON $name  $info")
done < <(jq -r '
    .[] | select(.active and .current_mode != null)
    | [.name, .current_mode.width, .current_mode.height,
       (.current_mode.refresh | round), .scale] | @tsv
' <<<"$outputs_json")

if (( ${#LINES[@]} == 0 )); then
    log WARN "No active display outputs"
    notify_warn "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_NO_OUTPUTS]}"
    exit 0
fi

pkill -x fuzzel 2>/dev/null || true
MAX_WIDTH=$(printf '%s\n' "${LINES[@]}" | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')
SELECTED=$(printf '%s\n' "${LINES[@]}" \
    | fuzzel --dmenu --anchor=top-right --log-no-syslog --minimal-lines \
        --lines="${#LINES[@]}" --width="$MAX_WIDTH" --hide-prompt "$@") || true
[ -z "$SELECTED" ] && exit 0

# The output name is the first field after the icon.
NAME=${SELECTED#* }; NAME=${NAME%% *}
log INFO "Output selected: $NAME"

# --- Mode / scale menu ---------------------------------------------------
declare -a ACTIONS=()
while IFS= read -r mode; do
    [ -n "$mode" ] && ACTIONS+=("${MSG[RESOLUTION]}: $mode")
done < <(jq -r --arg n "$NAME" '
    .[] | select(.name == $n) | .modes[]?
    | "\(.width)x\(.height)@\(.refresh | round)"
' <<<"$outputs_json" | sort -u)

for scale in 1 1.25 1.5 2; do
    ACTIONS+=("${MSG[SCALE]}: $scale")
done
ACTIONS+=("${MSG[DISABLE]}")

pkill -x fuzzel 2>/dev/null || true
MAX_WIDTH=$(printf '%s\n' "${ACTIONS[@]}" | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')
CHOICE=$(printf '%s\n' "${ACTIONS[@]}" \
    | fuzzel --dmenu --anchor=top-right --log-no-syslog --minimal-lines \
        --lines="${#ACTIONS[@]}" --width="$MAX_WIDTH" --hide-prompt "$@") || true
[ -z "$CHOICE" ] && exit 0

# --- Apply ---------------------------------------------------------------
status=0
case "$CHOICE" in
    "${MSG[RESOLUTION]}: "*)
        mode=${CHOICE#*: }
        log INFO "Setting mode $mode on $NAME"
        swaymsg output "$NAME" mode "$mode" >/dev/null 2>&1 || status=1
        ;;
    "${MSG[SCALE]}: "*)
        scale=${CHOICE#*: }
        log INFO "Setting scale $scale on $NAME"
        swaymsg output "$NAME" scale "$scale" >/dev/null 2>&1 || status=1
        ;;
    "${MSG[DISABLE]}")
        log INFO "Disabling output $NAME"
        swaymsg output "$NAME" disable >/dev/null 2>&1 || status=1
        ;;
    *)
        exit 0
        ;;
esac

if (( status == 0 )); then
    notify_ok "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MSG_APPLIED]}" NAME="$NAME")"
else
    log ERROR "Failed to change output $NAME"
    notify_error "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MSG_FAILED]}" NAME="$NAME")"
fi
