#!/usr/bin/env bash
#
# wifi-monitor.sh — Waybar "custom/wifi" modülü için durum üreticisi.
#
# Görev:
#   - Sistemde wifi aygıtı yoksa boş/gizli çıktı verir (exec-if zaten
#     modülü başlangıçta gizler, burada da hotplug durumu için aynı
#     davranış tekrarlanır).
#   - Wifi aygıtı var ama bağlı değilse: uyarı simgesi + "disconnected" sınıfı.
#   - Bağlıysa: sinyal gücüne göre 4 seviyeli simge + "connected" sınıfı,
#     tooltip'te aygıt adı, SSID, IP adresi ve sinyal gücü.
#
# İzleme:
#   `ip monitor link addr` ile arayüz/adres değişiklikleri anlık yakalanır
#   (bağlantı kurma/kesme, IP alma vb. bu olayları tetikler). Sinyal gücü
#   değişimi her zaman bu olayları tetiklemediğinden, ayrıca 15 saniyede
#   bir periyodik tazeleme yapılır.
#
# Bağımlılıklar: nmcli (NetworkManager), jq, iproute2 (ip monitor).

set -uo pipefail

# nmcli çıktısının yerelleştirilmiş (Türkçe vb.) kelimelerle gelmesini önler;
# awk/cut ile yapılan sabit-metin karşılaştırmaları (STATE, SECURITY, "--" vb.)
# bu sayede locale bağımsız çalışır.


ICON_WARN=$(printf '%b' '\U0000E1DA')   # bağlı değil / uyarı
ICON_L1=$(printf '%b' '\U0000EBE4')     # sinyal seviye 1 (zayıf)
ICON_L2=$(printf '%b' '\U0000EBD6')     # sinyal seviye 2
ICON_L3=$(printf '%b' '\U0000EBE1')     # sinyal seviye 3
ICON_L4=$(printf '%b' '\U0000E1D8')     # sinyal seviye 4 (güçlü)

get_wifi_iface() {
    LC_ALL=C nmcli -t -f DEVICE,TYPE device status 2>/dev/null \
        | awk -F: '$2=="wifi"{print $1; exit}'
}

emit() {
    local iface="$1"

    if [[ -z "$iface" ]]; then
        # Wifi aygıtı yok -> modülü gizle (boş metin, boşluk kaplamasın diye)
        jq -nc '{"text":"", "tooltip":"", "class":"hidden"}'
        return
    fi

    local state
    state=$(LC_ALL=C nmcli -t -f DEVICE,STATE device status 2>/dev/null \
        | awk -F: -v i="$iface" '$1==i{print $2}')

    if [[ "$state" != "connected" ]]; then
        jq -nc --arg icon "$ICON_WARN" --arg dev "$iface" \
            '{"text": $icon,
              "tooltip": ("Aygıt: " + $dev + "\nDurum: Bağlı değil"),
              "class": "disconnected"}'
        return
    fi

    local line ssid signal ip4
    line=$(LC_ALL=C nmcli -t -f IN-USE,SSID,SIGNAL device wifi list ifname "$iface" 2>/dev/null \
        | awk -F: '$1=="*"{print; exit}')
    ssid=$(printf '%s' "$line" | cut -d: -f2)
    signal=$(printf '%s' "$line" | cut -d: -f3)
    [[ "$signal" =~ ^[0-9]+$ ]] || signal=0

    ip4=$(LC_ALL=C nmcli -t -f IP4.ADDRESS device show "$iface" 2>/dev/null \
        | head -n1 | cut -d: -f2 | cut -d/ -f1)
    [[ -z "$ip4" ]] && ip4="-"
    [[ -z "$ssid" ]] && ssid="-"

    local icon
    if   (( signal >= 80 )); then icon="$ICON_L4"
    elif (( signal >= 55 )); then icon="$ICON_L3"
    elif (( signal >= 30 )); then icon="$ICON_L2"
    else                          icon="$ICON_L1"
    fi

    jq -nc --arg icon "$icon" --arg dev "$iface" --arg ssid "$ssid" \
        --arg ip "$ip4" --arg sig "$signal" \
        '{"text": $icon,
          "tooltip": ("Aygıt: " + $dev + "\nSSID: " + $ssid + "\nIP: " + $ip + "\nSinyal: %" + $sig),
          "class": "connected"}'
}

# İlk durumu hemen bildir
iface=$(get_wifi_iface)
emit "$iface"

# `ip monitor` ile arayüz/adres değişikliklerini izle; her olayda durumu yenile
(
    ip monitor link addr 2>/dev/null | while read -r _; do
        iface=$(get_wifi_iface)
        emit "$iface"
    done
) &
IP_MON_PID=$!

cleanup() {
    kill "$IP_MON_PID" 2>/dev/null
}
trap cleanup EXIT INT TERM

# Sinyal gücü değişimi `ip monitor` olayı üretmeyebileceğinden periyodik tazeleme
while true; do
    sleep 15
    iface=$(get_wifi_iface)
    emit "$iface"
done
