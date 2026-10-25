#!/bin/bash
#
# set-language.sh - Switch system language
# Usage: set-language.sh <lang-code>
# Examples:
#   set-language.sh tr              # Set to Turkish
#   set-language.sh en              # Set to English

set -euo pipefail
export LC_ALL=C

source "$(dirname "$0")/klog.sh"

BIN_DIR="$(cd "$(dirname "$0")" && pwd)"
LANG_DIR="$BIN_DIR/lang"
CONFIG_DIR="$HOME/.config/waybar"

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
        exit 1
    fi
    log  "WARN" "Warning: Language '$LANG_CODE' not found, falling back to English"
    LANG_CODE="en"
fi

# Update language symlink
ln -sf "$LANG_CODE.sh" "$LANG_DIR/current.sh"
log  "DEBUG" "Kayra language set to: $LANG_CODE"

# Update waybar config using template generator
bash "$HOME/.local/bin/waybar-config-builder.sh"
log  "DEBUG" "Waybar language set to: $LANG_CODE"

# Update ~/.profile with LANG and LC_ALL
PROFILE_FILE="$HOME/.profile"
# Eşleşmeyen dil kodu için set -u altında "unbound variable" hatası vermemesi adına yedek
LOCALE_STRING="${LOCALE_MAP[$LANG_CODE]:-${LOCALE_MAP[en]}}"
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
    log  "DEBUG" "Updated ~/.profile with LANG and LC_ALL: $LOCALE_STRING"
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
    log  "INFO" "Created ~/.profile with LANG and LC_ALL: $LOCALE_STRING"
fi

log  "INFO" "Language set to: $LANG_CODE"

# Signal waybar to reload configuration if it's running
# (sway dışında çalıştırılırsa betik yanlışlıkla hata koduyla çıkmasın)
swaymsg reload 2>/dev/null || true
