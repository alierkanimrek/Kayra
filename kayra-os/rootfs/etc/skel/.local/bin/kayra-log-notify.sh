#!/bin/bash
#
# kayra-log-monitor.sh - Watches ~/.local/var/log/kayra.log with inotifywait
# and shows a desktop notification whenever a new ERROR record appears.
#
# * The notification has two actions:
#     - "Open Log File"  : opens the log file in the text editor
#     - "Disable"        : sets kayra_error_log_notify="false" in settings.conf
# * Notifications are skipped while kayra_error_log_notify is not "true"
#   in ~/.config/kayra/settings.conf
#
source "$HOME/.local/bin/single-instance.sh"
single_instance
export LC_ALL=C

KLOG_SCRIPT="$(basename "$0")"
source "$HOME/.local/bin/klog.sh"
source "$HOME/.local/bin/settings-conf.sh"
source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_KAYRA_LOG_MONITOR

LOGFILE="$HOME/.local/var/log/kayra.log"
SETTINGS_FILE="$HOME/.config/kayra/settings.conf"
CONFIG_KEY="kayra_error_log_notify"
EDITOR_BIN="mousepad"

# Extracts the script name and the message from a log line.
# Log line format: "<date> [<script>] [<LEVEL>] <message>"
# The date and the [LEVEL] tag are dropped from the notification body.
parse_log_line() {
    local line="$1"
    local rest="$line"

    # Drop the leading timestamp (date and time fields).
    rest=$(printf '%s\n' "$rest" | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}[ T][0-9]{2}:[0-9]{2}:[0-9]{2}[[:space:]]*//')
    rest=$(printf '%s\n' "$rest" | sed -E 's/^[0-9]{2}\/[0-9]{2}\/[0-9]{4}[[:space:]]+[0-9]{2}:[0-9]{2}:[0-9]{2}[[:space:]]*//')

    # Tags: the first one is the script name, the second one is the level.
    # The message is everything after the level tag.
    local parsed
    parsed=$(printf '%s\n' "$rest" | awk '{
        script = ""; level = ""; message = "";
        if (match($0, /\[([^][]*)\]/)) {
            script = substr($0, RSTART + 1, RLENGTH - 2);
            head = substr($0, 1, RSTART + RLENGTH);
            tail = substr($0, RSTART + RLENGTH);
            if (match(tail, /\[([^][]*)\]/)) {
                level = substr(tail, RSTART + 1, RLENGTH - 2);
                message = substr(tail, RSTART + RLENGTH);
                sub(/^[[:space:]]+/, "", message);
            } else {
                message = tail;
                sub(/^[[:space:]]+/, "", message);
            }
        } else {
            message = $0;
        }
        printf "%s\x1f%s\n", script, message;
    }')

    LOG_SCRIPT_NAME="${parsed%%$'\x1f'*}"
    LOG_MESSAGE="${parsed#*$'\x1f'}"
}

notify_enabled() {
    local value
    value=$(conf_get "$CONFIG_KEY")
    [ "$value" = "true" ]
}

# Writes CONFIG_KEY=false into the settings file (creating it if needed).
disable_notifications() {
    mkdir -p "$(dirname "$SETTINGS_FILE")"
    if [ ! -f "$SETTINGS_FILE" ]; then
        printf '%s="false"\n' "$CONFIG_KEY" >"$SETTINGS_FILE"
        return 0
    fi
    if grep -q "^${CONFIG_KEY}=" "$SETTINGS_FILE"; then
        sed -i "s/^${CONFIG_KEY}=.*/${CONFIG_KEY}=\"false\"/" "$SETTINGS_FILE"
    else
        printf '%s="false"\n' "$CONFIG_KEY" >>"$SETTINGS_FILE"
    fi
}

# Sends the notification and handles the user action in the background,
# so that the monitoring loop is never blocked by the notification.
show_notification() {
    local title="$1"
    local body="$2"
    (
        ACTION=$(notify-send -w -u critical -a "${MSG[NOTIFY_APP]}" \
            -A "open_log=${MSG[BUTTON_OPEN_LOG]}" \
            -A "disable=${MSG[BUTTON_DISABLE]}" \
            "$title" "$body")
        case "$ACTION" in
            open_log)
                "$EDITOR_BIN" "$LOGFILE" >/dev/null 2>&1 &
                ;;
            disable)
                disable_notifications
                log INFO "Error log notifications disabled by user action"
                ;;
        esac
    ) &
}

mkdir -p "$(dirname "$LOGFILE")"
touch "$LOGFILE"

log INFO "Starting log monitor for $LOGFILE"

LAST_LINES=$(wc -l <"$LOGFILE" 2>/dev/null || echo 0)

while true; do
    # Wait for a modification of the log file.
    inotifywait -q -e modify,close_write,move_self "$LOGFILE" >/dev/null 2>&1 || continue

    CURRENT_LINES=$(wc -l <"$LOGFILE" 2>/dev/null || echo 0)

    # Truncation or rotation: start over from the beginning.
    if [ "$CURRENT_LINES" -lt "$LAST_LINES" ]; then
        LAST_LINES=0
    fi

    if [ "$CURRENT_LINES" -gt "$LAST_LINES" ]; then
        NEW_LINES=$(tail -n "+$((LAST_LINES + 1))" "$LOGFILE")
        LAST_LINES="$CURRENT_LINES"

        while IFS= read -r line; do
            [ -z "$line" ] && continue
            case "$line" in
                *\[ERROR\]*|*\[WARN\]*)
                    if notify_enabled; then
                        parse_log_line "$line"
                        show_notification "${MSG[NOTIFY_TITLE]}" "[${LOG_SCRIPT_NAME}] ${LOG_MESSAGE}"
                    fi
                    ;;
            esac
        done <<<"$NEW_LINES"
    fi
done
