#!/usr/bin/env bash
#
# waybar-app-pins.sh - Pinned application icons for the Waybar "group/app-pins".
#
# The bar exposes a fixed set of slots (image#app-pin-N modules defined in
# ~/.config/waybar/app-pins.conf). Each slot runs this script with its own slot
# index, so this single script serves every slot:
#
#   menu        Fuzzel picker with the installed applications; the chosen
#               application is appended to the state file (adds a pin).
#   command     Fuzzel prompt; the typed shell command is appended to the state
#               file as a "cmd:" pin and shown with a fixed terminal icon.
#               Command pins always run inside a terminal (see TERMINAL) using
#               the user's interactive shell (bash -ic), so PATH and aliases
#               from ~/.bashrc apply; a TUI like "htop" or "opencode" does not
#               need to name a terminal.
#   icon N      Print the icon file path and the tooltip of slot N. The image
#               module shows the icon; for an empty slot a non-existent path is
#               printed so the module hides it.
#   launch N    Launch the application (action pin) stored in slot N, or run
#               the command (cmd: pin) inside a terminal.
#   remove N    Fuzzel menu with a single "Remove" entry that unpins slot N.
#
# Adding or removing a pin only rewrites the state file, then sends
# SIGRTMIN+5 to Waybar so the image slots redraw (no config reload).
#
# State file (one pin per line, line order = slot order):
#   ~/.config/kayra/app-pins.list
#   * An absolute .desktop path is an application pin.
#   * A line beginning with "cmd:" is a shell command pin.
#
# Slot management (adding slot modules) is a different script:
#   waybar-app-pins-slot.sh
#
# Commands used: awk, find, sort, cut, sed, head, grep, printf, mktemp, pkill,
#   setsid, fuzzel, gio, jq.
#
# Usage: waybar-app-pins.sh {menu|command|icon N|launch N|remove N}
#

set -uo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

source "$SCRIPT_DIR/klog.sh"
source "$SCRIPT_DIR/settings-conf.sh"
source "$SCRIPT_DIR/i18n.sh"
declare -n MSG=i18n_APP_PINS
source "$SCRIPT_DIR/notify.sh"

STATE="$HOME/.config/kayra/app-pins.list"
INCLUDE="$HOME/.config/waybar/app-pins.conf"

# Real-time signal number; must match "signal" in app-pins.conf (SIGRTMIN + 5).
SIGNAL=5

# Icon file used for pins whose value is a shell command (state line "cmd:...").
CMD_ICON_NAME="terminal-app"

# Terminal command prefix used to run command pins (they always open in a
# terminal). Read from settings.conf (key "terminal"), e.g. "alacritty -e";
# falls back to "alacritty -e".
TERMINAL="$(conf_get terminal | head -n1)"
[ -n "$TERMINAL" ] || TERMINAL="alacritty -e"

# Temporary file used by the add menu (removed on exit).
TMP_DATA=""
cleanup() { [ -n "$TMP_DATA" ] && rm -f "$TMP_DATA"; }
trap cleanup EXIT

# --- Helpers -------------------------------------------------------------

