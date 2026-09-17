#!/usr/bin/env bash
#
# waybar-netmon.sh
# ------------------------------------------------------------------
# Sway/Waybar için ağ aygıtı izleyici custom modül betiği.
#
# Yaklaşım:
#   - "ip monitor address link" SADECE bir değişiklik olduğunu haber
#     verir (tetikleyici); kendisi hiçbir bilgi ayrıştırmaz.
#   - Her tetiklemede TEK bir "ip -j addr show" çağrısı yapılır. -j
#     ile alınan JSON çıktısı doğrudan jq'ye verilir; jq hem desenlere
#     göre sınıflandırmayı (test() ile regex eşleştirme), hem tooltip
#     ve ikon metnini, hem de waybar'ın beklediği nihai JSON nesnesini
#     üretir. jq zaten JSON ürettiği için metin kaçışı (escape) elle
#     yapılmaz; jq bunu otomatik ve güvenilir şekilde halleder.
#     Böylece ayrı bir awk adımına ihtiyaç kalmaz.
#
# Bağımlılık: jq (Void'de: xbps-install -S jq)
#
# Sadece komut satırından desen (glob) olarak verilen ETHERNET ve
# DİĞER (sanal/docker/veth vb.) arayüzleri işler. Kablosuz (wl*) ve
# geniş bant (ww*, usb* vb.) arayüzler bu betiğe parametre olarak
# verilmediği için otomatik olarak işlem dışı kalır.
#
# Kullanım:
#   waybar-netmon.sh --ethernet "en*" --other "docker*,veth*,br-*,virbr*"
#
# Desenler virgülle ayrılmış birden fazla shell glob içerebilir.
# ------------------------------------------------------------------

set -uo pipefail

ETH_PATTERNS=""
OTHER_PATTERNS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --ethernet|-e)
            ETH_PATTERNS="${2:-}"
            shift 2
            ;;
        --other|-o)
            OTHER_PATTERNS="${2:-}"
            shift 2
            ;;
        *)
            echo "Bilinmeyen parametre: $1" >&2
            exit 1
            ;;
    esac
done

if [[ -z "$ETH_PATTERNS" && -z "$OTHER_PATTERNS" ]]; then
    echo "Kullanım: $0 --ethernet <desen1,desen2,...> --other <desen1,desen2,...>" >&2
    exit 1
fi

# Nerd Font / icon font kod noktaları (U+EB2F, U+F56E)
# Not: locale'den bağımsız çalışması için \u kaçışı değil, doğrudan
# UTF-8 bayt dizisi (\x..) kullanılıyor.
ETH_ICON=$'\xee\xac\xaf'    # U+EB2F
OTHER_ICON=$'\xef\x95\xae'  # U+F56E

# Virgülle ayrılmış glob listesini (örn: "docker*,veth*") çapalı bir
# ERE alternatifine çevirir (örn: "^docker.*$|^veth.*$"). jq'nun
# test() fonksiyonu (Oniguruma) bu sözdizimini desteklediği için bu
# dönüşüm gerekli.
glob_list_to_ere() {
    local list="$1"
    local IFS=','
    local -a arr
    read -r -a arr <<< "$list"
    local ere="" pat rex
    for pat in "${arr[@]}"; do
        [[ -z "$pat" ]] && continue
        rex=$(printf '%s' "$pat" | sed -e 's/[.[\^$(){}|+]/\\&/g' -e 's/\*/.*/g' -e 's/\?/./g')
        if [[ -n "$ere" ]]; then
            ere+="|"
        fi
        ere+="^${rex}\$"
    done
    printf '%s' "$ere"
}

ETH_ERE=$(glob_list_to_ere "$ETH_PATTERNS")
OTHER_ERE=$(glob_list_to_ere "$OTHER_PATTERNS")

# Tek bir "ip -j addr show | jq" çağrısıyla durumu hesapla ve
# waybar'ın beklediği JSON satırını doğrudan jq'den bas
emit_state() {
    ip -j addr show 2>/dev/null | jq -c \
        --arg eth_re "$ETH_ERE" \
        --arg other_re "$OTHER_ERE" \
        --arg eth_icon "$ETH_ICON" \
        --arg other_icon "$OTHER_ICON" '
        def classify(name):
            if ($eth_re != "" and (name | test($eth_re))) then "eth"
            elif ($other_re != "" and (name | test($other_re))) then "other"
            else null end;

        [ .[] | {
            name: .ifname,
            ip: ((.addr_info // []) | map(select(.family == "inet")) | (.[0].local // "")),
            cls: classify(.ifname)
          } ]
        | map(select(.cls != null))
        | (map(select(.cls == "eth")))   as $eth
        | (map(select(.cls == "other"))) as $other
        | ($eth   | any(.ip != ""))      as $has_eth
        | ($other | any(.ip != ""))      as $has_other
        | ($eth   | map(if .ip != "" then "\(.name) : \(.ip)" else .name end)) as $eth_lines
        | ($other | map(if .ip != "" then "\(.name) : \(.ip)" else .name end)) as $other_lines
        | ([ (if $has_eth   then $eth_icon   else empty end),
             (if $has_other then $other_icon else empty end) ] | join(" ")) as $text
        | ([ (if ($eth_lines   | length) > 0 then "Ethernet:\n" + ($eth_lines   | join("\n")) else empty end),
             (if ($other_lines | length) > 0 then "Diğer:\n"    + ($other_lines | join("\n")) else empty end) ]
           | join("\n\n")) as $tooltip
        | { text: $text,
            tooltip: $tooltip,
            class: (if $text == "" then "disconnected" else "connected" end),
            alt:   (if $text == "" then "disconnected" else "connected" end) }
        '
}

# Başlangıçta bir kez mevcut durumu bildir
emit_state

# "ip monitor" ile kalıcı izleme: sadece TETİKLEYİCİ olarak kullanılır,
# içerik ayrıştırması yapılmaz. Her olayda emit_state yeniden çağrılır.
ip monitor address link 2>/dev/null | while read -r _; do
    # Art arda gelen olay patlamalarını (burst) sönümle
    sleep 0.3
    while read -r -t 0.1 _; do :; done
    emit_state
done
