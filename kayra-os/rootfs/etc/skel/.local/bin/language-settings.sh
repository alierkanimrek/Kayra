#!/usr/bin/env bash
#
# language-settings.sh - Display the available languages and apply the selection.
#
# The available languages come from the system locales (locale -av). The
# current language is read from ~/.profile. The current language is marked
# with a filled circle, the other languages with an empty circle.
#
# The locale code of the selected entry is handed over to set-language.sh.
# The mapping of the locale code to the language data file (lang/<code>.sh)
# and to the locale string is done there.
#
# Usage: language-settings.sh [fuzzel parameters...]
#
# Dependencies:
#   - fuzzel      (xbps-install -S fuzzel)
#   - libnotify   (for notify-send, xbps-install -S libnotify)
#
# Used commands: fuzzel, pkill, locale, awk, grep, cut, tr, set-language.sh
#
set -uo pipefail
export LC_ALL=C.UTF-8

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_LANGUAGE_SETTINGS

source "$(dirname "$0")/klog.sh"
source "$(dirname "$0")/notify.sh"

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
PROFILE_FILE="$HOME/.profile"
SET_LANGUAGE="$SCRIPT_DIR/set-language.sh"

# Icon shown on the notification (Material Symbols codepoint).
NOTIFY_ICON="\U000F799"

# Menu icons: filled circle for the current language, empty circle for the
# other languages.
ICON_CURRENT=$(LC_ALL=C.UTF-8 printf '%b' '\U000025CF')
ICON_OTHER=$(LC_ALL=C.UTF-8 printf '%b' '\U000025CB')

# Available locales from the system: "<locale code>|<language name>".
LOCALE_LIST=$(locale -av 2>/dev/null | awk '
    /^locale:/ { loc = $2; next }
    /language \|/ {
        name = $0
        sub(/.*language \| /, "", name)
        gsub(/^[ \t]+|[ \t]+$/, "", name)
        if (loc != "" && loc ~ /^[a-z][a-z]/) print loc "|" name
    }
')

# Current language code, read from ~/.profile (the first two characters of
# the LANG value, e.g. "en_US.UTF-8" -> "en").
CURRENT_CODE="en"
if [[ -f "$PROFILE_FILE" ]]; then
    PROFILE_LANG="$(grep -m1 '^export LANG=' "$PROFILE_FILE" 2>/dev/null | cut -d= -f2- | tr -d '"'"'" | tr -d '[:space:]')"
    [[ -z "$PROFILE_LANG" ]] && PROFILE_LANG="$(grep -m1 '^export LC_ALL=' "$PROFILE_FILE" 2>/dev/null | cut -d= -f2- | tr -d '"'"'" | tr -d '[:space:]')"
    [[ -n "$PROFILE_LANG" ]] && CURRENT_CODE="${PROFILE_LANG:0:2}"
fi
[[ -z "$CURRENT_CODE" ]] && CURRENT_CODE="en"

if [[ -z "$LOCALE_LIST" ]]; then
    log ERROR "No system locales found"
    notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_NO_LANGUAGES]}"
    exit 1
fi

# Build the menu lines and keep the locale code of every entry.
declare -a LINES=()
declare -a CODES=()

while IFS='|' read -r loc_code loc_name; do
    [[ -z "$loc_code" ]] && continue

    short_code="${loc_code:0:2}"
    if [[ "$short_code" == "$CURRENT_CODE" ]]; then
        LINES+=("$ICON_CURRENT $loc_name")
    else
        LINES+=("$ICON_OTHER $loc_name")
    fi
    CODES+=("$loc_code")
done <<< "$LOCALE_LIST"

# Close any existing fuzzel processes
pkill -x fuzzel 2>/dev/null || true

# Window width of the longest menu entry (icon counted as 3 characters)
MAX_WIDTH=$(printf '%s\n' "${LINES[@]}" | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')

# Get the selection from the fuzzel menu
SELECTED=$(printf '%s\n' "${LINES[@]}" | fuzzel --dmenu --anchor=top-right --log-no-syslog \
    --minimal-lines --lines="${#LINES[@]}" --width="$MAX_WIDTH" --hide-prompt "$@") || true

# Exit if the user cancelled the menu
[[ -z "$SELECTED" ]] && exit 0

# Index of the selected entry and its locale code
SEL_INDEX=$(printf '%s\n' "${LINES[@]}" | awk -v sel="$SELECTED" '$0 == sel { print NR - 1; exit }')
[[ -z "$SEL_INDEX" ]] && exit 0

SELECTED_LOCALE="${CODES[$SEL_INDEX]}"
[[ -z "$SELECTED_LOCALE" ]] && exit 0

# Do nothing when the selected language is already active
if [[ "${SELECTED_LOCALE:0:2}" == "$CURRENT_CODE" ]]; then
    log INFO "Language ${SELECTED_LOCALE} is already active"
    exit 0
fi

if [[ ! -x "$SET_LANGUAGE" ]]; then
    log ERROR "Language script is missing: $SET_LANGUAGE"
    notify_error "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MSG_FAILED]}" LANG="$SELECTED_LOCALE")"
    exit 1
fi

log INFO "Changing the language to $SELECTED_LOCALE"

if "$SET_LANGUAGE" "$SELECTED_LOCALE"; then
    log INFO "Language changed to $SELECTED_LOCALE"
else
    log ERROR "Failed to change the language to $SELECTED_LOCALE"
    notify_error "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MSG_FAILED]}" LANG="$SELECTED_LOCALE")"
    exit 1
fi
