#!/usr/bin/env bash
#
# change-passwd.sh
# Change user password via fuzzel (Void Linux, Wayland)
#
# Design: passwd(1) requires reading input from a real tty. Instead of
# simulating it with a pty wrapper (expect/python/socat), we run it in
# a real terminal (alacritty) and type passwords via "wtype" synthetic
# keyboard input. This avoids additional languages (python/expect),
# sudo, wheel group, or pkexec.
#
# Dependencies:
#   - fuzzel      (xbps-install -S fuzzel)
#   - alacritty   (xbps-install -S alacritty)
#   - wtype       (xbps-install -S wtype)   -- Wayland synthetic keyboard input
#   - libnotify   (for notify-send, xbps-install -S libnotify)

set -uo pipefail

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_CHANGE_PASSWD

FUZZEL_OPTS=(--lines=1 --anchor=top-right --log-no-syslog)
USER_NAME="$(id -un)"
WIN_CLASS="fuzzelpasswd"
RESULT_FILE="$(mktemp /tmp/fuzzelpasswd.XXXXXX)"

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

# Simple info window (closed with OK)
info_box() {
    local msg="$1"
    close_fuzzel
    printf 'OK\n' | fuzzel --dmenu --prompt="$msg" "${FUZZEL_OPTS[@]}" >/dev/null 2>&1
}

notify() {
    notify-send "$@"
}

# Type text via wtype, then press Enter
type_and_enter() {
    local text="$1"
    wtype -- "$text"
    sleep 0.15
    wtype -k Return
}

# --- Dependency check -----------------------------------------------
for bin in fuzzel alacritty wtype; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        info_box "$(i18n_template "${MSG[MSG_NOT_INSTALLED]}" BIN="$bin")"
        notify -u critical "${MSG[NOTIFY_TITLE]}" "$(i18n_template "${i18n[NOT_INSTALLED]}" BIN="$bin")"
        exit 1
    fi
done

# --- 1) Ask for current password -----
CURRENT_PASS="$(ask_password "${MSG[PROMPT_CURRENT]}")"
if [[ -z "$CURRENT_PASS" ]]; then
    notify "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_CANCELLED]}"
    exit 1
fi

# --- 2) Ask for new password twice ---
NEW_PASS1="$(ask_password "${MSG[PROMPT_NEW]}")"
if [[ -z "$NEW_PASS1" ]]; then
    notify "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_CANCELLED]}"
    unset CURRENT_PASS
    exit 1
fi

NEW_PASS2="$(ask_password "${MSG[PROMPT_NEW_REPEAT]}")"
if [[ -z "$NEW_PASS2" ]]; then
    notify "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_CANCELLED]}"
    unset CURRENT_PASS NEW_PASS1
    exit 1
fi

if [[ "$NEW_PASS1" != "$NEW_PASS2" ]]; then
    notify -u critical "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_MISMATCH]}"
    unset CURRENT_PASS NEW_PASS1 NEW_PASS2
    exit 1
fi

# --- 3) Clean up stray window, open passwd in real terminal ---
pkill -f "alacritty --class $WIN_CLASS" 2>/dev/null
close_fuzzel

alacritty --class "$WIN_CLASS" -e bash -c \
    "passwd '$USER_NAME'; echo \$? > '$RESULT_FILE'" &

# Wait for window to open and passwd to show first prompt
sleep 0.7

# --- 4) Type passwords in sequence ---
type_and_enter "$CURRENT_PASS"
sleep 0.4
type_and_enter "$NEW_PASS1"
sleep 0.4
type_and_enter "$NEW_PASS2"

# --- 5) Wait for result ---
STATUS=1
for _ in $(seq 1 50); do
    if [[ -s "$RESULT_FILE" ]]; then
        STATUS="$(cat "$RESULT_FILE")"
        break
    fi
    sleep 0.1
done

pkill -f "alacritty --class $WIN_CLASS" 2>/dev/null
unset CURRENT_PASS NEW_PASS1 NEW_PASS2

if [[ "$STATUS" -eq 0 ]]; then
    notify "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_SUCCESS]}"
else
    notify -u critical "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_FAILED]}"
fi

exit "$STATUS"
