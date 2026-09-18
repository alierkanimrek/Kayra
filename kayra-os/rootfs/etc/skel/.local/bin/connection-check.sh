#!/usr/bin/env bash
#
# custom/wifi-warning için Waybar modül scripti (olay tabanlı / "ip monitor")
# ---------------------------------------------------------------------------
# Mantık:
#   - "nmcli networking connectivity check" çıktısı "full" İSE  -> ikon YOK
#   - Sistemde bir Wi-Fi aygıtı VARSA (bağlı olmasa da yeterli) -> ikon YOK
#   - Bunların HİÇBİRİ doğru değilse (bağlantı "full" değil VE
#     Wi-Fi aygıtı da yoksa)                                    -> uyarı ikonu
#
# Periyodik (interval) kontrol YOK: script açılışta bir kez durumu bildirir,
# sonra "ip monitor" ile arayüz (link) / adres (address) / rota (route)
# olaylarını dinler ve SADECE bir değişiklik olduğunda yeniden kontrol eder.
# Waybar bu scripti sürekli (interval'siz) çalıştırır; her satır yeni bir
# JSON durumu olarak okunur.
#
# NOT: Mesajındaki ikon kodu ("\ufffb7") bozuk/geçersiz bir Unicode kod
# noktası olduğu için kullanılamadı. Yerine theme.css'te zaten kullandığın
# "Material Symbols Outlined" fontundan "wifi_off" ikonunu (\ue648) koydum.
# Farklı bir ikon istersen aşağıdaki satırı kendi kod noktanla değiştir.
ICON_WARNING=$(printf '%b' '\U000FFFB7')

check_and_report() {
    local connectivity has_wifi_device

    connectivity="$(nmcli networking connectivity check 2>/dev/null)"

    has_wifi_device="false"
    if nmcli -t -f TYPE device status 2>/dev/null | grep -qx "wifi"; then
        has_wifi_device="true"
    fi

    if [[ "$connectivity" == "full" || "$has_wifi_device" == "true" ]]; then
        # Her şey normal: hiçbir simge gösterilmesin
        printf '{"text": "", "class": "hidden"}\n'
    else
        # İnternet "full" değil VE hiç Wi-Fi aygıtı yok -> uyar
        printf '{"text": "%s", "class": "warning", "tooltip": "Wi-Fi aygıtı bulunamadı ve internet bağlantısı yok (connectivity: %s)\\nTıkla: Ağ Yöneticisini aç"}\n' \
            "$ICON_WARNING" "$connectivity"
    fi
}

# Başlangıçta mevcut durumu bir kez bildir
check_and_report

# "ip monitor" çıkışını satır satır oku; link (arayüz ekleme/çıkarma,
# up/down), address (IP atama/kaldırma) ve route (varsayılan rota
# değişiklikleri) olaylarını dinler. Bu komut ağ değişmediği sürece
# hiçbir çıktı üretmez, dolayısıyla CPU'da boşta bekler.
ip monitor link address route 2>/dev/null | while true; do
    # Bir olay satırı gelene kadar blokla bekle
    if ! read -r _; then
        break
    fi

    # Kısa bir süre içinde art arda gelen olayları (örn. bir arayüzün
    # aşağı/yukarı gitmesiyle oluşan birden çok satır) tek bir kontrolde
    # birleştir (debounce), gereksiz tekrar kontrolleri önle.
    while read -r -t 0.5 _; do :; done

    check_and_report
done
