#!/bin/bash

WAYBAR_THEME_CSS="$HOME/.config/waybar/theme.css"
FUZZEL_INI="$HOME/.config/fuzzel/fuzzel.ini"

json="${1:-{}}"
bg=$(echo "$json" | jq -r '.bg // empty')
fg=$(echo "$json" | jq -r '.fg // empty')
sbg=$(echo "$json" | jq -r '.selected_bg // empty')
sfg=$(echo "$json" | jq -r '.selected_fg // empty')

fmt_fuzzel() {
  local v="$1"
  [ -z "$v" ] && return
  if [[ "$v" == \#* ]]; then
    [[ ${#v} -eq 7 ]] && echo "${v}ff" || echo "$v"
  else
    [[ ${#v} -eq 6 ]] && echo "${v}ff" || echo "$v"
  fi
}

[ -n "$bg" ]  && sed -i "s/@define-color color-bg[[:space:]]*[^;]*;/@define-color color-bg $bg;/" "$WAYBAR_THEME_CSS"
[ -n "$bg" ]  && sed -i "s/@define-color color-surface[[:space:]]*[^;]*;/@define-color color-surface $bg;/" "$WAYBAR_THEME_CSS"
[ -n "$fg" ]  && sed -i "s/@define-color color-fg[[:space:]]*[^;]*;/@define-color color-fg $fg;/" "$WAYBAR_THEME_CSS"
[ -n "$sfg" ] && sed -i "s/@define-color color-fg-hover[[:space:]]*[^;]*;/@define-color color-fg-hover $sfg;/" "$WAYBAR_THEME_CSS"

fb=$(fmt_fuzzel "$bg"); ff=$(fmt_fuzzel "$fg")
fsb=$(fmt_fuzzel "$sbg"); fsf=$(fmt_fuzzel "$sfg")

[ -n "$fb" ] && sed -i "s/^background=.*/background=$fb/" "$FUZZEL_INI"
[ -n "$ff" ] && sed -i "s/^text=.*/text=$ff/" "$FUZZEL_INI"
[ -n "$fsb" ] && sed -i "s/^match=.*/match=$fsb/" "$FUZZEL_INI"
[ -n "$fsb" ] && sed -i "s/^selection=.*/selection=$fsb/" "$FUZZEL_INI"
[ -n "$fsf" ] && sed -i "s/^selection-text=.*/selection-text=$fsf/" "$FUZZEL_INI"
[ -n "$fsb" ] && sed -i "s/^selection-match=.*/selection-match=$fsb/" "$FUZZEL_INI"
[ -n "$ff" ] && sed -i "s/^border=.*/border=$ff/" "$FUZZEL_INI"
