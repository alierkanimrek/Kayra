#!/usr/bin/env bash
#
# Kayra OS — Waybar "Kullanıcı Bilgisi" modülü
# ---------------------------------------------
# Waybar'ın return-type=json bekleyen bir custom modülü için veri üretir.
# Çıktı: {"text": "...", "tooltip": "...", "class": "...", "alt": "..."}
#
# Bağımlılıklar: jq, coreutils (getent, id)

set -euo pipefail

# Modül ikonu (kullanıcı simgesi)
# NOT: LC_ALL=C.UTF-8 ZORUNLU. \U kaçış dizisi, çalıştırma ortamının
# locale'i UTF-8 değilse (örn. sway/waybar minimal bir ortamda
# başlatıldıysa) sessizce doğru UTF-8 baytlarını üretmeyip literal
# "\uXXXX" metnini basar. Bu satırlar o riski ortadan kaldırır.
ICON_USER=$(LC_ALL=C.UTF-8 printf '%b' '\U000E853')
# Supervisor (wheel grubu üyesi) rozeti
ICON_SUPERVISOR=$(LC_ALL=C.UTF-8 printf '%b' '\U000E8D3')

USERNAME="${USER:-$(whoami)}"

# GECOS alanından tam adı çek (virgülle ayrılmış ilk alan = tam ad)
FULLNAME=$(getent passwd "$USERNAME" | awk -F: '{print $5}' | cut -d, -f1)
if [ -z "$FULLNAME" ]; then
    FULLNAME="$USERNAME"
fi

# Kullanıcının üyesi olduğu tüm gruplar (birincil + ikincil), alfabetik sıralı
GROUPS_LIST=$(id -nG "$USERNAME" | tr ' ' '\n' | sort)

IS_SUPERVISOR=false
if printf '%s\n' "$GROUPS_LIST" | grep -qx "wheel"; then
    IS_SUPERVISOR=true
fi

# Tooltip (Pango markup desteklenir)
TOOLTIP="<b>${FULLNAME}</b>  (${USERNAME})"
if $IS_SUPERVISOR; then
    TOOLTIP="${TOOLTIP}  ${ICON_SUPERVISOR}"
fi

GROUPS_FORMATTED=$(printf '%s\n' "$GROUPS_LIST" | sed 's/^/  • /')
TOOLTIP="${TOOLTIP}

<b>Gruplar:</b>
${GROUPS_FORMATTED}"

CLASS="user-info"
if $IS_SUPERVISOR; then
    CLASS="user-info supervisor"
fi

# -c (compact) ZORUNLU: waybar'ın return-type=json modülleri çıktıyı
# satır satır okur. jq'nun varsayılan pretty-print modu birden çok satıra
# yayılmış JSON ürettiği için (ilk satır sadece "{" olur) waybar
# "Missing '}' or object member name" hatası verir.
jq -nc \
  --arg text "$ICON_USER" \
  --arg tooltip "$TOOLTIP" \
  --arg class "$CLASS" \
  '{text: $text, tooltip: $tooltip, class: $class, alt: $class}'
