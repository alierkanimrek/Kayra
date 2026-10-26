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
