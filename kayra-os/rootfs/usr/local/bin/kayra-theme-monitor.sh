#!/usr/bin/env bash
#
# kayra-theme-monitor.sh - Re-apply the Kayra theme when the GTK theme changes.
#
# Watches the GTK4 settings (gsettings and the gtk-4.0 config directory) and
# re-applies the theme when the active theme, color-scheme or accent-color
# changes. Only active when auto_theme is true in settings.conf.
#
# Started by the sway session, guarded by single_instance.
#
# Used libraries: single-instance.sh, i18n.sh, settings-conf.sh.
# Used commands: gsettings, inotifywait, theme-probe.sh, change-theme.sh
#
source /usr/local/lib/kayra/single-instance.sh
single_instance

source /usr/local/lib/kayra/i18n.sh

source /usr/local/lib/kayra/settings-conf.sh

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
  while read -r -t 0.3 _; do :; done   # coalesce rapid successive events
  on_change
done < <(
  gsettings monitor org.gnome.desktop.interface 2>/dev/null \
    | grep --line-buffered -E 'color-scheme|accent-color|gtk-theme' &
  if [ -d "$CFG" ] && command -v inotifywait >/dev/null; then
    inotifywait -m -q -e close_write,moved_to,create,delete,attrib "$CFG" &
  fi
  wait
)
