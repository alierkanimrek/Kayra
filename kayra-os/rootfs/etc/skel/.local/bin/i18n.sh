#!/usr/bin/env bash
#
# i18n.sh - Kayra OS i18n library (source it; do not execute it).
#
# Loads the active language file and its string arrays:
#   lang/current.sh (symlink set by set-language.sh) or lang/en.sh as fallback.
# Arrays: i18n_<SCREEN>_* per screen (e.g. i18n_USER_MENU), i18n for globals,
#         user_menu/settings_menu/... map a localized label to a command.
#
# Usage in a script:
#   source "$(dirname "$0")/i18n.sh"
#   declare -n MSG=i18n_MY_SCREEN
#   echo "$(i18n_template "${MSG[MSG_CHANGED]}" "VALUE=$value")"
#
# i18n_template <string> [KEY=VALUE ...]
#   Prints <string> with each {KEY} replaced by VALUE (unknown keys stay).
#
# New language: copy lang/en.sh to lang/<code>.sh, translate values, keep
# array/key names identical, then run: set-language.sh <code>.
#
LANG_DIR="$(dirname "${BASH_SOURCE[0]}")/lang"
LANG_FILE="$LANG_DIR/current.sh"

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
