#!/bin/bash

WAYBAR_THEME_CSS="$HOME/.config/waybar/theme.css"
FUZZEL_INI="$HOME/.config/fuzzel/fuzzel.ini"
SWAYNC_THEME_DIR="$HOME/.config/swaync/"

# Argüman zorunlu: yoksa jq'ya boş girdi verilir ve hiçbir şey yapılmaz
if [[ $# -ne 1 ]]; then
    echo "Usage: change-theme.sh <json>" >&2
    exit 1
fi
json="$1"
bg=$(echo "$json" | jq -r '.bg // empty')
fg=$(echo "$json" | jq -r '.fg // empty')
sbg=$(echo "$json" | jq -r '.selected_bg // empty')
sfg=$(echo "$json" | jq -r '.selected_fg // empty')

# waybar/theme.css
[ -n "$bg" ] && sed -i -E "s/^([[:space:]]*@define-color[[:space:]]+color-bg[[:space:]]+)[^;]*;/\1$bg;/" "$WAYBAR_THEME_CSS"
[ -n "$bg" ] && sed -i -E "s/^([[:space:]]*@define-color[[:space:]]+color-surface[[:space:]]+)[^;]*;/\1$bg;/" "$WAYBAR_THEME_CSS"
[ -n "$fg" ] && sed -i -E "s/^([[:space:]]*@define-color[[:space:]]+color-fg[[:space:]]+)[^;]*;/\1$fg;/" "$WAYBAR_THEME_CSS"
[ -n "$sbg" ] && sed -i -E "s/^([[:space:]]*@define-color[[:space:]]+color-fg-hover[[:space:]]+)[^;]*;/\1$sbg;/" "$WAYBAR_THEME_CSS"

cp "$WAYBAR_THEME_CSS" "$SWAYNC_THEME_DIR"

# fuzzel/fuzzel.ini (alpha ff eklenerek)
f() { echo "${1#\#}ff"; }
[ -n "$bg" ] && sed -i "s/^background=.*/background=$(f "$bg")/" "$FUZZEL_INI"
[ -n "$fg" ] && sed -i "s/^text=.*/text=$(f "$fg")/" "$FUZZEL_INI"
[ -n "$sfg" ] && sed -i "s/^match=.*/match=$(f "$sfg")/" "$FUZZEL_INI"
[ -n "$sbg" ] && sed -i "s/^selection=.*/selection=$(f "$sbg")/" "$FUZZEL_INI"
[ -n "$sfg" ] && sed -i "s/^selection-text=.*/selection-text=$(f "$sfg")/" "$FUZZEL_INI"
[ -n "$fg" ] && sed -i "s/^selection-match=.*/selection-match=$(f "$fg")/" "$FUZZEL_INI"
[ -n "$fg" ] && sed -i "s/^border=.*/border=$(f "$fg")/" "$FUZZEL_INI"

pkill -USR2 waybar
