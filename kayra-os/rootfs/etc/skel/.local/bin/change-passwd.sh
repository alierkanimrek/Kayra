#!/usr/bin/env bash
#
# change-passwd.sh - Change the user password via a fuzzel menu.
#
# Design: passwd(1) requires reading the input from a real tty. Instead of
# simulating it with a pty wrapper (expect/python/socat), the script runs
# passwd inside a real terminal (alacritty) and types the passwords with
# "wtype" synthetic keyboard input. This avoids additional languages
# (python/expect), sudo, wheel group or pkexec.
#
# The passwords are collected with fuzzel in password mode. The prompt is
# kept here because the user has to know which password is being asked.
# The "OK" info window has no prompt and therefore uses --hide-prompt.
#
# Dependencies:
#   - fuzzel      (xbps-install -S fuzzel)
#   - alacritty   (xbps-install -S alacritty)
#   - wtype       (xbps-install -S wtype)   -- Wayland synthetic keyboard input
#   - libnotify   (for notify-send, xbps-install -S libnotify)
#
# Used commands: fuzzel, alacritty, wtype, notify-send, pkill, mktemp, id, passwd
#
set -uo pipefail
export LC_ALL=C.UTF-8

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_CHANGE_PASSWD

source "$(dirname "$0")/klog.sh"
source "$(dirname "$0")/notify.sh"

USER_NAME="$(id -un)"
WIN_CLASS="fuzzelpasswd"
RESULT_FILE="$(mktemp /tmp/fuzzelpasswd.XXXXXX)"

# Common fuzzel options for the menus of this script.
FUZZEL_OPTS=(--lines=1 --anchor=top-right --log-no-syslog --minimal-lines)

# Maximum wait time for the passwd process, in tenths of a second.
WAIT_TICKS=50

cleanup() {
    rm -f "$RESULT_FILE"
}
trap cleanup EXIT

# Close any leftover fuzzel windows before each menu
close_fuzzel() {
    pkill -x fuzzel 2>/dev/null || true
    sleep 0.05
}

# Open fuzzel dmenu for hidden (password) input, return typed text
ask_password() {
    local prompt="$1"
    close_fuzzel
    printf '' | fuzzel --dmenu --password --prompt="$prompt" "${FUZZEL_OPTS[@]}" 2>/dev/null
}

# Simple info window (closed with OK). No prompt needed, so the prompt line
# is hidden and the message itself is shown as a menu entry.
info_box() {
    local msg="$1"
    close_fuzzel
    printf '%s\nOK\n' "$msg" | fuzzel --dmenu --hide-prompt "${FUZZEL_OPTS[@]}" >/dev/null 2>&1
}

# Type text via wtype, then press Enter
type_and_enter() {
    local text="$1"
    wtype -- "$text"
    sleep 0.15
    wtype -k Return
}

log INFO "Password change started for user $USER_NAME"

# --- Dependency check -----------------------------------------------
for bin in fuzzel alacritty wtype notify-send; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        log ERROR "Required command $bin is not installed"
        info_box "$(i18n_template "${MSG[MSG_NOT_INSTALLED]}" BIN="$bin")"
        notify_error "${MSG[NOTIFY_TITLE]}" \
            "$(i18n_template "${MSG[MSG_NOT_INSTALLED]}" BIN="$bin")"
        exit 1
    fi
done

# --- 1) Ask for current password -------------------------------------
CURRENT_PASS="$(ask_password "${MSG[PROMPT_CURRENT]}")"
if [[ -z "$CURRENT_PASS" ]]; then
    log INFO "Password change cancelled at the current password prompt"
    notify_info "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_CANCELLED]}"
    exit 1
fi

# --- 2) Ask for new password twice -----------------------------------
NEW_PASS1="$(ask_password "${MSG[PROMPT_NEW]}")"
if [[ -z "$NEW_PASS1" ]]; then
    log INFO "Password change cancelled at the new password prompt"
    notify_info "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_CANCELLED]}"
    unset CURRENT_PASS
    exit 1
fi

NEW_PASS2="$(ask_password "${MSG[PROMPT_NEW_REPEAT]}")"
if [[ -z "$NEW_PASS2" ]]; then
    log INFO "Password change cancelled at the new password repeat prompt"
    notify_info "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_CANCELLED]}"
    unset CURRENT_PASS NEW_PASS1
    exit 1
fi

if [[ "$NEW_PASS1" != "$NEW_PASS2" ]]; then
    log WARN "The new passwords do not match"
    notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_MISMATCH]}"
    unset CURRENT_PASS NEW_PASS1 NEW_PASS2
    exit 1
fi

# --- 3) Clean up stray window, open passwd in real terminal -----------
pkill -f "alacritty --class $WIN_CLASS" 2>/dev/null || true
close_fuzzel

alacritty --class "$WIN_CLASS" -e bash -c \
    "passwd '$USER_NAME'; echo \$? > '$RESULT_FILE'" &

# Wait for window to open and passwd to show first prompt
sleep 0.7

# --- 4) Type passwords in sequence -----------------------------------
type_and_enter "$CURRENT_PASS"
sleep 0.4
type_and_enter "$NEW_PASS1"
sleep 0.4
type_and_enter "$NEW_PASS2"

# --- 5) Wait for result ----------------------------------------------
STATUS=1
ticks=0
while [[ ! -s "$RESULT_FILE" ]] && ((ticks < WAIT_TICKS)); do
    sleep 0.1
    ticks=$((ticks + 1))
done

if [[ -s "$RESULT_FILE" ]]; then
    STATUS="$(cat "$RESULT_FILE")"
else
    log WARN "Timeout while waiting for the passwd result"
fi

pkill -f "alacritty --class $WIN_CLASS" 2>/dev/null || true
unset CURRENT_PASS NEW_PASS1 NEW_PASS2

if [[ "$STATUS" -eq 0 ]]; then
    log INFO "Password changed successfully for user $USER_NAME"
    notify_ok "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_SUCCESS]}"
else
    log ERROR "Password change failed for user $USER_NAME"
    notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_FAILED]}"
fi

exit "$STATUS"
