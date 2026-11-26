#!/bin/bash
#
# kayra-autostart.sh - manage user startup commands for the Sway session.
#
# Commands are stored one per line in ~/.config/kayra/autostart.list.
# Lines starting with "#" are comments. Lines starting with "off:" are kept in
# the list but skipped at startup. The line order is the startup order.
#
# "run" starts the enabled commands as the logged-in user. Each command is
# started in its own session with setsid and does not block the next one. The
# output of the commands goes to ~/.local/var/log/kayra-autostart.log, which is
# truncated on every "run" call.
#
# Usage:
#   kayra-autostart.sh run      # start the enabled commands (called by sway)
#   kayra-autostart.sh menu     # fuzzel management menu
#   kayra-autostart.sh add      # add a command
#   kayra-autostart.sh remove   # remove a command
#   kayra-autostart.sh toggle   # enable or disable a command
#   kayra-autostart.sh edit     # open the list with xdg-open
#   kayra-autostart.sh list     # print the list
#
# Used commands: setsid, bash, fuzzel, pkill, awk, printf, mktemp, mv, cat,
#                mkdir, basename, dirname, xdg-open
#
set -uo pipefail
export LC_ALL=C.UTF-8

STATE="$HOME/.config/kayra/autostart.list"
LOG="$HOME/.local/var/log/kayra-autostart.log"

source /usr/local/lib/kayra/klog.sh
source /usr/local/lib/kayra/i18n.sh
source /usr/local/lib/kayra/notify.sh
declare -n MSG=i18n_AUTOSTART
declare -n MENU=autostart_menu

# Removes leading and trailing whitespace from the given string.
trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# Creates the state file with a short header when it does not exist.
ensure_state_file() {
    [ -f "$STATE" ] && return 0
    mkdir -p "$(dirname "$STATE")" || return 1
    cat > "$STATE" <<'EOF'
# Kayra OS startup commands for the Sway session.
# One command per line. Lines starting with "#" are comments.
# Prefix a command with "off:" to keep it in the list but skip it at startup.
EOF
}

# Prints the icon and label lines of the commands in the state file.
# Arguments: active_icon disabled_icon
build_command_lines() {
    local active_icon="$1" disabled_icon="$2" line icon
    while IFS= read -r line || [ -n "$line" ]; do
        line=$(trim "$line")
        [ -z "$line" ] && continue
        case "$line" in
            \#*) continue ;;
            off:*) icon="$disabled_icon" ;;
            *) icon="$active_icon" ;;
        esac
        printf '%b %s\n' "\U000$icon" "$line"
    done < "$STATE"
}

# Fetches a command from the user with a fuzzel prompt.
# Prints the trimmed command; prints nothing when the prompt is cancelled.
ask_command() {
    local prompt="$1" cmd
    pkill -x fuzzel 2>/dev/null || true
    cmd=$(fuzzel --dmenu --anchor=top-right --prompt-only="$prompt: " \
        --log-no-syslog --minimal-lines) || true
    trim "$cmd"
}

# Replaces the state file with the output of an awk program.
# Arguments: awk_program target
rewrite_state() {
    local program="$1" target="$2" tmp
    tmp=$(mktemp "${TMPDIR:-/tmp}/kayra-autostart.XXXXXX") || {
        log ERROR "cannot create a temporary file"
        return 1
    }
    if ! KAYRA_TARGET="$target" awk "$program" "$STATE" > "$tmp"; then
        rm -f "$tmp"
        log ERROR "cannot rewrite the startup list"
        return 1
    fi
    if ! mv "$tmp" "$STATE"; then
        rm -f "$tmp"
        log ERROR "cannot replace the startup list"
        return 1
    fi
}

