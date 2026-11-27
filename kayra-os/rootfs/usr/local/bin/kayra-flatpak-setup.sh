#!/usr/bin/env bash
#
# kayra-flatpak-setup.sh - Set up the Flathub remote and refresh its metadata
# for the system or for the current user. Optionally install an application.
#
# The script is never started automatically. The user runs it from the
# application menu or from a terminal, and it is safe to run again at any
# time:
#   * The installation scope is selected from a fuzzel menu:
#       System (all users) - system-wide remote and appstream, via pkexec
#       User (only me)     - user-level remote and appstream, without root
#   * The selected flathub remote is added when it is missing.
#   * The appstream metadata is refreshed, so the application list is not
#     empty on a system where the remote was added before the network was up.
#   * The remote is checked again before the script reports success.
#   * The optional application is installed in the selected scope.
#
# --repair recreates the remote of the selected scope and is meant for a
# broken remote configuration that older Kayra images left behind, when the
# remote was added during early boot before the network was available.
# Installed applications are kept; only the remote configuration is
# recreated.
#
# Usage:
#   kayra-flatpak-setup.sh [--repair] [APP_ID]
#
# Dependencies:
#   - flatpak, fuzzel, curl
#   - polkit (pkexec, only for the system scope)
#   - libnotify (for notify-send, xbps-install -S libnotify)
#
# Used commands: flatpak, fuzzel, pkill, pkexec, curl, command, printf, sh,
#                wc, notify-send (via notify.sh)
#

set -uo pipefail
export LC_ALL=C.UTF-8

source /usr/local/lib/kayra/i18n.sh
declare -n MSG=i18n_FLATPAK_SETUP

source /usr/local/lib/kayra/klog.sh
source /usr/local/lib/kayra/notify.sh

KLOG_SCRIPT="kayra-flatpak-setup"
REPO_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"
REMOTE_NAME="flathub"

# The package installs the binary in /usr/bin. Keep the fallback absolute so
# pkexec never runs an executable that was resolved from the user's PATH.
FLATPAK_BIN="/usr/bin/flatpak"
[[ -x $FLATPAK_BIN ]] || FLATPAK_BIN="/usr/sbin/flatpak"

# Material Symbols codepoints: package (E48F), computer (E30A), person (E7FD).
NOTIFY_ICON="$(printf '%b' '\U0000E48F')"
ICON_SYSTEM="$(printf '%b' '\U0000E30A')"
ICON_USER="$(printf '%b' '\U0000E7FD')"
NOTIFY_APP="${MSG[APP_NAME]}"

REPAIR=0
APP_ID=""

usage() {
    printf '%s\n' "${MSG[MSG_USAGE]}"
}

die_usage() {
    usage >&2
    exit 2
}

while (($#)); do
    case "$1" in
        --repair)
            REPAIR=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            die_usage
            ;;
        *)
            [[ -z $APP_ID ]] || die_usage
            APP_ID="$1"
            ;;
    esac
    shift
done

if ((EUID == 0)); then
    printf 'kayra-flatpak-setup: run this script as the desktop user, not as root\n' >&2
    exit 1
fi

if [[ ! -x $FLATPAK_BIN ]]; then
    log ERROR "flatpak was not found"
    notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_NO_FLATPAK]}"
    exit 1
fi

if ! command -v fuzzel >/dev/null 2>&1; then
    log ERROR "fuzzel was not found"
    notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_NO_FUZZEL]}"
    exit 1
fi

if [[ -n $APP_ID && ! $APP_ID =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    log ERROR "Invalid application id: $APP_ID"
    notify_error "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MSG_INVALID_APP]}" APP="$APP_ID")"
    exit 1
fi

# Installation scope. The menu is short and fixed, so it uses minimal lines
# and no prompt; the labels themselves explain the two choices.
LINES=(
    "$ICON_SYSTEM ${MSG[SCOPE_SYSTEM]}"
    "$ICON_USER ${MSG[SCOPE_USER]}"
)

pkill -x fuzzel 2>/dev/null || true

# Window width of the longest menu entry (icon counted as 3 characters).
MAX_WIDTH=$(printf '%s\n' "${LINES[@]}" | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')

SELECTED=$(printf '%s\n' "${LINES[@]}" |
    fuzzel --dmenu --anchor=top-right --log-no-syslog --minimal-lines \
        --lines="${#LINES[@]}" --width="$MAX_WIDTH" --hide-prompt) || true

[ -z "$SELECTED" ] && exit 0

case "${SELECTED#* }" in
    "${MSG[SCOPE_SYSTEM]}")
        SCOPE=system
        SCOPE_FLAG=--system
        SCOPE_LABEL="${MSG[SCOPE_SYSTEM]}"
        ;;
    "${MSG[SCOPE_USER]}")
        SCOPE=user
        SCOPE_FLAG=--user
        SCOPE_LABEL="${MSG[SCOPE_USER]}"
        ;;
    *)
        exit 0
        ;;
