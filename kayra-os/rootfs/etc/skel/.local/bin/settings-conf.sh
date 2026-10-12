#!/bin/bash

# Kayra ayar dosyasının yolu
CONFIG_FILE="${HOME}/.config/kayra/settings.conf"

# Belirtilen anahtarın değerini okur
conf_get() {
    local key="$1"
    if [ -f "$CONFIG_FILE" ]; then
        grep "^${key}=" "$CONFIG_FILE" | cut -d'=' -f2- | sed 's/^"//;s/"$//'
    fi
}

# Belirtilen anahtarın değerini değiştirir (sed ile günceller)
conf_set() {
    local key="$1"
    local value="$2"
    if [ -f "$CONFIG_FILE" ]; then
        sed -i "s/^${key}=.*/${key}=\"${value}\"/" "$CONFIG_FILE"
    fi
}
