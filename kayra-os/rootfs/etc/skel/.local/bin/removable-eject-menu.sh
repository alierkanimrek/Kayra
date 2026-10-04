#!/usr/bin/env bash
# usbeject: bağlı bölümü olan rm=true diskleri fuzzel'de listeler, seçileni ayırıp güvenle çıkarır.

list=$(lsblk -J -o PATH,TYPE,LABEL,SIZE,RM,MODEL,PKNAME,MOUNTPOINTS |
    jq -r '
        [.blockdevices[] | recurse(.children[]?)] as $all
        | $all[]
        | select(.type == "disk")
        | select(.rm == true or .rm == 1 or .rm == "1")
        | .path as $p
        | ($p | sub("^/dev/"; "")) as $name
        | [$all[] | select(.type == "part" and .pkname == $name)] as $parts
        | select([$parts[], .] | map(.mountpoints[]? | select(.)) | length > 0)
        | ([$parts[] | .label // empty] | join(",")) as $l
        | "\($p)  \((.model // "-") | gsub("^\\s+|\\s+$";""))  \(.size)  \(if $l == "" then "-" else $l end)"')

if [ -z "$list" ]; then
    notify-send -i drive-removable-media "Depolama" "Bağlı çıkarılabilir aygıt yok"
    exit 0
fi

sel=$(printf '%s\n' "$list" | fuzzel --dmenu -p "Çıkar: ") || exit 0
disk=$(awk '{print $1}' <<<"$sel")
[ -n "$disk" ] || exit 0

# Diskin altındaki tüm bağlı bölümleri ayır
failed=()
while read -r part; do
    [ -n "$part" ] || continue
    if lsblk -no MOUNTPOINTS "$part" | grep -q .; then
        udisksctl unmount -b "$part" >/dev/null 2>&1 || failed+=("$part")
    fi
done < <(lsblk -lnpo PATH,TYPE "$disk" | awk '$2=="part"{print $1}')

# Disk doğrudan bağlıysa (bölümsüz) onu da ayır
if lsblk -dno MOUNTPOINTS "$disk" | grep -q .; then
    udisksctl unmount -b "$disk" >/dev/null 2>&1 || failed+=("$disk")
fi

if [ ${#failed[@]} -gt 0 ]; then
    notify-send -u critical -i dialog-error "Çıkarma başarısız" \
        "Ayrılamayan (meşgul olabilir): ${failed[*]}"
    exit 1
fi

sync
if udisksctl power-off -b "$disk" >/dev/null 2>&1; then
    notify-send -i drive-removable-media "Depolama" "$disk güvenle çıkarılabilir"
else
    notify-send -i drive-removable-media "Depolama" "$disk ayrıldı (power-off desteklenmiyor olabilir, çıkarmak güvenli)"
fi
