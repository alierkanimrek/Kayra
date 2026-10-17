#!/bin/bash
# change-wallpaper.sh
# gjs görsel seçici çalıştırır; seçim yapılırsa kopyalar + sway config günceller

SELECTED=$(gjs -m "$HOME/.local/bin/image-picker.gjs" 2>/dev/null)

# Boş veya sadece uyarı satırları varsa çık
[ -z "$SELECTED" ] && exit 0

# Tam yol al (satır başı/sonu boşlukları temizle)
FILE_PATH=$(echo "$SELECTED" | head -n1 | tr -d '\r\n')

# Dosya var mı kontrol et
[ -f "$FILE_PATH" ] || exit 1

TARGET_DIR="$HOME/.local/share/backgrounds"
mkdir -p "$TARGET_DIR"

# Orijinal uzantıyı koruyarak sabit adla kopyala
EXT="${FILE_PATH##*.}"
TARGET_FILE="$TARGET_DIR/kayra_desktop.$EXT"
cp "$FILE_PATH" "$TARGET_FILE"

# Sway config dosyasını güncelle
CONFIG="$HOME/.config/sway/background.conf"
if [ -f "$CONFIG" ]; then
    echo "exec_always swaybg -i \"$TARGET_FILE\" -m fill" > "$CONFIG"
    swaybg -i "$TARGET_FILE" -m fill
fi
