#!/bin/bash
#
# set-language.sh - Switch system language
# Usage: set-language.sh [OPTIONS] <lang-code>
# Options:
#   -q, --quiet    Suppress output
#   --get-current  Print current language
# Examples:
#   set-language.sh tr              # Set to Turkish
#   set-language.sh en              # Set to English
#   set-language.sh --get-current   # Show current language

set -euo pipefail
export LC_ALL=C

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_SET_LANGUAGE

BIN_DIR="$(cd "$(dirname "$0")" && pwd)"
LANG_DIR="$BIN_DIR/lang"
CONFIG_DIR="$HOME/.config/waybar"
LOG_DIR="$HOME/.local/var/log"
LOG_FILE="$LOG_DIR/sway.log"
QUIET=false

# Create log directory if needed
mkdir -p "$LOG_DIR" 2>/dev/null || true

# Log function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [set-language] [$level] $message" >> "$LOG_FILE"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -q|--quiet)
      QUIET=true
      shift
      ;;
    --get-current)
      if [ -L "$LANG_DIR/current.sh" ]; then
        basename "$(readlink "$LANG_DIR/current.sh")" .sh
      else
        echo "en"  # Default fallback
      fi
      exit 0
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS] <lang-code>"
      echo "Set system language (affects i18n, menus, waybar)"
      echo ""
      echo "Options:"
      echo "  -q, --quiet      Suppress output"
      echo "  --get-current    Print current language code"
      echo "  -h, --help       Show this help"
      echo ""
      echo "Available languages: en, tr"
      exit 0
      ;;
    -*)
      log "ERROR" "Unknown option: $1"
      echo "$(i18n_template "Error: Unknown option: {OPT}" OPT="$1")" >&2
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

LANG_CODE="${1:-en}"

# Map language codes to locale strings
declare -A LOCALE_MAP=(
    ["en"]="en_US.UTF-8"
    ["tr"]="tr_TR.UTF-8"
)

# Verify language file exists, fallback to English if not
if [ ! -f "$LANG_DIR/$LANG_CODE.sh" ]; then
    if [ ! -f "$LANG_DIR/en.sh" ]; then
        log "ERROR" "Language '$LANG_CODE' not found and fallback 'en.sh' missing"
        echo "$(i18n_template "Error: Language {LANG} not found and fallback 'en.sh' missing" LANG="$LANG_CODE")" >&2
        exit 1
    fi
    log "WARN" "Language '$LANG_CODE' not found, falling back to English"
    if [ "$QUIET" = false ]; then
        echo "$(i18n_template "${MSG[WARN_FALLBACK]}" LANG="$LANG_CODE")" >&2
    fi
    LANG_CODE="en"
fi

# Update language symlink
ln -sf "$LANG_CODE.sh" "$LANG_DIR/current.sh"
log "INFO" "Language set to: $LANG_CODE"

# Update waybar config if it exists
if [ -d "$CONFIG_DIR" ]; then
    if [ -f "$CONFIG_DIR/config-$LANG_CODE.jsonc" ]; then
        ln -sf "config-$LANG_CODE.jsonc" "$CONFIG_DIR/config.jsonc"
        log "INFO" "Waybar config updated for language: $LANG_CODE"
    fi
fi

# Update ~/.profile with LANG and LC_ALL
PROFILE_FILE="$HOME/.profile"
LOCALE_STRING="${LOCALE_MAP[$LANG_CODE]}"
LOCALE_ESCAPED=$(printf '%s\n' "$LOCALE_STRING" | sed -e 's/[\/&]/\\&/g')

if [ -f "$PROFILE_FILE" ]; then
    # Update existing LANG and LC_ALL values
    if grep -q "^export LANG=" "$PROFILE_FILE"; then
        sed -i "s/^export LANG=.*/export LANG=$LOCALE_ESCAPED/" "$PROFILE_FILE"
    else
        echo "export LANG=$LOCALE_STRING" >> "$PROFILE_FILE"
    fi

    if grep -q "^export LC_ALL=" "$PROFILE_FILE"; then
        sed -i "s/^export LC_ALL=.*/export LC_ALL=$LOCALE_ESCAPED/" "$PROFILE_FILE"
    else
        echo "export LC_ALL=$LOCALE_STRING" >> "$PROFILE_FILE"
    fi
    log "INFO" "Updated ~/.profile with LANG and LC_ALL: $LOCALE_STRING"
else
    # Create .profile if it doesn't exist
    cat > "$PROFILE_FILE" << 'EOFPROFILE'
# User profile - language and locale settings
export LANG=
export LC_ALL=
EOFPROFILE
    # Update the values using sed to properly escape special characters
    sed -i "s/^export LANG=$/export LANG=$LOCALE_ESCAPED/" "$PROFILE_FILE"
    sed -i "s/^export LC_ALL=$/export LC_ALL=$LOCALE_ESCAPED/" "$PROFILE_FILE"
    log "INFO" "Created ~/.profile with LANG and LC_ALL: $LOCALE_STRING"
fi

# Signal waybar to reload configuration if it's running
pkill -SIGUSR2 waybar 2>/dev/null || true

if [ "$QUIET" = false ]; then
    echo "$(i18n_template "${MSG[MSG_SUCCESS]}" LANG="$LANG_CODE")"
fi
