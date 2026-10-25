#!/usr/bin/env bash
# tema-izle.sh: aktif GTK4 temasının bg/fg renklerini ve açık/koyu durumunu verir.
#   ./tema-izle.sh --once   tek seferlik JSON yazdırır
#   ./tema-izle.sh          tema değişince JSON yazdırmaya devam eder
# Çıktı: {"theme":"...","dark":true,"bg":"#...","fg":"#..."}
source "$HOME/.local/bin/single-instance.sh"
single_instance

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_WIFI_MONITOR

source "$HOME/.local/bin/settings-conf.sh"

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-4.0"

on_change() {
  auto_theme=$(conf_get auto_theme)
  if [ $auto_theme = true ]; then
    theme_colors=$($HOME/.local/bin/theme-probe.sh) # format {"bg":"#fafafa","fg":"#3d3d3d","selected_bg":"#4b8501","selected_fg":"#ffffff"}
    $HOME/.local/bin/change-theme.sh "$theme_colors"
  fi
}

trap 'kill 0' EXIT

while read -r _; do
  while read -r -t 0.3 _; do :; done   # art arda gelen olayları birleştir
  on_change
done < <(
  gsettings monitor org.gnome.desktop.interface 2>/dev/null \
    | grep --line-buffered -E 'color-scheme|accent-color|gtk-theme' &
  if [ -d "$CFG" ] && command -v inotifywait >/dev/null; then
    inotifywait -m -q -e close_write,moved_to,create,delete,attrib "$CFG" &
  fi
  wait
)
