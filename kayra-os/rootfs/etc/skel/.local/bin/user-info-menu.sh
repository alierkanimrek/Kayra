#!/usr/bin/env bash
#
# Kayra OS — Waybar "Kullanıcı Bilgisi" modülü için tıklama menüsü
# ------------------------------------------------------------------
# Modüle tıklandığında fuzzel ile sabit bir menü açar.
#
# NOT: Menü seçenekleri şu an İŞLEVSİZDİR (placeholder). Her seçeneğin
# gerçek işlevi (şifre değiştirme, grup düzenleme, $HOME kullanımı)
# ayrıca yazılacak ve aşağıdaki case bloklarına eklenecektir.

set -euo pipefail

OPT_PASSWORD="Şifre değiştirme"
OPT_GROUPS="Grupları düzenleme"
OPT_HOME_USAGE="\$HOME dizini kullanımı"

MENU="${OPT_PASSWORD}
${OPT_GROUPS}
${OPT_HOME_USAGE}"



CHOICE=$(pkill fuzzel; printf '%s\n' "$MENU" | fuzzel --dmenu --anchor=top-right --log-no-syslog --prompt "Kullanıcı: ") || exit 0

if [ -z "${CHOICE:-}" ]; then
    exit 0
fi

case "$CHOICE" in
    "$OPT_PASSWORD")
        # TODO: Şifre değiştirme betiği buraya eklenecek
        # exec "$(dirname "${BASH_SOURCE[0]}")/actions/10-change-password.sh"
        :
        ;;
    "$OPT_GROUPS")
        # TODO: Grupları düzenleme betiği buraya eklenecek
        # exec "$(dirname "${BASH_SOURCE[0]}")/actions/20-edit-groups.sh"
        :
        ;;
    "$OPT_HOME_USAGE")
        # TODO: $HOME dizini kullanımını gösterme betiği buraya eklenecek
        # exec "$(dirname "${BASH_SOURCE[0]}")/actions/30-home-usage.sh"
        :
        ;;
esac
