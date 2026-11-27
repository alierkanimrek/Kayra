#!/usr/bin/env bash
#
# kayra-change-passwd.sh - Change the user password in a real terminal.
#
# Design: passwd(1) reads the current and new passwords directly from a real
# TTY. The script opens alacritty and runs passwd there, so the passwords
# never pass through command line arguments, environment variables or
# synthetic keyboard input. The terminal closes automatically when passwd
# finishes and the script reports the result with a notification.
#
# The exit code of passwd is written to a temporary file by the wrapper that
# runs inside the terminal. Alacritty itself does not expose the child exit
# code, so the temporary file is the only reliable result channel. The file
# contains only the numeric exit code, never a password.
#
# Dependencies:
#   - alacritty   (xbps-install -S alacritty)
#   - libnotify   (for notify-send, xbps-install -S libnotify)
#
# Used commands: alacritty, notify-send, mktemp, id, passwd, head, rm
#
set -uo pipefail
export LC_ALL=C.UTF-8

source /usr/local/lib/kayra/i18n.sh
declare -n MSG=i18n_CHANGE_PASSWD

source /usr/local/lib/kayra/klog.sh
source /usr/local/lib/kayra/notify.sh

USER_NAME="$(id -un)"
RESULT_FILE="$(mktemp /tmp/kayra-change-passwd.XXXXXX)"

cleanup() {
    rm -f "$RESULT_FILE"
}
trap cleanup EXIT

log INFO "Password change started for user $USER_NAME"

# --- Dependency check -----------------------------------------------
for bin in alacritty notify-send passwd; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        log ERROR "Required command $bin is not installed"
        notify_error "${MSG[NOTIFY_TITLE]}" \
            "$(i18n_template "${MSG[MSG_NOT_INSTALLED]}" BIN="$bin")"
        exit 1
    fi
done

# --- Run passwd in a real terminal -----------------------------------
# The wrapper writes only the exit code to RESULT_FILE. The password is read
# by passwd from the terminal and never touches the script.
alacritty --title "${MSG[WINDOW_TITLE]}" -e \
    bash -c 'passwd "$1"; rc=$?; printf "%s\n" "$rc" > "$2"; exit "$rc"' \
    _ "$USER_NAME" "$RESULT_FILE"
ALACRITTY_STATUS=$?

# --- Read the result --------------------------------------------------
STATUS=""
if [[ -s "$RESULT_FILE" ]]; then
    STATUS="$(head -n1 "$RESULT_FILE")"
fi

if [[ ! "$STATUS" =~ ^[0-9]+$ ]]; then
    if [[ "$ALACRITTY_STATUS" -ne 0 ]]; then
        log ERROR "Could not open the terminal for the password change"
        notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_TERMINAL_FAILED]}"
    else
        log INFO "Password change cancelled or terminal closed before passwd finished"
        notify_info "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_CANCELLED]}"
    fi
    exit 1
fi

if [[ "$STATUS" -eq 0 ]]; then
    log INFO "Password changed successfully for user $USER_NAME"
    notify_ok "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_SUCCESS]}"
    exit 0
fi

log ERROR "Password change failed for user $USER_NAME (passwd exit code $STATUS)"
notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_FAILED]}"
exit "$STATUS"
