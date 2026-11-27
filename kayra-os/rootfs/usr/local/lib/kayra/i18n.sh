#!/usr/bin/env bash
#
# i18n.sh - Kayra OS i18n library (source it; do not execute it).
#
# Loads the active language file and its string arrays:
#   the "lang" key of ~/.config/kayra/settings.conf (via settings-conf.sh)
#   selects /usr/local/share/kayra/lang/<code>.sh.
#   When lang is empty (automatic mode), the language is derived from the
#   "locale" key or from the current LANG, and en.sh is the final fallback.
#   There is no lang/current.sh symlink.
# Arrays: i18n_<SCREEN>_* per screen (e.g. i18n_USER_MENU), i18n for globals,
#         user_menu/system_menu/... map a localized label to a command.
#
# Usage in a script:
#   source /usr/local/lib/kayra/i18n.sh
#   declare -n MSG=i18n_MY_SCREEN
#   echo "$(i18n_template "${MSG[MSG_CHANGED]}" "VALUE=$value")"
#
# i18n_template <string> [KEY=VALUE ...]
#   Prints <string> with each {KEY} replaced by VALUE (unknown keys stay).
#
# New language: copy lang/en.sh to lang/<code>.sh, translate values, keep
# array/key names identical, add a matching line to languages.tsv, then run:
# kayra-set-language.sh <code>.
#
LANG_DIR="/usr/local/share/kayra/lang"

# The language code is read from settings.conf (lang=). When it is empty, the
# language is derived from the locale key or the current LANG, so the interface
# follows the system language without an explicit user choice. A missing data
# file falls back to English.
. /usr/local/lib/kayra/settings-conf.sh 2>/dev/null || true
I18N_LANG_CODE=$(conf_get lang 2>/dev/null | head -n1)

if [ -z "$I18N_LANG_CODE" ]; then
    I18N_LOCALE=$(conf_get locale 2>/dev/null | head -n1)
    [ -n "$I18N_LOCALE" ] || I18N_LOCALE=${LANG:-}
    I18N_DERIVED=${I18N_LOCALE%%_*}
    if [ -n "$I18N_DERIVED" ] && [ -f "$LANG_DIR/$I18N_DERIVED.sh" ]; then
        I18N_LANG_CODE=$I18N_DERIVED
    else
        I18N_LANG_CODE=en
    fi
fi

LANG_FILE="$LANG_DIR/$I18N_LANG_CODE.sh"
[[ -f "$LANG_FILE" ]] || LANG_FILE="$LANG_DIR/en.sh"

source "$LANG_FILE"

i18n_template() {
  local result="$1"
  shift

  for pair in "$@"; do
    local key="${pair%%=*}"
    local val="${pair#*=}"
    result="${result//\{$key\}/$val}"
  done

  echo "$result"
}
