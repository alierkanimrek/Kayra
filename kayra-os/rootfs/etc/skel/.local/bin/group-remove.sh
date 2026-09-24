#!/usr/bin/env bash
# grup-cikar.sh
# fuzzel menüsü ile kullanıcının üye olduğu gruplardan çıkarma yapar.
# İstisna gruplar menüde görünür ama üzerlerinde işlem yapılamaz.
#
# Kullanım: ./grup-cikar.sh [fuzzel'e geçilecek ek parametreler]

set -euo pipefail

# --- Ayarlar -----------------------------------------------------------
ICON_MEMBER=$(printf '%b' '\U0000E7EF')   # çıkarılabilir grup simgesi
ICON_EXCEPTION=""                          # istisna grup simgesi yok

SEP=$'\t'   # simge ile grup adı arasındaki sabit ayraç

# İşlem yapılamayacak istisna gruplar
EXCEPTION_GROUPS=(audio video input users socklog)

TARGET_USER="${SUDO_USER:-${USER:-$(id -un)}}"

# --- Açık fuzzel pencerelerini kapat -----------------------------------
pkill -x fuzzel 2>/dev/null || true

# --- Grup bilgisi topla --------------------------------------------------
mapfile -t USER_GROUPS < <(id -Gn "$TARGET_USER" | tr ' ' '\n')
PRIMARY_GROUP=$(id -gn "$TARGET_USER")

declare -A IS_EXCEPTION_MAP
for eg in "${EXCEPTION_GROUPS[@]}"; do
    IS_EXCEPTION_MAP["$eg"]=1
done
is_exception() { [[ -n "${IS_EXCEPTION_MAP[$1]+x}" ]]; }

# --- Menüde gösterilecek gruplar (birincil grup hariç) -------------------
LISTED_GROUPS=()
for g in "${USER_GROUPS[@]}"; do
    [[ "$g" == "$PRIMARY_GROUP" ]] && continue
    LISTED_GROUPS+=("$g")
done

if [[ ${#LISTED_GROUPS[@]} -eq 0 ]]; then
    notify-send -u normal "Grup Yönetimi" "Çıkarılabilecek bir grup bulunamadı."
    exit 0
fi

# --- Menü metnini oluştur (TAB ayraçlı) ----------------------------------
menu=""
for g in "${LISTED_GROUPS[@]}"; do
    if is_exception "$g"; then
        menu+="${ICON_EXCEPTION}${SEP}${g}"$'\n'
    else
        menu+="${ICON_MEMBER}${SEP}${g}"$'\n'
    fi
done

# --- fuzzel'i çalıştır -----------------------------------------------------
line_count=${#LISTED_GROUPS[@]}

selection=$(printf '%s' "$menu" | fuzzel --dmenu --log-no-syslog "$@" --lines="$line_count") || true

[[ -z "$selection" ]] && exit 0

# TAB'a göre ayrıştır: simge boş olsa da kesin sonuç verir
selected_group="${selection#*"$SEP"}"

# --- İstisna grup ise: işlem yapılmaz ------------------------------------
if is_exception "$selected_group"; then
    notify-send -u normal "Grup Yönetimi" \
        "'${selected_group}' istisna grubudur, ${TARGET_USER} kullanıcısı bu gruptan çıkarılamaz."
    exit 0
fi

# --- Gruptan çıkar (usermod ile) -----------------------------------------
new_list=""
for g in "${USER_GROUPS[@]}"; do
    if [[ "$g" != "$selected_group" && "$g" != "$PRIMARY_GROUP" ]]; then
        new_list+="${g},"
    fi
done
new_list="${new_list%,}"

if pkexec usermod -G "$new_list" "$TARGET_USER"; then
    notify-send -u normal "Grup Yönetimi" \
        "${TARGET_USER} kullanıcısı '${selected_group}' grubundan çıkarıldı."
else
    notify-send -u critical "Grup Yönetimi" \
        "'${selected_group}' grubundan çıkarma işlemi başarısız oldu."
fi
