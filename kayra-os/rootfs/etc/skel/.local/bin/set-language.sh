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
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

LANG_CODE="${1:-}"

if [ -z "$LANG_CODE" ]; then
    log "ERROR" "No language code provided"
    echo "Usage: $0 [OPTIONS] <lang-code>" >&2
    echo "Available: en, tr" >&2
    exit 1
fi

# Verify language file exists, fallback to English if not
if [ ! -f "$LANG_DIR/$LANG_CODE.sh" ]; then
    if [ ! -f "$LANG_DIR/en.sh" ]; then
        log "ERROR" "Language '$LANG_CODE' not found and fallback 'en.sh' missing"
        echo "Error: Language '$LANG_CODE' not found and fallback 'en.sh' missing" >&2
        exit 1
    fi
    log "WARN" "Language '$LANG_CODE' not found, falling back to English"
    if [ "$QUIET" = false ]; then
        echo "Warning: Language '$LANG_CODE' not found, falling back to English" >&2
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

if [ "$QUIET" = false ]; then
    echo "Language set to: $LANG_CODE"
fi
