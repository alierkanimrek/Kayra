#!/usr/bin/env bash
#
# notify.sh - Notify-send wrapper for Kayra OS scripts (source it; do not execute it).
#
# The library only wraps notify-send. The i18n strings and the log messages
# belong to the calling script, they are not handled here.
#
# The icon of the notification is a Material Symbols codepoint, the same
# notation that the other Kayra scripts use. The glyph is rendered into an
# SVG file, because the notification daemon shows icon files and icon names
# of the icon theme, but not font glyphs.
#
# Usage:
#   source "$(dirname "$0")/notify.sh"
#
#   notify "Title" "Body"                 # normal urgency
#   notify "Title" "Body" critical        # urgency: low, normal, critical
#
#   notify_info  "Title" "Body"
#   notify_ok    "Title" "Body"
#   notify_warn  "Title" "Body"
#   notify_error "Title" "Body"
#
#   notify_action "Title" "Body" "id=Label" "id2=Label2"
#       Shows buttons and prints the selected action id (nothing when closed).
#
# Config:
#   NOTIFY_APP      Application name shown on the notification. Default: "Kayra"
#   NOTIFY_URGENCY  Default urgency of the notifications. Default: "normal"
#   NOTIFY_TIMEOUT  Optional timeout of the notifications, in milliseconds.
#                   Empty (the default) lets the notification daemon decide
#                   how long the notification stays on screen.
#   NOTIFY_ICON     Optional icon of the notification. It is a Material
#                   Symbols codepoint, either in the "\U000F799" or in the
#                   "0xF799" notation. Default: none
#   NOTIFY_ICON_FONT  Font of the icon. Default: "Material Symbols Outlined"
#   NOTIFY_ICON_COLOR  Color of the icon. Default: "#2e3436"
#   NOTIFY_ICON_DIR    Directory of the generated icon files.
#                      Default: "${XDG_CACHE_HOME:-$HOME/.cache}/kayra/notify-icons"
#
# Used commands: notify-send, command, printf, mkdir
#
# ---------------------------------------------------------------------------
# Example 1: simple messages
# ---------------------------------------------------------------------------
#
#   #!/usr/bin/env bash
#   export LC_ALL=C.UTF-8
#   set -uo pipefail
#
#   source "$(dirname "$0")/notify.sh"
#
#   notify_info "Backup" "The backup has started."
#   notify_ok   "Backup" "142 files copied."
#   notify_warn "Backup" "The disk is almost full."
#   notify_error "Backup" "rsync exited with code 23."
#
# ---------------------------------------------------------------------------
# Example 2: localized messages and log entries in the calling script
# ---------------------------------------------------------------------------
#
#   #!/usr/bin/env bash
#   export LC_ALL=C.UTF-8
#   set -uo pipefail
#
#   source "$(dirname "$0")/i18n.sh"
#   source "$(dirname "$0")/klog.sh"
#   source "$(dirname "$0")/notify.sh"
#
#   declare -n MSG=i18n_BACKUP
#
#   if rsync -a "$SOURCE" "$TARGET"; then
#       log INFO "Backup finished"
#       notify_ok "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_DONE]}"
#   else
#       log ERROR "Backup failed"
#       notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_FAILED]}"
#   fi
#
# ---------------------------------------------------------------------------
# Example 3: a notification with buttons
# ---------------------------------------------------------------------------
#
#   #!/usr/bin/env bash
#   export LC_ALL=C.UTF-8
#   set -uo pipefail
#
#   source "$(dirname "$0")/i18n.sh"
#   source "$(dirname "$0")/klog.sh"
#   source "$(dirname "$0")/notify.sh"
#
#   declare -n MSG=i18n_BACKUP
#
#   ACTION=$(notify_action "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_CONFIRM]}" \
#       "open=${MSG[BUTTON_OPEN]}" "later=${MSG[BUTTON_LATER]}")
#
#   case "$ACTION" in
#       open)
#           log INFO "The user opened the backup folder"
#           xdg-open "$TARGET"
#           ;;
#       *)
#           log INFO "The user did not open the backup folder"
#           ;;
#   esac
#
# ---------------------------------------------------------------------------
# Example 4: a notification that does not block the script
# ---------------------------------------------------------------------------
#
#   # The action is handled in the background, the script continues at once.
#   # The selected action id is written to the log file.
#   (
#       ACTION=$(notify_action "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_INFO]}" \
#           "open=${MSG[BUTTON_OPEN]}")
#       log INFO "Notification action: $ACTION"
#   ) &
#
# ---------------------------------------------------------------------------
# Example 5: a critical message that stays on the screen
# ---------------------------------------------------------------------------
#
#   # notify-send keeps the critical notifications longer, the daemon
#   # decides how long they are shown.
#   notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_CRITICAL]}"
#

export LC_ALL=C.UTF-8

: "${NOTIFY_APP:=Kayra}"
: "${NOTIFY_URGENCY:=normal}"
: "${NOTIFY_TIMEOUT:=}"
: "${NOTIFY_ICON:=}"

# Font that is used for the Material Symbols icon.
: "${NOTIFY_ICON_FONT:=Material Symbols Outlined}"

# Color of the Material Symbols icon.
: "${NOTIFY_ICON_COLOR:=#2e3436}"

