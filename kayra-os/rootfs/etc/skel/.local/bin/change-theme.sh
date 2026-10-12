#!/bin/bash

WAYBAR_THEME_CSS="$HOME/.config/waybar/theme.css"
FUZZEL_INI="$HOME/.config/fuzzel/fuzzel.ini"

json="${1:-{}}"

# JSON doğrulama: hatalı/eksik girdi jq hatasını önler
if ! printf '%s\n' "$json" | jq -e . >/dev/null 2>&1; then
  echo "Hata: Geçersiz JSON parametresi: $json" >&2
  exit 1
fi

bg=$(printf '%s\n' "$json" | jq -r '.bg // empty')
fg=$(printf '%s\n' "$json" | jq -r '.fg // empty')
sbg=$(printf '%s\n' "$json" | jq -r '.selected_bg // empty')
sfg=$(printf '%s\n' "$json" | jq -r '.selected_fg // empty')

# waybar/theme.css
[ -n "$bg" ] && sed -i "s/@define-color color-bg[[:space:]]*[^;]*;/@define-color color-bg $bg;/" "$WAYBAR_THEME_CSS"
[ -n "$bg" ] && sed -i "s/@define-color color-surface[[:space:]]*[^;]*;/@define-color color-surface $bg;/" "$WAYBAR_THEME_CSS"
[ -n "$fg" ] && sed -i "s/@define-color color-fg[[:space:]]*[^;]*;/@define-color color-fg $fg;/" "$WAYBAR_THEME_CSS"
[ -n "$sfg" ] && sed -i "s/@define-color color-fg-hover[[:space:]]*[^;]*;/@define-color color-fg-hover $sfg;/" "$WAYBAR_THEME_CSS"

# fuzzel/fuzzel.ini (alpha ff eklenerek)
f() { echo "${1#\#}ff"; }
[ -n "$bg" ] && sed -i "s/^background=.*/background=$(f "$bg")/" "$FUZZEL_INI"
[ -n "$fg" ] && sed -i "s/^text=.*/text=$(f "$fg")/" "$FUZZEL_INI"
[ -n "$sfg" ] && sed -i "s/^match=.*/match=$(f "$sfg")/" "$FUZZEL_INI"
[ -n "$sbg" ] && sed -i "s/^selection=.*/selection=$(f "$sbg")/" "$FUZZEL_INI"
[ -n "$sfg" ] && sed -i "s/^selection-text=.*/selection-text=$(f "$sfg")/" "$FUZZEL_INI"
[ -n "$sfg" ] && sed -i "s/^selection-match=.*/selection-match=$(f "$sfg")/" "$FUZZEL_INI"
[ -n "$fg" ] && sed -i "s/^border=.*/border=$(f "$fg")/" "$FUZZEL_INI"
