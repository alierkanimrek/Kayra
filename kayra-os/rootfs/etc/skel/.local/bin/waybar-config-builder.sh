#!/usr/bin/env bash
# waybar-config-builder.sh
# .config/waybar/config.jsonc oluşturur.
# i18n yapılarını (lang/current.sh) kullanır; config.template'den okur.
# Python / harici bağımlılık yok; bash echo / printf ve template-lib.sh kullanılır.

set -uo pipefail

export LC_ALL=C.UTF-8

source "$(dirname "$0")/klog.sh"

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_WAYBAR_CONFIG

source "$(dirname "$0")/template-lib.sh"

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

if [[ ! -f "$TEMPLATE" ]]; then
    log "ERROR" "Template not found: $TEMPLATE"
    exit 1
fi

# Template metnini oku ve tüm yer tutucuları i18n mesajlarıyla değiştir
template_text="$(<"$TEMPLATE")"

for ph in "${PLACEHOLDERS[@]}"; do
    template_text="$(template_replace "$template_text" "$ph" "${MSG[$ph]}")"
done

# Başlık: i18n mesajlarını kullan
{
    echo "// Waybar config - built by waybar-config-builder.sh"
    echo ""
    printf '%s\n' "$template_text"
} > "$OUT"

log DEBUG "Waybar config created: $OUT "

if [[ ! -f "$OUT" ]]; then
    log "ERROR" "$OUT not created"
    exit 1
fi

exit 0
