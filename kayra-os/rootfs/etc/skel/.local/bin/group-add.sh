#!/usr/bin/env bash
# grup-ekle.sh
# fuzzel menüsü ile kullanıcıyı üye olmadığı bir gruba ekler.
#
# Kullanım: ./grup-ekle.sh [fuzzel'e geçilecek ek parametreler]

set -euo pipefail

TARGET_USER="${SUDO_USER:-${USER:-$(id -un)}}"

# --- Açık fuzzel pencerelerini kapat -----------------------------------
pkill -x fuzzel 2>/dev/null || true

# --- Grup bilgisi topla --------------------------------------------------
mapfile -t ALL_GROUPS < <(getent group | cut -d: -f1 | sort -u)
mapfile -t USER_GROUPS < <(id -Gn "$TARGET_USER" | tr ' ' '\n')

declare -A IS_MEMBER_MAP
for ug in "${USER_GROUPS[@]}"; do
    IS_MEMBER_MAP["$ug"]=1
done
is_member() { [[ -n "${IS_MEMBER_MAP[$1]+x}" ]]; }

# --- Eklenebilir grup listesi (henüz üye olunmayanlar) -------------------
ADDABLE_GROUPS=()
for g in "${ALL_GROUPS[@]}"; do
    if ! is_member "$g"; then
        ADDABLE_GROUPS+=("$g")
    fi
done

if [[ ${#ADDABLE_GROUPS[@]} -eq 0 ]]; then
    notify-send -u normal "Grup Yönetimi" "Eklenebilecek bir grup bulunamadı."
    exit 0
fi

menu=$(printf '%s\n' "${ADDABLE_GROUPS[@]}")

# --- fuzzel'i çalıştır -----------------------------------------------------
line_count=${#ADDABLE_GROUPS[@]}

selected_group=$(printf '%s' "$menu" | fuzzel --dmenu --log-no-syslog "$@" --lines="$line_count") || true

[[ -z "$selected_group" ]] && exit 0

# --- Gruba ekle (usermod ile) --------------------------------------------
if pkexec usermod -aG "$selected_group" "$TARGET_USER"; then
    notify-send -u normal "Grup Yönetimi" \
        "${TARGET_USER} kullanıcısı '${selected_group}' grubuna eklendi."
else
    notify-send -u critical "Grup Yönetimi" \
        "'${selected_group}' grubuna ekleme işlemi başarısız oldu."
fi
