#!/bin/bash
#
# settings-conf.sh - Kayra OS settings file helper (source it; do not execute).
#
# Reads/writes the key=value settings in ~/.config/kayra/settings.conf.
#
# Usage in a script:
#   source "$(dirname "$0")/settings-conf.sh"
#   conf_get  key            # prints the value (without quotes)
#   conf_set  key "value"    # rewrites the key line as key="value"
#   conf_wait_change [secs]  # blocks until settings.conf changes or timeout
#
# Note: conf_set needs the file to already exist; create it first.

# Path of the settings file
CONFIG_FILE="${HOME}/.config/kayra/settings.conf"

# Prints the value of the given key
conf_get() {
    local key="$1"
    if [ -f "$CONFIG_FILE" ]; then
        grep "^${key}=" "$CONFIG_FILE" | cut -d'=' -f2- | sed 's/^"//;s/"$//'
    fi
}

# Updates the value of the given key
conf_set() {
    local key="$1"
    local value="$2"
    if [ -f "$CONFIG_FILE" ]; then
        sed -i "s/^${key}=.*/${key}=\"${value}\"/" "$CONFIG_FILE"
    fi
}

# Blocks until the settings file changes, or until <seconds> pass.
# Returns 0 when the file changed, 1 on timeout (and when inotifywait is
# missing, where it simply sleeps). The directory is watched, not the file,
# because editors (sed -i) replace the file with a rename. Monitor mode is used
# so that a quick "create temp file, rename over" sequence is not missed.
#
# Typical use, to react to changes without busy waiting:
#   while :; do
#       value=$(conf_get key)
#       ... do something ...
#       conf_wait_change 5 || true
#   done
conf_wait_change() {
    local timeout="${1:-5}"
    local dir base line remaining deadline rc=1

    dir="$(dirname "$CONFIG_FILE")"
    base="$(basename "$CONFIG_FILE")"

    command -v inotifywait >/dev/null 2>&1 || { sleep "$timeout"; return 1; }

    coproc CONF_WATCH {
        exec inotifywait -m -q -e close_write,create,moved_to,moved_from \
            --format '%f' "$dir" 2>/dev/null
    }
    local fd="${CONF_WATCH[0]}" wpid="$CONF_WATCH_PID"

    deadline=$(( $(date +%s) + timeout ))
    while :; do
        remaining=$(( deadline - $(date +%s) ))
        (( remaining <= 0 )) && break
        if IFS= read -r -t "$remaining" line <&"$fd"; then
            [[ "$line" == "$base" ]] && { rc=0; break; }
        else
            break
        fi
    done

    kill "$wpid" 2>/dev/null
    wait "$wpid" 2>/dev/null
    return "$rc"
}
