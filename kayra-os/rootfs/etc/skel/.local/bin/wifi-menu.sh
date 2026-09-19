#!/usr/bin/env bash
#
# wifi-menu.sh — "custom/wifi" modülü tıklama davranışı.
#
# fuzzel --dmenu ile bağlanılabilir ağların listesini sunar:
#   <sinyal-simgesi> <kilit-varsa> <✓ bağlıysa> SSID
# Seçilen ağ:
#   - zaten bağlı olunan ağsa -> bağlantı kesilir.
#   - şifreli bir ağsa -> fuzzel --password ile şifre sorulur ve bağlanılır
#     (fuzzel, girilen karakterleri maskeler; wofi'de bu özellik yok,
#     bu yüzden şifre girişi için fuzzel tercih edildi).
#   - açık bir ağsa -> doğrudan bağlanılır.
#
# Bağımlılıklar: nmcli (NetworkManager), fuzzel, jq (kilit tespiti için
# gerekmese de tutarlılık açısından kullanılabilir; burada saf bash/awk
# yeterli olduğundan jq zorunlu değildir).

set -uo pipefail

# nmcli çıktısının yerelleştirilmiş (Türkçe vb.) kelimelerle gelmesini önler;
# awk/cut ile yapılan sabit-metin karşılaştırmaları (STATE, SECURITY, "--" vb.)
# bu sayede locale bağımsız çalışır.

ICON_L1=$(printf '%b' '\U0000EBE4')
ICON_L2=$(printf '%b' '\U0000EBD6')
ICON_L3=$(printf '%b' '\U0000EBE1')
ICON_L4=$(printf '%b' '\U0000E1D8')
LOCK="🔒"
CHECK="✓"

notify() {
    command -v notify-send >/dev/null 2>&1 && notify-send -a "Wifi" "$1" "${2:-}"
}

iface=$(LC_ALL=C nmcli -t -f DEVICE,TYPE device status | awk -F: '$2=="wifi"{print $1; exit}')
if [[ -z "$iface" ]]; then
    notify "Wifi" "Wifi aygıtı bulunamadı"
    exit 1
fi

active_ssid=$(LC_ALL=C nmcli -t -f IN-USE,SSID device wifi list ifname "$iface" \
    | awk -F: '$1=="*"{print $2; exit}')

# Taze bir tarama iste (başarısız olursa önbellekteki liste kullanılır)
LC_ALL=C nmcli device wifi rescan ifname "$iface" >/dev/null 2>&1
sleep 1

# SSID:GÜVENLİK:SİNYAL satırlarını al, sinyale göre sırala, SSID'ye göre tekilleştir
mapfile -t networks < <(
    LC_ALL=C nmcli -t -f SSID,SECURITY,SIGNAL device wifi list ifname "$iface" 2>/dev/null \
        | awk -F: '$1!=""' \
        | sort -t: -k3,3 -nr \
        | awk -F: '!seen[$1]++'
)

if [[ ${#networks[@]} -eq 0 ]]; then
    notify "Wifi" "Yakında ağ bulunamadı"
    exit 1
fi

declare -A menu_map
menu_lines=()

for entry in "${networks[@]}"; do
    ssid="${entry%%:*}"
    rest="${entry#*:}"
    security="${rest%%:*}"
    signal="${rest#*:}"
    [[ "$signal" =~ ^[0-9]+$ ]] || signal=0

    if   (( signal >= 80 )); then icon="$ICON_L4"
    elif (( signal >= 55 )); then icon="$ICON_L3"
    elif (( signal >= 30 )); then icon="$ICON_L2"
    else                          icon="$ICON_L1"
    fi

    lock=""
    [[ -n "$security" && "$security" != "--" ]] && lock="$LOCK "

    mark=""
    [[ "$ssid" == "$active_ssid" ]] && mark="$CHECK "

    label="${icon}  ${lock}${mark}${ssid}"
    menu_lines+=("$label")
    menu_map["$label"]="${ssid}:::${security}"
done

selection=$(printf '%s\n' "${menu_lines[@]}" \
    | fuzzel --dmenu --anchor=top-right --log-no-syslog --placeholder="Wifi ağı seç" --lines=10 --prompt="wifi> ")
[[ -z "$selection" ]] && exit 0

chosen="${menu_map[$selection]:-}"
[[ -z "$chosen" ]] && exit 0

ssid="${chosen%%:::*}"
security="${chosen#*:::}"

# Seçilen ağ zaten bağlı olunan ağsa: bağlantıyı kes
if [[ "$ssid" == "$active_ssid" ]]; then
    if LC_ALL=C nmcli device disconnect "$iface" >/dev/null 2>&1; then
        notify "Wifi" "Bağlantı kesildi" "$ssid"
    else
        notify "Wifi" "Bağlantı kesilemedi" "$ssid"
    fi
    exit 0
fi

# Şifreli ağ: fuzzel --password ile maskeli şifre girişi al
if [[ -n "$security" && "$security" != "--" ]]; then
    password=$(fuzzel --dmenu --password --anchor=top-right --log-no-syslog --placeholder="Şifre: ${ssid}" --prompt="şifre> " < /dev/null)
    [[ -z "$password" ]] && exit 0

    if LC_ALL=C nmcli device wifi connect "$ssid" password "$password" ifname "$iface" >/dev/null 2>&1; then
        notify "Wifi" "Bağlandı" "$ssid"
    else
        notify "Wifi" "Bağlantı başarısız (şifre yanlış olabilir)" "$ssid"
    fi
else
    if LC_ALL=C nmcli device wifi connect "$ssid" ifname "$iface" >/dev/null 2>&1; then
        notify "Wifi" "Bağlandı" "$ssid"
    else
        notify "Wifi" "Bağlantı başarısız" "$ssid"
    fi
fi