# Starts the enabled commands and truncates the log first.
cmd_run() {
    if ! ensure_state_file; then
        log ERROR "cannot create the startup list: $STATE"
        notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_READ_FAILED]}"
        return 1
    fi

    mkdir -p "$(dirname "$LOG")" 2>/dev/null || true
    : > "$LOG" 2>/dev/null || true

    local line count=0
    while IFS= read -r line || [ -n "$line" ]; do
        line=$(trim "$line")
        [ -z "$line" ] && continue
        case "$line" in
            \#*|off:*) continue ;;
        esac
        log INFO "Starting startup command: $line"
        if ! setsid -f bash -c "$line" < /dev/null >> "$LOG" 2>&1; then
            log ERROR "Failed to start startup command: $line"
            continue
        fi
        count=$((count + 1))
    done < "$STATE"

    log INFO "Started $count startup command(s)"
    return 0
}

# Fuzzel management menu.
cmd_menu() {
    if ! ensure_state_file; then
        log ERROR "cannot create the startup list: $STATE"
        notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_READ_FAILED]}"
        return 1
    fi

    local -a LINES=(
        "$(printf '%b' "\U000E145") ${MENU[ADD]}"
        "$(printf '%b' "\U000E15B") ${MENU[REMOVE]}"
        "$(printf '%b' "\U000E9F6") ${MENU[TOGGLE]}"
        "$(printf '%b' "\U000E3C9") ${MENU[EDIT]}"
        "$(printf '%b' "\U000E037") ${MENU[RUN]}"
    )

    pkill -x fuzzel 2>/dev/null || true

    local max_width selected
    max_width=$(printf '%s\n' "${LINES[@]}" | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')

    selected=$(printf '%s\n' "${LINES[@]}" | fuzzel --dmenu --anchor=top-right \
        --log-no-syslog --minimal-lines --lines="${#LINES[@]}" \
        --width="$max_width" --hide-prompt) || true

    [ -z "$selected" ] && return 0

    case "${selected#* }" in
        "${MENU[ADD]}")    cmd_add ;;
        "${MENU[REMOVE]}") cmd_remove ;;
        "${MENU[TOGGLE]}") cmd_toggle ;;
        "${MENU[EDIT]}")   cmd_edit ;;
        "${MENU[RUN]}")    cmd_run ;;
    esac
}

# Adds a command to the list.
cmd_add() {
    if ! ensure_state_file; then
        log ERROR "cannot create the startup list: $STATE"
        notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_READ_FAILED]}"
        return 1
    fi

    local cmd
    cmd=$(ask_command "${MSG[PROMPT_ADD]}")
    [ -z "$cmd" ] && return 0

    case "$cmd" in
        \#*|off:*)
            log WARN "Rejected startup command: $cmd"
            notify_warn "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_INVALID]}"
            return 1
            ;;
    esac

    if KAYRA_CMD="$cmd" awk '
        BEGIN { c = ENVIRON["KAYRA_CMD"] }
        {
            line = $0
            sub(/^[ \t]+/, "", line)
            sub(/[ \t]+$/, "", line)
            if (substr(line, 1, 4) == "off:") {
                line = substr(line, 5)
                sub(/^[ \t]+/, "", line)
            }
            if (line == c) found = 1
        }
        END { exit !found }
    ' "$STATE"; then
        notify_info "${MSG[NOTIFY_TITLE]}" \
            "$(i18n_template "${MSG[MSG_ALREADY]}" CMD="$cmd")"
        return 0
    fi

    if ! printf '%s\n' "$cmd" >> "$STATE"; then
        log ERROR "cannot append to the startup list: $STATE"
        notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_READ_FAILED]}"
        return 1
    fi

    log INFO "Startup command added: $cmd"
    notify_ok "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MSG_ADDED]}" CMD="$cmd")"
}

