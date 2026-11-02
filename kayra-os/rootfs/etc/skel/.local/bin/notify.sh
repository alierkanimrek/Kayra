#!/usr/bin/env bash
#
# notify.sh - Notify-send wrapper for Kayra OS scripts (source it; do not execute it).
#
# The library only wraps notify-send. The i18n strings and the log messages
# belong to the calling script, they are not handled here.
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
#
# Used commands: notify-send, command
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

# notify <title> [body] [urgency]
notify() {
    local title="${1:-}" body="${2:-}" urgency="${3:-$NOTIFY_URGENCY}"

    [[ -n "$title" ]] || return 1

    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -a "$NOTIFY_APP" -u "$urgency" "$title" "$body" >/dev/null 2>&1
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

    notify-send -a "$NOTIFY_APP" -u "$NOTIFY_URGENCY" -w "${args[@]}" "$title" "$body" 2>/dev/null
}
