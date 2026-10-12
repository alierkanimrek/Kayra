#!/bin/bash

WAYBAR_THEME_CSS="$HOME/.config/waybar/theme.css"
FUZZEL_INI="$HOME/.config/fuzzel/fuzzel.ini"

json="${1:-{}}"
[ -z "${json// /}" ] && json="{}"

# JSON doğrulama: hatalı/eksik girdi jq hatasını önler
if ! jq -e . >/dev/null 2>&1 <<< "$json"; then
  echo "Hata: Geçersiz JSON parametresi: $json" >&2
  exit 1
fi

bg=$(jq -r '.bg // empty' <<< "$json")
fg=$(jq -r '.fg // empty' <<< "$json")
sbg=$(jq -r '.selected_bg // empty' <<< "$json")
sfg=$(jq -r '.selected_fg // empty' <<< "$json")

# waybar/theme.css
if [ -f "$WAYBAR_THEME_CSS" ]; then
  [ -n "$bg" ]  && sed -i "s|@define-color color-bg[[:space:]]*[^;]*;|@define-color color-bg $bg;|" "$WAYBAR_THEME_CSS"
  [ -n "$bg" ]  && sed -i "s|@define-color color-surface[[:space:]]*[^;]*;|@define-color color-surface $bg;|" "$WAYBAR_THEME_CSS"
  [ -n "$fg" ]  && sed -i "s|@define-color color-fg[[:space:]]*[^;]*;|@define-color color-fg $fg;|" "$WAYBAR_THEME_CSS"
  [ -n "$sfg" ] && sed -i "s|@define-color color-fg-hover[[:space:]]*[^;]*;|@define-color color-fg-hover $sfg;|" "$WAYBAR_THEME_CSS"
fi

# fuzzel/fuzzel.ini (alpha ff eklenerek)
f() {
  local c="${1:-}"
  [ -z "$c" ] && return
  c="${c#\#}"
  if [ "${#c}" -eq 6 ]; then
    printf '%s\n' "${c}ff"
  else
    printf '%s\n' "$c"
  fi
}

if [ -f "$FUZZEL_INI" ]; then
  fb=$(f "$bg"); ff=$(f "$fg")
  fsb=$(f "$sbg"); fsf=$(f "$sfg")
  [ -n "$fb" ] && sed -i "s|^background=.*|background=$fb|" "$FUZZEL_INI"
  [ -n "$ff" ] && sed -i "s|^text=.*|text=$ff|" "$FUZZEL_INI"
  [ -n "$fsb" ] && sed -i "s|^match=.*|match=$fsb|" "$FUZZEL_INI"
  [ -n "$fsb" ] && sed -i "s|^selection=.*|selection=$fsb|" "$FUZZEL_INI"
  [ -n "$fsf" ] && sed -i "s|^selection-text=.*|selection-text=$fsf|" "$FUZZEL_INI"
  [ -n "$fsb" ] && sed -i "s|^selection-match=.*|selection-match=$fsb|" "$FUZZEL_INI"
  [ -n "$ff" ] && sed -i "s|^border=.*|border=$ff|" "$FUZZEL_INI"
fi