# Directory for the generated icon files.
: "${NOTIFY_ICON_DIR:=${XDG_CACHE_HOME:-$HOME/.cache}/kayra/notify-icons}"

# notify_icon_codepoint <value>
# Prints the Unicode codepoint of the given icon value. The value is either
# a codepoint in the "\U000F799" or in the "0xF799" notation, or the symbol
# itself. A value that is none of these is an icon name and has no
# codepoint.
notify_icon_codepoint() {
    local value="${1:-}"
    local hex=""

    [[ -n "$value" ]] || return 1

    # The "\U000F799" notation.
    if [[ "$value" =~ ^\\U([0-9A-Fa-f]{4,8})$ ]]; then
        hex="${BASH_REMATCH[1]}"
    # The "0xF799" notation.
    elif [[ "$value" =~ ^0[xX]([0-9A-Fa-f]{4,8})$ ]]; then
        hex="${BASH_REMATCH[1]}"
    # The symbol itself. The Material Symbols are in the private use area,
    # so a single character above U+2000 is a symbol and not a text.
    elif [[ "${#value}" -eq 1 ]]; then
        local codepoint
        codepoint="$(printf '%d' "'$value")"
        [[ "$codepoint" -gt 8192 ]] || return 1
        printf '%X\n' "$codepoint"
        return 0
    else
        return 1
    fi

    # The leading zeros of the codepoint are removed, so "\U000F799" and
    # "\UF799" give the same result.
    printf '%X\n' "$((16#$hex))"
}

# notify_icon_svg <codepoint>
# Prints the path of the icon file for the given codepoint. The file is an
# SVG with the Material Symbols glyph as text. It is created once and then
# reused.
notify_icon_svg() {
    local codepoint="${1:-}"

    [[ -n "$codepoint" ]] || return 1

    local dir="${NOTIFY_ICON_DIR}"
    mkdir -p "$dir" 2>/dev/null || return 1

    local file="$dir/$codepoint.svg"

    if [[ ! -f "$file" ]]; then
        local glyph
        glyph="$(printf '%b' "\\U$codepoint")"

        printf '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><text x="24" y="34" font-family="%s" font-size="32" text-anchor="middle" fill="%s">%s</text></svg>\n' \
            "$NOTIFY_ICON_FONT" "$NOTIFY_ICON_COLOR" "$glyph" > "$file" 2>/dev/null || return 1
    fi

    [[ -f "$file" ]] && printf '%s\n' "$file"
}

# notify_icon_resolve <icon-value>
# Prints the icon that is given to notify-send. The value is a Material
# Symbols codepoint, for example "\U000F799". The glyph is rendered into an
# SVG file, because the notification daemon only shows icon files and icon
# names of the icon theme, but not font glyphs.
# A value that is no codepoint is an icon name and is passed through, so the
# daemon looks it up in the icon theme.
notify_icon_resolve() {
    local value="${1:-}"

    [[ -n "$value" ]] || return 0

    # An absolute path is used as it is.
    if [[ "$value" == /* ]]; then
        [[ -f "$value" ]] && printf '%s\n' "$value"
        return 0
    fi

    local codepoint
    codepoint="$(notify_icon_codepoint "$value")"

    if [[ -n "$codepoint" ]]; then
        notify_icon_svg "$codepoint"
        return 0
    fi

    printf '%s\n' "$value"
}

# notify <title> [body] [urgency]
notify() {
    local title="${1:-}" body="${2:-}" urgency="${3:-$NOTIFY_URGENCY}"

    [[ -n "$title" ]] || return 1

    command -v notify-send >/dev/null 2>&1 || return 0

    local args=() icon
    icon="$(notify_icon_resolve "${NOTIFY_ICON:-}")"
    [[ -n "$icon" ]] && args+=(-i "$icon")
    [[ "$NOTIFY_TIMEOUT" =~ ^[0-9]+$ ]] && args+=(-t "$NOTIFY_TIMEOUT")

    notify-send -a "$NOTIFY_APP" -u "$urgency" "${args[@]}" "$title" "$body" >/dev/null 2>&1
}

notify_info()  { notify "$1" "${2:-}" normal; }
notify_ok()    { notify "$1" "${2:-}" normal; }
notify_warn()  { notify "$1" "${2:-}" normal; }
notify_error() { notify "$1" "${2:-}" critical; }

# notify_action <title> [body] <id=Label> [<id=Label> ...]
# Prints the id of the selected button.
notify_action() {
    local title="${1:-}" body=""
    shift

    # The body is optional, the action descriptions contain a "=" character.
    if (($#)) && [[ "$1" != *=* ]]; then
        body="$1"
        shift
    fi

    [[ -n "$title" ]] || return 1

    command -v notify-send >/dev/null 2>&1 || return 0

    local args=() action
    for action in "$@"; do
        args+=(-A "$action")
    done

    local icon
    icon="$(notify_icon_resolve "${NOTIFY_ICON:-}")"
    [[ -n "$icon" ]] && args=(-i "$icon" "${args[@]}")
    [[ "$NOTIFY_TIMEOUT" =~ ^[0-9]+$ ]] && args+=(-t "$NOTIFY_TIMEOUT")

    notify-send -a "$NOTIFY_APP" -u "$NOTIFY_URGENCY" -w "${args[@]}" "$title" "$body" 2>/dev/null
}