# Removes a command from the list.
cmd_remove() {
    if ! ensure_state_file; then
        log ERROR "cannot create the startup list: $STATE"
        notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_READ_FAILED]}"
        return 1
    fi

    local lines
    lines=$(build_command_lines "E837" "E836")
    if [ -z "$lines" ]; then
        notify_info "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_NO_COMMANDS]}"
        return 0
    fi

    local -a LINES
    mapfile -t LINES <<< "$lines"

    pkill -x fuzzel 2>/dev/null || true

    local max_width selected
    max_width=$(printf '%s\n' "${LINES[@]}" | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')

    selected=$(printf '%s\n' "${LINES[@]}" | fuzzel --dmenu --anchor=top-right \
        --log-no-syslog --minimal-lines --lines="${#LINES[@]}" \
        --width="$max_width" --hide-prompt) || true

    [ -z "$selected" ] && return 0

    local target="${selected#* }"
    [ -z "$target" ] && return 0

    if ! rewrite_state '{
        line = $0
        sub(/^[ \t]+/, "", line)
        sub(/[ \t]+$/, "", line)
        if (line != ENVIRON["KAYRA_TARGET"]) print
    }' "$target"; then
        notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_READ_FAILED]}"
        return 1
    fi

    log INFO "Startup command removed: $target"
    notify_ok "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MSG_REMOVED]}" CMD="$target")"
}

# Enables or disables a command by adding or removing the "off:" prefix.
cmd_toggle() {
    if ! ensure_state_file; then
        log ERROR "cannot create the startup list: $STATE"
        notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_READ_FAILED]}"
        return 1
    fi

    local lines
    lines=$(build_command_lines "E837" "E836")
    if [ -z "$lines" ]; then
        notify_info "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_NO_COMMANDS]}"
        return 0
    fi

    local -a LINES
    mapfile -t LINES <<< "$lines"

    pkill -x fuzzel 2>/dev/null || true

    local max_width selected
    max_width=$(printf '%s\n' "${LINES[@]}" | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')

    selected=$(printf '%s\n' "${LINES[@]}" | fuzzel --dmenu --anchor=top-right \
        --log-no-syslog --minimal-lines --lines="${#LINES[@]}" \
        --width="$max_width" --hide-prompt) || true

    [ -z "$selected" ] && return 0

    local target="${selected#* }"
    [ -z "$target" ] && return 0

    local display="$target" state
    case "$target" in
        off:*)
            display="${target#off:}"
            display=$(trim "$display")
            state="${MSG[STATE_ON]}"
            ;;
        *)
            state="${MSG[STATE_OFF]}"
            ;;
    esac

    if ! rewrite_state '{
        line = $0
        sub(/^[ \t]+/, "", line)
        sub(/[ \t]+$/, "", line)
        if (line == ENVIRON["KAYRA_TARGET"]) {
            if (substr(line, 1, 4) == "off:") {
                s = substr(line, 5)
                sub(/^[ \t]+/, "", s)
                print s
            } else {
                print "off:" line
            }
            next
        }
        print
    }' "$target"; then
        notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_READ_FAILED]}"
        return 1
    fi

    log INFO "Startup command toggled: $target -> $state"
    notify_ok "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MSG_TOGGLED]}" CMD="$display" STATE="$state")"
}

# Opens the list with the user's default text editor.
cmd_edit() {
    if ! ensure_state_file; then
        log ERROR "cannot create the startup list: $STATE"
        notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_READ_FAILED]}"
        return 1
    fi

    if ! command -v xdg-open >/dev/null 2>&1; then
        log ERROR "xdg-open is not installed"
        notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_EDIT_FAILED]}"
        return 1
    fi

    if xdg-open "$STATE" >/dev/null 2>&1; then
        log INFO "Opened the startup list: $STATE"
        notify_info "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_EDIT_OPENED]}"
    else
        log ERROR "Failed to open the startup list: $STATE"
        notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_EDIT_FAILED]}"
        return 1
    fi
}

# Prints the raw state file.
cmd_list() {
    ensure_state_file || return 1
    cat "$STATE"
}

case "${1:-}" in
    run)    cmd_run ;;
    menu)   cmd_menu ;;
    add)    cmd_add ;;
    remove) cmd_remove ;;
    toggle) cmd_toggle ;;
    edit)   cmd_edit ;;
    list)   cmd_list ;;
    *)
        printf 'Usage: %s {run|menu|add|remove|toggle|edit|list}\n' "$(basename "$0")" >&2
        exit 2
        ;;
esac
