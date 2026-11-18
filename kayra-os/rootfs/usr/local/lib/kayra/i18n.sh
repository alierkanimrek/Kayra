#!/usr/bin/env bash
#
# i18n.sh - Kayra OS i18n library (source it; do not execute it).
#
# Loads the active language file and its string arrays:
#   the "lang" key of ~/.config/kayra/settings.conf (via settings-conf.sh)
#   selects /usr/local/share/kayra/lang/<code>.sh; en.sh is the fallback.
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
# array/key names identical, then run: kayra-set-language.sh <code>.
#
LANG_DIR="/usr/local/share/kayra/lang"

# The language code is read from settings.conf (lang=); English is the default.
# A missing data file also falls back to English.
. /usr/local/lib/kayra/settings-conf.sh 2>/dev/null || true
I18N_LANG_CODE=$(conf_get lang 2>/dev/null)
I18N_LANG_CODE=${I18N_LANG_CODE:-en}

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
