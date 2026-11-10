#!/usr/bin/env bash
#
# waybar-app-pins-slot.sh - Manage the fixed slots of the Waybar "group/app-pins".
#
# The slots are the static image#app-pin-N modules listed in
# ~/.config/waybar/app-pins.conf and referenced by "group/app-pins". This script
# edits that file to add or remove a slot, then reloads Waybar so the new module
# list is picked up (a full reload, unlike the lightweight redraw used when a
# pin is added or removed).
#
# Subcommands:
#   add      Append the next free slot.
#   remove   Remove the highest slot, only when it is empty (no pinned app).
#   list     Print the number of used slots and the total slot count.
#
# The include file is plain JSON (no comments) so jq can edit it safely.
#
# Commands used: jq, mktemp, mv, rm, sed, sort, tail, wc, pkill.
#
# Usage: waybar-app-pins-slot.sh {add|remove|list}
#

set -uo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

source "$SCRIPT_DIR/klog.sh"
source "$SCRIPT_DIR/i18n.sh"
declare -n MSG=i18n_APP_PINS
source "$SCRIPT_DIR/notify.sh"

INCLUDE="$HOME/.config/waybar/app-pins.conf"
STATE="$HOME/.config/kayra/app-pins.list"
BIN="$HOME/.local/bin/waybar-app-pins.sh"

# Print the slot indices found in the include file, ascending.
slot_indices() {
    [ -f "$INCLUDE" ] || return 0
    jq -r 'keys[] | select(test("^image#app-pin-[0-9]+$")) | sub("^image#app-pin-"; "")' "$INCLUDE" 2>/dev/null |
        sort -n
}

cmd_list() {
    local total used
    total=$(slot_indices | wc -l)
    used=$(wc -l < "$STATE" 2>/dev/null || echo 0)
    printf '%s\n' "$(i18n_template "${MSG[MSG_SLOT_COUNT]}" COUNT="$used/$total")"
}

cmd_add() {
    local last idx tmp
    if [ ! -f "$INCLUDE" ]; then
        log ERROR "Missing include file: $INCLUDE"
        notify_error "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_FAILED]}" APP="$INCLUDE")"
        exit 1
    fi

    last=$(slot_indices | tail -n1)
    last="${last:--1}"
    idx=$(( last + 1 ))

    tmp=$(mktemp "${TMPDIR:-/tmp}/app-pins.conf.XXXXXX") || exit 1

    if jq --arg i "$idx" --arg bin "$BIN" '
        ("image#app-pin-" + $i) as $name |
        .[$name] = {
            "exec": ($bin + " icon " + $i),
            "size": 20,
            "signal": 5,
            "on-click": ($bin + " launch " + $i),
            "on-click-right": ($bin + " remove " + $i)
        } |
        .["group/app-pins"].modules += [$name]
    ' "$INCLUDE" > "$tmp" && mv "$tmp" "$INCLUDE"; then
        rm -f "$tmp"
        pkill -SIGUSR2 -x waybar 2>/dev/null || true
        log INFO "Slot added: $idx"
        notify_ok "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_SLOT_ADDED]}" INDEX="$idx")"
    else
        rm -f "$tmp"
        log ERROR "Failed to add slot"
        notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_FAILED]}"
        exit 1
    fi
}

cmd_remove() {
    local last n tmp occupied
    if [ ! -f "$INCLUDE" ]; then
        log ERROR "Missing include file: $INCLUDE"
        exit 1
    fi

    last=$(slot_indices | tail -n1)
    if [ -z "$last" ]; then
        notify_warn "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_NO_SLOTS]}"
        exit 0
    fi
    if [ "$last" -le 0 ]; then
        notify_warn "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_SLOT_LAST_FULL]}" INDEX="$last")"
        exit 0
    fi

    # The slot may only be removed when no application is pinned in it.
    n=$(( last + 1 ))
    occupied=$(sed -n "${n}p" "$STATE" 2>/dev/null)
    if [ -n "$occupied" ]; then
        notify_warn "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_SLOT_LAST_FULL]}" INDEX="$last")"
        exit 0
    fi

    tmp=$(mktemp "${TMPDIR:-/tmp}/app-pins.conf.XXXXXX") || exit 1

    if jq --arg name "image#app-pin-$last" '
        del(.[$name]) | .["group/app-pins"].modules -= [$name]
    ' "$INCLUDE" > "$tmp" && mv "$tmp" "$INCLUDE"; then
        rm -f "$tmp"
        pkill -SIGUSR2 -x waybar 2>/dev/null || true
        log INFO "Slot removed: $last"
        notify_ok "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_SLOT_REMOVED]}" INDEX="$last")"
    else
        rm -f "$tmp"
        log ERROR "Failed to remove slot"
        notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_FAILED]}"
        exit 1
    fi
}

case "${1:-}" in
    add)    cmd_add ;;
    remove) cmd_remove ;;
    list)   cmd_list ;;
    *)
        printf 'Usage: %s {add|remove|list}\n' "$(basename "$0")" >&2
        exit 2
        ;;
esac

exit 0
