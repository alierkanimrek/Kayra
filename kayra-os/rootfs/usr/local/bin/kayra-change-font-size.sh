#!/usr/bin/env bash
#
# Change Font Size - Updates font size in settings and applies it to Waybar,
# Fuzzel and SwayNC.
# Usage: kayra-change-font-size.sh <size>
# Size: integer between 8 and 48 (pixels)
#
# Used libraries: klog.sh, settings-conf.sh
# Used commands: sed, pkill, swaync-client

set -euo pipefail
export LC_ALL=C.UTF-8

source /usr/local/lib/kayra/klog.sh
source /usr/local/lib/kayra/settings-conf.sh

if [[ $# -ne 1 ]]; then
    echo "Usage: change-font-size.sh <size 8...48>" >&2
    exit 1
fi

SIZE="$1"

# Validate size is a number between 8 and 48
if ! [[ "$SIZE" =~ ^[0-9]+$ ]] || (( SIZE < 8 || SIZE > 48 )); then
    echo "# Usage: change-font-size.sh <size>)" >&2
    exit 1
fi

SETTINGS_FILE="$HOME/.config/kayra/settings.conf"
WAYBAR_THEME="$HOME/.config/waybar/theme.css"
FUZZEL_CONFIG="$HOME/.config/fuzzel/fuzzel.ini"
SWAYNC_THEME="$HOME/.config/swaync/style.css"
ALACRITTY_CONFIG="$HOME/.config/alacritty/alacritty.toml"

# Update settings.conf
if [[ -f "$SETTINGS_FILE" ]]; then
    conf_set font_size "$SIZE"
    log "DEBUG" "Font size changed to $SIZE in $SETTINGS_FILE"
else
    log "ERROR" "Settings file not found: $SETTINGS_FILE"
    exit 1
fi

# Update Waybar theme.css
if [[ -f "$WAYBAR_THEME" ]]; then
    sed -i "s/font-size: [0-9]*px;/font-size: ${SIZE}px;/" "$WAYBAR_THEME"
    log "DEBUG" "Font size changed to $SIZE in waybar $WAYBAR_THEME"
fi

# Update Fuzzel config (remove old size and add new one)
if [[ -f "$FUZZEL_CONFIG" ]]; then
    if grep -q "^font=" "$FUZZEL_CONFIG"; then
        sed -i "s/^font=\(.*\):pixelsize=[0-9]*/font=\1:pixelsize=$SIZE/" "$FUZZEL_CONFIG"
        log "DEBUG" "Font size changed to $SIZE in $FUZZEL_CONFIG"
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
        log "DEBUG" "Font size changed to $SIZE in swaync $SWAYNC_THEME"
    fi
fi

# Update Alacritty config (TOML format: size = 12.0)
#if [[ -f "$ALACRITTY_CONFIG" ]]; then
#    sed -i "s/^size = [0-9.]*$/size = ${SIZE}.0/" "$ALACRITTY_CONFIG"
#    log "DEBUG" "Font size changed to $SIZE in $ALACRITTY_CONFIG"
#fi

log "INFO" "Font size changed to $SIZE"

# Reload Waybar
pkill -SIGUSR2 waybar 2>/dev/null || true

# Reload SwayNC
if command -v swaync-client >/dev/null 2>&1; then
    swaync-client -rs >/dev/null 2>&1 || true
fi
