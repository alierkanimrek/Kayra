#!/usr/bin/env bash
#
# system-menu.sh - Kayra OS boolean settings menu.
#
# Lists the boolean settings of ~/.config/kayra/settings.conf in a fuzzel
# dmenu, each prefixed with its state icon (true = ●, false = ○).
# Selecting an entry toggles the value (true <-> false) and saves it.
#
# Add a setting: put its key in SETTING_KEYS, and its translated label as
# [LABEL_<key>] in i18n_SYSTEM_MENU (lang/en.sh, lang/tr.sh).
#

set -euo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Provides conf_get / conf_set and CONFIG_FILE
source "$SCRIPT_DIR/settings-conf.sh"

# Localization strings
source "$SCRIPT_DIR/i18n.sh"
declare -n MSG=i18n_SYSTEM_MENU

# ------------------------------------------------------------------
# Settings registry - add new boolean settings here
# ------------------------------------------------------------------
SETTING_KEYS=(
    auto_theme
    error_log_notify
    kayra_error_log_notify
)

# Optional display labels; missing keys fall back to the key name
declare -A SETTING_LABELS=()

# State icons
ICON_TRUE=$(LC_ALL=C.UTF-8 printf '%b' '\U000025CF')
ICON_FALSE=$(LC_ALL=C.UTF-8 printf '%b' '\U000025CB')

# Reads a boolean setting, prints "true" or "false"
setting_get() {
    local key="$1"
    local value
    value=$(conf_get "$key" | head -n1)
    [ "$value" = "true" ] && echo "true" || echo "false"
}

# Writes a boolean setting, creating the file/entry when missing
setting_set() {
    local key="$1"
    local value="$2"

    mkdir -p "$(dirname "$CONFIG_FILE")"
    if [ ! -f "$CONFIG_FILE" ]; then
        touch "$CONFIG_FILE"
    fi

    if grep -q "^${key}=" "$CONFIG_FILE"; then
        conf_set "$key" "$value"
    else
        printf '%s="%s"\n' "$key" "$value" >>"$CONFIG_FILE"
    fi
}

# Flips true <-> false and prints the new value
setting_toggle() {
    local key="$1"
    local current
    current=$(setting_get "$key")

    local new_value="true"
    [ "$current" = "true" ] && new_value="false"

    setting_set "$key" "$new_value"
    echo "$new_value"
}

# ------------------------------------------------------------------
# Build the menu entries
# ------------------------------------------------------------------
declare -a MENU_LINES=()
declare -a MENU_KEYS=()

for key in "${SETTING_KEYS[@]}"; do
    current=$(setting_get "$key")

    if [ "$current" = "true" ]; then
        icon="$ICON_TRUE"
    else
        icon="$ICON_FALSE"
    fi

    label="${MSG[LABEL_${key}]:-${SETTING_LABELS[$key]:-$key}}"

    MENU_LINES+=("${icon} ${label}")
    MENU_KEYS+=("$key")
done

if [ "${#MENU_LINES[@]}" -eq 0 ]; then
    echo "${MSG[MSG_NO_ITEMS]:-No settings found}" >&2
    exit 1
fi

# Close any open fuzzel menu before showing a new one
pkill -x fuzzel 2>/dev/null || true

# --- Show the menu ------------------------------------------------
SELECTED=$(printf '%s\n' "${MENU_LINES[@]}" | fuzzel --dmenu --log-no-syslog --hide-prompt "$@" --prompt="${MSG[PROMPT_ACTION]:-Setting: }") || true

[ -z "$SELECTED" ] && exit 0

# Find the index of the selected line
SELECTED_INDEX=-1
for i in "${!MENU_LINES[@]}"; do
    if [ "${MENU_LINES[$i]}" = "$SELECTED" ]; then
        SELECTED_INDEX=$i
        break
    fi
done

[ "$SELECTED_INDEX" -lt 0 ] && exit 0

TARGET_KEY="${MENU_KEYS[$SELECTED_INDEX]}"
setting_toggle "$TARGET_KEY" >/dev/null

exit 0
