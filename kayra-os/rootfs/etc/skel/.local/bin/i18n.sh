#!/usr/bin/env bash

LANG_CODE="${LANG%%_*}"

LANG_DIR="$(dirname "${BASH_SOURCE[0]}")/lang"
LANG_FILE="$LANG_DIR/$LANG_CODE.sh"

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