# desktop_field <file> <key>
# Print the value of <key> inside the [Desktop Entry] group of a .desktop file.
desktop_field() {
    awk -v key="$2" '
        /^\[/ { in_de = ($0 == "[Desktop Entry]"); next }
        in_de && index($0, key "=") == 1 { print substr($0, length(key) + 2); exit }
    ' "$1"
}

# resolve_icon <name-or-path>
# Turn an icon theme name (or an absolute path) into an image file path.
resolve_icon() {
    local name="$1" hit
    [ -n "$name" ] || return 0
    case "$name" in
        /*) [ -f "$name" ] && { printf '%s\n' "$name"; return 0; } ;;
    esac
    # Prefer a large or scalable icon.
    hit=$(find /usr/share/icons /usr/share/pixmaps "$HOME/.local/share/icons" \
              -type f \( -name "$name.png" -o -name "$name.svg" -o -name "$name.xpm" \) \
              2>/dev/null | grep -E '/(scalable|256x256|192x192|128x128|96x96|64x64|48x48)/' | head -n1)
    [ -n "$hit" ] || hit=$(find /usr/share/icons /usr/share/pixmaps "$HOME/.local/share/icons" \
              -type f \( -name "$name.png" -o -name "$name.svg" -o -name "$name.xpm" \) \
              2>/dev/null | head -n1)
    printf '%s\n' "$hit"
}

# list_desktops
# Print every visible application as "name<TAB>icon<TAB>desktop_path".
# Directories are scanned in XDG order; the first entry for an id wins.
list_desktops() {
    local dirs
    local -a files
    mapfile -t dirs < <(printf '%s/applications\n' "$HOME/.local/share" \
        $(printf '%s' "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" | tr ':' '\n'))
    mapfile -t files < <(find "${dirs[@]}" -maxdepth 1 \( -type f -o -type l \) -name '*.desktop' 2>/dev/null)
    [ "${#files[@]}" -gt 0 ] || return 0
    awk '
        function flush() {
            if (have_de && name != "" && exec != "" && type == "Application" &&
                nodisplay != "true" && hidden != "true") {
                base = file; sub(/^.*\//, "", base); sub(/\.desktop$/, "", base)
                if (!(base in seen)) {
                    seen[base] = 1
                    printf "%s\t%s\t%s\n", name, icon, file
                }
            }
        }
        FNR == 1 {
            if (NR > 1) flush()
            file = FILENAME
            in_de = 0; have_de = 0; name = ""; icon = ""; exec = ""; type = ""; nodisplay = ""; hidden = ""
        }
        /^\[/ { in_de = ($0 == "[Desktop Entry]"); if (in_de) have_de = 1; next }
        in_de && /^Name=/      { if (name == "") name = substr($0, 6) }
        in_de && /^Icon=/      { if (icon == "") icon = substr($0, 6) }
        in_de && /^Exec=/      { if (exec == "") exec = substr($0, 6) }
        in_de && /^Type=/      { type = substr($0, 6) }
        in_de && /^NoDisplay=/ { nodisplay = substr($0, 11) }
        in_de && /^Hidden=/    { hidden = substr($0, 8) }
        END { flush() }
    ' "${files[@]}"
}

# Number of slots defined in the include file.
slot_count() {
    [ -f "$INCLUDE" ] || { echo 0; return; }
    jq -r '[keys[] | select(test("^image#app-pin-[0-9]+$"))] | length' "$INCLUDE" 2>/dev/null || echo 0
}

# Redraw the image slots of the bar.
signal_waybar() {
    pkill -SIGRTMIN+"$SIGNAL" -x waybar 2>/dev/null || true
}

# --- Subcommands ---------------------------------------------------------

cmd_menu() {
    local width sel idx path name used total
    TMP_DATA=$(mktemp "${TMPDIR:-/tmp}/app-pins.XXXXXX") || exit 1

    list_desktops | sort -s -t$'\t' -k1,1 > "$TMP_DATA"
    if [ ! -s "$TMP_DATA" ]; then
        notify_warn "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_NO_APPS]}"
        exit 0
    fi

    local -a paths
    mapfile -t paths < <(cut -f3 "$TMP_DATA")

    width=$(cut -f1 "$TMP_DATA" |
        awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')

    pkill -x fuzzel 2>/dev/null || true
    # Name in column 1, the icon is appended with Rofi's dmenu icon protocol.
    sel=$(awk -F'\t' '{ if ($2 == "") print $1; else printf "%s%cicon\x1f%s\n", $1, 0, $2 }' "$TMP_DATA" |
        fuzzel --dmenu --anchor=top-left --log-no-syslog --no-sort --index --only-match \
            --width="$width" \
            --prompt="${MSG[MENU_PROMPT]}: ") || exit 0
    [ -n "$sel" ] || exit 0

    idx="$sel"
    path="${paths[$idx]:-}"
    [ -n "$path" ] || exit 0
    name=$(desktop_field "$path" Name)

    if grep -qxF -- "$path" "$STATE" 2>/dev/null; then
        notify_info "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_ALREADY]}" APP="$name")"
        exit 0
    fi

    used=$(wc -l < "$STATE" 2>/dev/null || echo 0)
    total=$(slot_count)
    if [ "$used" -ge "$total" ]; then
        notify_warn "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_FULL]}"
        exit 0
    fi

    mkdir -p "$(dirname "$STATE")"
    printf '%s\n' "$path" >> "$STATE"
    signal_waybar
    log INFO "Pin added: $path"
    notify_ok "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_ADDED]}" APP="$name")"
}

cmd_command() {
    local cmd used total
    pkill -x fuzzel 2>/dev/null || true
    cmd=$(fuzzel --dmenu --anchor=top-left --prompt-only="${MSG[COMMAND_PROMPT]}: " --log-no-syslog) || exit 0
    [ -n "$cmd" ] || exit 0

    if grep -qxF -- "cmd:$cmd" "$STATE" 2>/dev/null; then
        notify_info "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_ALREADY]}" APP="$cmd")"
        exit 0
    fi

    used=$(wc -l < "$STATE" 2>/dev/null || echo 0)
    total=$(slot_count)
    if [ "$used" -ge "$total" ]; then
        notify_warn "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_FULL]}"
        exit 0
    fi

    mkdir -p "$(dirname "$STATE")"
    printf 'cmd:%s\n' "$cmd" >> "$STATE"
    signal_waybar
    log INFO "Command pin added: $cmd"
    notify_ok "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_CMD_ADDED]}" CMD="$cmd")"
}

cmd_icon() {
    local n="$1" line path icon name resolved
    line=$(sed -n "$(( n + 1 ))p" "$STATE" 2>/dev/null)
    if [ -z "$line" ]; then
        # Waybar strips one trailing newline, so empty output would keep the
        # previous icon. Print a non-existent path instead: loading it fails and
        # the image module hides the slot.
        printf '%s\n' "$HOME/.config/kayra/app-pins.none"
        exit 0
    fi

    # Command pin: fixed terminal icon, the command itself is the tooltip.
    if [ "${line#cmd:}" != "$line" ]; then
        resolved=$(resolve_icon "$CMD_ICON_NAME")
        [ -n "$resolved" ] || resolved=$(resolve_icon application-x-executable)
        [ -n "$resolved" ] || exit 0
        printf '%s\n%s\n' "$resolved" "${line#cmd:}"
        exit 0
    fi

    path="$line"
    if [ ! -f "$path" ]; then
        printf '%s\n' "$HOME/.config/kayra/app-pins.none"
        exit 0
    fi
    icon=$(desktop_field "$path" Icon)
    name=$(desktop_field "$path" Name)
    resolved=$(resolve_icon "$icon")
    [ -n "$resolved" ] || resolved=$(resolve_icon application-x-executable)
    [ -n "$resolved" ] || exit 0
    printf '%s\n%s\n' "$resolved" "$name"
}

cmd_launch() {
    local n="$1" line
    line=$(sed -n "$(( n + 1 ))p" "$STATE" 2>/dev/null)
    [ -n "$line" ] || exit 0

    # Command pin: always open the command in a terminal. An interactive shell
    # is used so the user's PATH and aliases from ~/.bashrc are available
    # (non-interactive shells do not read it).
    if [ "${line#cmd:}" != "$line" ]; then
        # $TERMINAL may carry extra arguments (e.g. "alacritty -e"), so it is
        # intentionally word-split here.
        # shellcheck disable=SC2086
        setsid -f $TERMINAL bash -ic "${line#cmd:}" >/dev/null 2>&1 ||
            log WARN "Failed to run command: ${line#cmd:}"
        exit 0
    fi

    gio launch "$line" >/dev/null 2>&1 || log WARN "Failed to launch: $line"
}

cmd_remove() {
    local n="$1" line label option width sel
    line=$(sed -n "$(( n + 1 ))p" "$STATE" 2>/dev/null)
    [ -n "$line" ] || exit 0

    if [ "${line#cmd:}" != "$line" ]; then
        label="${line#cmd:}"
    else
        label=$(desktop_field "$line" Name)
    fi

    option="${MSG[REMOVE_ACTION]} $label"
    width=$(printf '%s\n' "$option" |
        awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')

    pkill -x fuzzel 2>/dev/null || true
    sel=$(printf '%s\n' "$option" |
        fuzzel --dmenu --anchor=top-left --log-no-syslog --hide-prompt --minimal-lines \
            --lines=1 --width="$width") || exit 0
    [ -n "$sel" ] || exit 0

    sed -i "$(( n + 1 ))d" "$STATE"
    signal_waybar
    log INFO "Pin removed: $line"
    notify_ok "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${MSG[MSG_REMOVED]}" APP="$label")"
}

# --- Entry point ---------------------------------------------------------

case "${1:-}" in
    menu)    cmd_menu ;;
    command) cmd_command ;;
    icon)    cmd_icon "${2:?missing slot index}" ;;
    launch)  cmd_launch "${2:?missing slot index}" ;;
    remove)  cmd_remove "${2:?missing slot index}" ;;
    *)
        printf 'Usage: %s {menu|command|icon N|launch N|remove N}\n' "$(basename "$0")" >&2
        exit 2
        ;;
esac

exit 0
