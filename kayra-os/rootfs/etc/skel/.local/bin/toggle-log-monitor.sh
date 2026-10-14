#!/bin/bash
# Log monitor toggle script - reads and toggles error_log_notify in settings.conf

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_LOG_MONITOR

source "$HOME/.local/bin/settings-conf.sh"

CURRENT=$(conf_get error_log_notify)

if [ "$CURRENT" = "true" ]; then
    NEW="false"
    BODY="${MSG[MSG_OFF]}"
else
    NEW="true"
    BODY="${MSG[MSG_ON]}"
fi

conf_set error_log_notify "$NEW"
notify-send -a "Kayra" "${MSG[NOTIFY_TITLE]}" "$BODY"

exit 0