esac

# pkexec is only needed for the system-wide installation.
if [[ $SCOPE == system ]] && ! command -v pkexec >/dev/null 2>&1; then
    log ERROR "pkexec was not found"
    notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_NO_PKEXEC]}"
    exit 1
fi

# Fail early when there is no network. The actual work is done by the helper
# below, so this check also tells the user why nothing was downloaded.
if command -v curl >/dev/null 2>&1; then
    if ! curl -fsS --max-time 10 -o /dev/null "$REPO_URL" 2>/dev/null; then
        log ERROR "Network check for $REPO_URL failed"
        notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_NO_NETWORK]}"
        exit 1
    fi
fi

log INFO "Setting up Flathub (scope=$SCOPE, repair=$REPAIR, app=${APP_ID:-none})"

# The privileged part. It is passed as a fixed script; the arguments below
# are positional parameters, so no user value is ever parsed as shell code.
# The same helper handles the user scope: there it runs as the user and
# flatpak is called with --user.
read -r -d '' SETUP_SCRIPT <<'SETUP' || true
set -eu
scope="$1"
remote="$2"
name="$3"
app="$4"
repair="$5"
bin="$6"

if [ "$repair" = "1" ]; then
    "$bin" "$scope" remote-delete --force "$name" >/dev/null 2>&1 || true
fi

"$bin" "$scope" remote-add --if-not-exists "$name" "$remote" >/dev/null
"$bin" "$scope" update --appstream --noninteractive >/dev/null
"$bin" "$scope" remote-ls --app "$name" --columns=application >/dev/null

if [ -n "$app" ]; then
    "$bin" "$scope" install -y "$name" "$app" >/dev/null || exit 2
fi

"$bin" "$scope" remote-ls --app "$name" --columns=application | wc -l
SETUP

if [[ $SCOPE == system ]]; then
    COUNT="$(pkexec /bin/sh -c "$SETUP_SCRIPT" sh \
        "$SCOPE_FLAG" "$REPO_URL" "$REMOTE_NAME" "$APP_ID" "$REPAIR" \
        "$FLATPAK_BIN" 2>/dev/null)"
    RC=$?
else
    COUNT="$(/bin/sh -c "$SETUP_SCRIPT" sh \
        "$SCOPE_FLAG" "$REPO_URL" "$REMOTE_NAME" "$APP_ID" "$REPAIR" \
        "$FLATPAK_BIN" 2>/dev/null)"
    RC=$?
fi

# pkexec returns 126/127 when the polkit dialog was dismissed or the user is
# not authorized, and 125 when no authentication agent answered.
if [[ $SCOPE == system ]] && ((RC == 125 || RC == 126 || RC == 127)); then
    log ERROR "pkexec authorization failed (exit $RC)"
    notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_PRIVILEGE_FAIL]}"
    exit 1
fi

if ((RC == 2)) && [[ -n $APP_ID ]]; then
    log ERROR "Could not install $APP_ID ($SCOPE)"
    notify_error "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MSG_INSTALL_FAIL]}" \
            APP="$APP_ID" SCOPE="$SCOPE_LABEL")"
    exit 1
fi

if ((RC != 0)); then
    log ERROR "Flathub setup failed ($SCOPE, exit $RC)"
    notify_error "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MSG_SETUP_FAIL]}" SCOPE="$SCOPE_LABEL")"
    exit 1
fi

COUNT="${COUNT//[[:space:]]/}"
if [[ ! $COUNT =~ ^[0-9]+$ ]] || ((COUNT < 1)); then
    log ERROR "Flathub returned no applications ($SCOPE)"
    notify_error "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MSG_SETUP_FAIL]}" SCOPE="$SCOPE_LABEL")"
    exit 1
fi

if [[ -n $APP_ID ]]; then
    log INFO "Installed $APP_ID ($SCOPE)"
    notify_ok "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MSG_INSTALL_OK]}" \
            APP="$APP_ID" SCOPE="$SCOPE_LABEL")"
else
    log INFO "Flathub ready ($SCOPE, $COUNT applications)"
    notify_ok "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MSG_SETUP_OK]}" \
            COUNT="$COUNT" SCOPE="$SCOPE_LABEL")"
fi

exit 0
