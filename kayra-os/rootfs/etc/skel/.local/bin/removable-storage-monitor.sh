#!/usr/bin/env bash
# usbwatch: çıkarılabilir (rm=true) aygıtları izler, waybar için JSON basar,
# yeni takılan bölümler için notify-send gönderir.

trap 'kill 0' EXIT

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_REMOVABLE_STORAGE_MONITOR

snap() {
    lsblk -J -o PATH,TYPE,LABEL,FSTYPE,SIZE,RM,MOUNTPOINTS |
    jq -c '[.blockdevices[] | recurse(.children[]?)
            | select(.type == "disk" or .type == "part")
            | select(.rm == true or .rm == 1 or .rm == "1")
            | del(.children) | {(.path): .}] | add // {}'
}

emit() {
    jq -c '
        def esc: gsub("&";"&amp;") | gsub("<";"&lt;") | gsub(">";"&gt;");
        [.[]] | sort_by(.path) as $d
        | if ($d | length) == 0
          then {text: "", tooltip: "${MSG[TOOLTIP_EMPTY]}", class: "empty"}
          else {
              text: "\ue1db \($d | length)",
              class: "present",
              tooltip: ($d | map(
                  i18n_template("${MSG[TOOLTIP_ITEM_FORMAT]}" \
                    type=(.type // "-") \
                    label=(.label // "-") \
                    fstype=(.fstype // "-") \
                    size=(.size // "-") \
                    mountpoints=([.mountpoints[]? | select(.)] | join(", ") | if . == "" then "-" else . end))
                  ) | map(esc) | join("\n"))
          } end' <<<"$1"
}

# Tek bir bölüm için bildirim + eylemler
notify_part() {
    local dev=$1 msg=$2 act mp
    act=$(notify-send -i drive-removable-media -t 15000 \
          -A open="${MSG[NOTIFY_ACTION_OPEN]}" \
          -A mount="${MSG[NOTIFY_ACTION_MOUNT]}" \
          -A default="${MSG[NOTIFY_ACTION_DEFAULT]}" \
          "${MSG[NOTIFY_TITLE]}" "$msg")
    case "$act" in
        open|default|mount)
            udisksctl mount -b "$dev" >/dev/null 2>&1
            if [ "$act" != mount ]; then
                mp=$(lsblk -no MOUNTPOINTS "$dev" | head -n1)
                [ -n "$mp" ] && xdg-open "$mp"
            fi ;;
    esac
}

# prev ile cur arasında yeni eklenen bölümleri bulup her biri için bildirim aç
notify_new() {
    jq -nr --argjson o "$1" --argjson n "$2" '
        $n | to_entries[] | select($o[.key] == null) | .value
        | select(.type == "part")
        | "\(.path)\t\(.label // .path) (\(.fstype // "?"), \(.size))"' |
    while IFS=$'\t' read -r dev msg; do
        notify_part "$dev" "$msg" &
    done
}

prev=$(snap)
emit "$prev"

{
    udevadm monitor -u -s block | grep --line-buffered '^UDEV' &
    findmnt --poll -n &
    wait
} | while read -r _; do
    while read -t 0.3 -r _; do :; done   # debounce
    udevadm settle
    cur=$(snap)
    if [ "$cur" != "$prev" ]; then
        notify_new "$prev" "$cur"
        emit "$cur"
        prev=$cur
    fi
done
