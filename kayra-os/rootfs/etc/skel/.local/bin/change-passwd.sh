#!/usr/bin/env bash
#
# fuzzel-passwd.sh
# Fuzzel ile kullanıcı şifresi değiştirme betiği (Void Linux, Wayland)
#
# Tasarım: passwd(1) girdiyi mutlaka gerçek bir tty'den okur. Bu yüzden
# onu pty simüle eden bir araçla (expect/python/socat) değil, GERÇEK bir
# terminalde (alacritty) çalıştırıyoruz. Fuzzel'den alınan şifreleri de
# o pencereye "wtype" ile klavye girdisi gibi yazdırıyoruz. Böylece hiçbir
# ek dil (python/expect) veya sudo/wheel/pkexec gerekmiyor.
#
# Bağımlılıklar:
#   - fuzzel      (xbps-install -S fuzzel)
#   - alacritty   (xbps-install -S alacritty)
#   - wtype       (xbps-install -S wtype)   -- Wayland sanal klavye girdisi
#   - libnotify   (notify-send için, xbps-install -S libnotify)

set -uo pipefail

FUZZEL_OPTS=(--lines=1 --anchor=top-right --log-no-syslog)
USER_NAME="$(id -un)"
WIN_CLASS="fuzzelpasswd"
RESULT_FILE="$(mktemp /tmp/fuzzelpasswd.XXXXXX)"

cleanup() {
    rm -f "$RESULT_FILE"
}
trap cleanup EXIT

# Her fuzzel menüsünden önce açık kalan diğer fuzzel pencerelerini kapat
close_fuzzel() {
    pkill -x fuzzel 2>/dev/null
    sleep 0.05
}

# Gizli (parola) girişi için fuzzel dmenu penceresi aç, girilen metni döndür
ask_password() {
    local prompt="$1"
    close_fuzzel
    printf '' | fuzzel --dmenu --password --prompt="$prompt" "${FUZZEL_OPTS[@]}" 2>/dev/null
}

# Basit bilgi penceresi (Tamam ile kapatılır)
info_box() {
    local msg="$1"
    close_fuzzel
    printf 'Tamam\n' | fuzzel --dmenu --prompt="$msg" "${FUZZEL_OPTS[@]}" >/dev/null 2>&1
}

notify() {
    notify-send "$@"
}

# wtype ile metin yaz, ardından Enter'a bas
type_and_enter() {
    local text="$1"
    wtype -- "$text"
    sleep 0.15
    wtype -k Return
}

# --- Bağımlılık kontrolü -----------------------------------------------
for bin in fuzzel alacritty wtype; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        info_box "$bin kurulu değil (xbps-install -S $bin)"
        notify -u critical "Şifre değiştirme" "$bin kurulu değil."
        exit 1
    fi
done

# --- 1) Mevcut şifreyi iste ---------------------------------------------
CURRENT_PASS="$(ask_password "Mevcut şifre: ")"
if [[ -z "$CURRENT_PASS" ]]; then
    notify "Şifre değiştirme" "İşlem iptal edildi."
    exit 1
fi

# --- 2) Yeni şifreyi iki defa iste --------------------------------------
NEW_PASS1="$(ask_password "Yeni şifre: ")"
if [[ -z "$NEW_PASS1" ]]; then
    notify "Şifre değiştirme" "İşlem iptal edildi."
    unset CURRENT_PASS
    exit 1
fi

NEW_PASS2="$(ask_password "Yeni şifre (tekrar): ")"
if [[ -z "$NEW_PASS2" ]]; then
    notify "Şifre değiştirme" "İşlem iptal edildi."
    unset CURRENT_PASS NEW_PASS1
    exit 1
fi

if [[ "$NEW_PASS1" != "$NEW_PASS2" ]]; then
    notify -u critical "Şifre değiştirme" "Yeni şifreler birbiriyle eşleşmiyor."
    unset CURRENT_PASS NEW_PASS1 NEW_PASS2
    exit 1
fi

# --- 3) Önceki kalıntı pencereyi temizle, passwd'ı gerçek terminalde aç -
pkill -f "alacritty --class $WIN_CLASS" 2>/dev/null
close_fuzzel

alacritty --class "$WIN_CLASS" -e bash -c \
    "passwd '$USER_NAME'; echo \$? > '$RESULT_FILE'" &

# Pencere açılıp passwd'ın ilk istemi göstermesi için bekle
sleep 0.7

# --- 4) Şifreleri sırayla "yaz" -----------------------------------------
type_and_enter "$CURRENT_PASS"
sleep 0.4
type_and_enter "$NEW_PASS1"
sleep 0.4
type_and_enter "$NEW_PASS2"

# --- 5) Sonucu bekle -----------------------------------------------------
STATUS=1
for _ in $(seq 1 50); do
    if [[ -s "$RESULT_FILE" ]]; then
        STATUS="$(cat "$RESULT_FILE")"
        break
    fi
    sleep 0.1
done

pkill -f "alacritty --class $WIN_CLASS" 2>/dev/null
unset CURRENT_PASS NEW_PASS1 NEW_PASS2

if [[ "$STATUS" -eq 0 ]]; then
    notify "Şifre değiştirme" "Şifre başarıyla değiştirildi."
else
    notify -u critical "Şifre değiştirme" "Şifre değiştirilemedi. Mevcut şifre hatalı olabilir."
fi

exit "$STATUS"
