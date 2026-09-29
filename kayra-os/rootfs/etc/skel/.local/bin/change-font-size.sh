#!/usr/bin/env bash
#
# Change Font Size - Updates font size in settings and applies to Waybar and Fuzzel
# Usage: change-font-size.sh <size>
# Size: integer between 8 and 48 (pixels)

set -euo pipefail
export LC_ALL=C

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_CHANGE_FONT_SIZE

if [[ $# -ne 1 ]]; then
    echo "$(i18n_template "${MSG[USAGE_ERROR]}" SCRIPT="$(basename "$0")")" >&2
    exit 1
fi

SIZE="$1"

# Validate size is a number between 8 and 48
if ! [[ "$SIZE" =~ ^[0-9]+$ ]] || (( SIZE < 8 || SIZE > 48 )); then
    echo "$(i18n_template "${MSG[ERROR_INVALID_SIZE]}" MIN="8" MAX="48")" >&2
    exit 1
fi

SETTINGS_FILE="$HOME/.config/kayra/settings.conf"
WAYBAR_THEME="$HOME/.config/waybar/theme.css"
FUZZEL_CONFIG="$HOME/.config/fuzzel/fuzzel.ini"
SWAYNC_THEME="$HOME/.config/swaync/style.css"
ALACRITTY_CONFIG="$HOME/.config/alacritty/alacritty.toml"

# Update settings.conf
if [[ -f "$SETTINGS_FILE" ]]; then
    if grep -q "^font_size=" "$SETTINGS_FILE"; then
        sed -i "s/^font_size=.*/font_size=$SIZE/" "$SETTINGS_FILE"
    else
        echo "font_size=$SIZE" >> "$SETTINGS_FILE"
    fi
    echo "${MSG[MSG_SUCCESS]}"
else
    echo "$(i18n_template "${MSG[ERROR_SETTINGS_NOT_FOUND]}" FILE="$SETTINGS_FILE")" >&2
    exit 1
fi

# Update Waybar theme.css
if [[ -f "$WAYBAR_THEME" ]]; then
    sed -i "s/font-size: [0-9]*px;/font-size: ${SIZE}px;/" "$WAYBAR_THEME"
fi

# Update Fuzzel config (remove old size and add new one)
if [[ -f "$FUZZEL_CONFIG" ]]; then
    if grep -q "^font=" "$FUZZEL_CONFIG"; then
        sed -i "s/^font=\(.*\):size=[0-9]*/font=\1:size=$SIZE/" "$FUZZEL_CONFIG"
    fi
fi

# Update Swaync theme (add font-size to * selector if not present, or update existing)
if [[ -f "$SWAYNC_THEME" ]]; then
    if grep -q "^\* {" "$SWAYNC_THEME"; then
        # Check if font-size already exists in * selector
        if sed -n '/^\* {/,/^}/p' "$SWAYNC_THEME" | grep -q "font-size:"; then
            sed -i "/^\* {/,/^}/{s/font-size: [0-9]*px;/font-size: ${SIZE}px;/}" "$SWAYNC_THEME"
        else
            # Add font-size after font-family line in * selector
            sed -i "/^\* {/,/^}/{/font-family:/a\    font-size: ${SIZE}px;
}" "$SWAYNC_THEME"
        fi
    fi
fi

# Update Alacritty config (TOML format: size = 12.0)
if [[ -f "$ALACRITTY_CONFIG" ]]; then
    sed -i "s/^size = [0-9.]*$/size = ${SIZE}.0/" "$ALACRITTY_CONFIG"
fi

# Reload Waybar
pkill -SIGUSR2 waybar 2>/dev/null || true

# Reload Swaync
pkill -SIGUSR1 swaync 2>/dev/null || true
