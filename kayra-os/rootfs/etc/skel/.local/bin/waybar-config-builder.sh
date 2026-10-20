#!/usr/bin/env bash
# waybar-config-builder.sh
# .config/waybar/config.jsonc oluşturur.
# i18n yapılarını (lang/current.sh) kullanır; config.template'den okur.
# Python / harici bağımlılık yok; bash echo / printf / while kullanılır.

set -uo pipefail

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_WAYBAR_CONFIG

CONFIG_DIR="$HOME/.config/waybar"
TEMPLATE="$CONFIG_DIR/config.template"
OUT="$CONFIG_DIR/config.jsonc"

mkdir -p "$CONFIG_DIR"

# Yer tutucu (placeholder) isimleri
PLACEHOLDERS=(
  LOCK_TOOLTIP LOGOUT_TOOLTIP REBOOT_TOOLTIP SHUTDOWN_TOOLTIP
  APP_MENU_TOOLTIP CLIPBOARD_TOOLTIP
  BATTERY_TOOLTIP BATTERY_TOOLTIP_CHARGING
  BATTERY_EVENT_WARNING BATTERY_EVENT_CRITICAL BATTERY_EVENT_FULL
  BATTERY_EVENT_DISCHARGING BATTERY_EVENT_CHARGING
)

# Basit print komutları ile oluştur (while + bash substitution)
{
    # Başlık: i18n mesajlarını kullan
    echo "// Waybar config - built by waybar-config-builder.sh"
    echo ""

    while IFS= read -r line || [[ -n "$line" ]]; do
        for ph in "${PLACEHOLDERS[@]}"; do
            pat="{{${ph}}}"
            # Bash substitution; pattern değişkenle vererek {{}} parse hatası önlenir
            line="${line//$pat/${MSG[$ph]}}"
        done
        printf '%s\n' "$line"
    done < "$TEMPLATE"
} > "$OUT"

echo "Waybar config created: $OUT "
ls -la "$OUT"

if [[ ! -f "$OUT" ]]; then
    echo "Error: $OUT not created" >&2
    exit 1
fi

exit 0

