#!/bin/bash

DATA_FILE="$1"
shift # İlk parametreyi (JSON dosyası) tüket, kalan tüm parametreleri ($@) fuzzel'a aktar

# 1. Parametre kontrolü
if [ -z "$HOME/.local/var/lib/waybar/$DATA_FILE" ]; then
    echo "Kullanım: $0 $HOME/.local/var/lib/waybar/<json-dosya> [fuzzel parametreleri...]" >&2
    exit 1
fi

# 2. Dosya kontrolü
if [ ! -f "$HOME/.local/var/lib/waybar/$DATA_FILE" ]; then
    echo "Hata: Dosya bulunamadı -> $HOME/.local/var/lib/waybar/$DATA_FILE" >&2
    exit 1
fi

# 3. Var olan Fuzzel süreçlerini kapat
pkill -x fuzzel 2>/dev/null

# 4. Seçimi al (varsayılan parametrelere ek olarak eklenen "$@" aktarılır)
SELECTED_KEY=$(jq -r 'keys[]' "$HOME/.local/var/lib/waybar/$DATA_FILE" | fuzzel --dmenu --log-no-syslog "$@" --prompt="Eylem: ")

[ -z "$SELECTED_KEY" ] && exit 0

# 5. Komutu çalıştır
COMMAND=$HOME/.local/bin/$(jq -r --arg key "$SELECTED_KEY" '.[$key]' "$HOME/.local/var/lib/waybar/$DATA_FILE")

if [ -n "$COMMAND" ] && [ "$COMMAND" != "null" ]; then
    eval "$COMMAND" &
fi
