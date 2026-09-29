#!/usr/bin/env bash
#
# Language Settings - Display available languages and apply selection
# Gets available languages from system locales and allows switching

set -euo pipefail
export LC_ALL=C

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_SETTINGS_MENU

# Get current language from ~/.profile
# Extract language code from locale string (first 2 chars)
PROFILE_FILE="$HOME/.profile"
CURRENT_LANG="en"  # Default fallback

if [ -f "$PROFILE_FILE" ]; then
    # Source .profile to get LANG variable directly
    source "$PROFILE_FILE" 2>/dev/null
    # Extract first 2 characters as language code
    CURRENT_LANG="${LANG:0:2}"
    # Fallback to "en" if extraction failed
    [ -z "$CURRENT_LANG" ] && CURRENT_LANG="en"
fi

# Extract available languages from locale -av
# Only includes locales with 'language' field (filters out C.utf8, POSIX, etc.)
# Format: locale_code = language_name
# Example: en_US.utf8 = American English
LANGUAGES=$(locale -av | awk '/^locale:/{loc=$2} /language \|/{gsub(/.*language \| /,""); print loc " = " $0}' | sed 's/ .*archive.*//')

# Parse and create menu array
declare -A lang_menu
declare -a lang_codes
declare -a lang_names

while IFS= read -r line; do
    # Extract locale code and language name
    # en_US.utf8 = American English
    locale_code=$(echo "$line" | cut -d' ' -f1)
    language_name=$(echo "$line" | cut -d'=' -f2 | sed 's/^ //')

    # Extract short code from locale: first 2 characters (en_US.utf8 -> en)
    short_code="${locale_code:0:2}"

    # Store for menu
    lang_menu["$language_name"]="$short_code"
    lang_codes+=("$short_code")
    lang_names+=("$language_name")
done <<< "$LANGUAGES"

# Get current language's full name for highlighting
CURRENT_NAME=""
for name in "${lang_names[@]}"; do
    if [[ "${lang_menu[$name]}" == "$CURRENT_LANG" ]]; then
        CURRENT_NAME="$name"
        break
    fi
done

# Close any existing fuzzel processes
pkill -x fuzzel 2>/dev/null || true

# Show fuzzel menu with current language marked with *
SELECTED=$(
  (if [ -n "$CURRENT_NAME" ]; then
     printf '* %s\n' "$CURRENT_NAME"
   fi
   printf '%s\n' "${lang_names[@]}" | grep -v "^${CURRENT_NAME}$" 2>/dev/null || true) | \
  fuzzel --dmenu --log-no-syslog --anchor=top-right "$@" --prompt="Select: "
) || exit 0

# Exit if user cancelled
[[ -z "$SELECTED" ]] && exit 0

# Remove the marker if present
SELECTED="${SELECTED#\* }"

# Check if selection is same as current
if [[ "$SELECTED" == "$CURRENT_NAME" ]]; then
    exit 0
fi

# Get language code for selection
SELECTED_CODE="${lang_menu[$SELECTED]}"

# Apply language change
if ~/.local/bin/set-language.sh "$SELECTED_CODE" 2>&1; then
    notify-send -i preferences-desktop-locale "Language" "Changed to: $SELECTED"
else
    notify-send -u critical "Language" "Failed to change language to: $SELECTED"
    exit 1
fi
