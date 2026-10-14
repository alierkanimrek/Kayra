#!/bin/bash
# Auto theme toggle script - reads and toggles auto_theme in settings.conf

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_TOGGLE_AUTO_THEME

source "$HOME/.local/bin/settings-conf.sh"

CURRENT=$(conf_get auto_theme)

if [ "$CURRENT" = "true" ]; then
    NEW="false"
    BODY="${MSG[MSG_OFF]}"
else
    NEW="true"
    BODY="${MSG[MSG_ON]}"
fi

conf_set auto_theme "$NEW"
notify-send -a "Kayra" "${MSG[NOTIFY_TITLE]}" "$BODY"

# Update current value for theme-monitor if needed
# (conf_set writes to file; theme-monitor reads file on trigger)
exit 0
