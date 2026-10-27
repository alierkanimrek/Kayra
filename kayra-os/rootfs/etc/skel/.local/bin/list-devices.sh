#!/usr/bin/env bash
# list-devices.sh - Collects PCI and USB devices with their kernel modules.
#
# For every device it reports:
#   * the kernel driver/module currently bound to it (modules in use)
#   * the other modules that could handle the device (alias resolution)
#
# The result is written as JSON to:
#   $HOME/.local/bin/data/devices.json
#
# Usage: list-devices.sh
#
export LC_ALL=C.UTF-8
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$HOME/.local/bin/data"
DATA_FILE="$DATA_DIR/devices.json"

# shellcheck source=/dev/null
[ -f "$SCRIPT_DIR/klog.sh" ] && . "$SCRIPT_DIR/klog.sh"

# Fallback logger when klog.sh is not available
if ! command -v log >/dev/null 2>&1; then
    log() { printf '%s\n' "$*"; }
fi

log INFO "Starting device collection"

for cmd in lspci lsusb modprobe lsmod jq; do
    command -v "$cmd" >/dev/null 2>&1 || { log ERROR "Missing required command: $cmd"; exit 1; }
done

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# JSON array of all currently loaded kernel modules (used for the "loaded" flag)
LOADED_JSON="[]"
if [ -r /proc/modules ]; then
    LOADED_JSON="$(awk 'NR>1{print $1}' /proc/modules | jq -R -s 'split("\n")|map(select(length>0))|unique')"
else
    LOADED_JSON="$(lsmod 2>/dev/null | awk 'NR>1{print $1}' | jq -R -s 'split("\n")|map(select(length>0))|unique')"
fi

# Convert a list of module names (one per line) into a JSON array of objects
# [{"name":"e1000","loaded":true}, ...]
modules_to_json() {
    jq -R -s --argjson loaded "$LOADED_JSON" '
        split("\n")
        | map(gsub("^\\s+|\\s+$"; ""))
        | map(select(length > 0))
        | unique
        | map(. as $n | {name: $n, loaded: ($loaded | index($n) != null)})
    '
}

# ---------------------------------------------------------------- PCI devices

PCI_FILE="$TMP_DIR/pci.json"
: > "$PCI_FILE"

pci_slots=$(ls -1 /sys/bus/pci/devices 2>/dev/null | sort)

for slot in $pci_slots; do
    dev_path="/sys/bus/pci/devices/$slot"

    modalias=$(cat "$dev_path/modalias" 2>/dev/null)

    # Currently bound driver and its kernel module
    driver=""
    module=""
    if [ -L "$dev_path/driver" ]; then
        driver=$(basename "$(readlink -f "$dev_path/driver")" 2>/dev/null)
        module_link=$(readlink -f "$dev_path/driver/module" 2>/dev/null)
        [ -n "$module_link" ] && module=$(basename "$module_link")
    fi
    [ -z "$module" ] && [ -n "$driver" ] && module="$driver"

    # Names and numeric ids (two lspci calls: one resolved, one numeric)
    names_line=$(lspci -Dmm -s "$slot" 2>/dev/null | head -n1)
    nums_line=$(lspci -Dmm -n -s "$slot" 2>/dev/null | head -n1)

    mapfile -t name_fields < <(printf '%s\n' "$names_line" | grep -o '"[^"]*"' | sed 's/^"//; s/"$//')
    mapfile -t num_fields < <(printf '%s\n' "$nums_line" | grep -o '"[^"]*"' | sed 's/^"//; s/"$//')

    class_name="${name_fields[0]:-}"
    vendor_name="${name_fields[1]:-}"
    device_name="${name_fields[2]:-}"
    subsys_vendor="${name_fields[3]:-}"
    subsys_device="${name_fields[4]:-}"

    class_id="${num_fields[0]:-}"
    vendor_id="${num_fields[1]:-}"
    device_id="${num_fields[2]:-}"

    revision=$(printf '%s\n' "$nums_line" | grep -o '\-r[0-9a-fA-F]*' | head -n1 | tr -d '\-r')

    # Modules that could handle this device: lspci's own list plus alias resolution
    available_mods="$TMP_DIR/avail.$$"
    : > "$available_mods"
    lspci -Dnnk -s "$slot" 2>/dev/null \
        | sed -n 's/^[[:space:]]*Kernel modules:[[:space:]]*//p' \
        | tr ',' '\n' >> "$available_mods"
    [ -n "$modalias" ] && modprobe -R "$modalias" 2>/dev/null >> "$available_mods"

    in_use_mods="$TMP_DIR/inuse.$$"
    : > "$in_use_mods"
    [ -n "$module" ] && printf '%s\n' "$module" >> "$in_use_mods"

    jq -n \
        --arg slot "$slot" \
        --arg class_id "$class_id" \
        --arg class_name "$class_name" \
        --arg vendor_id "$vendor_id" \
        --arg device_id "$device_id" \
        --arg vendor "$vendor_name" \
        --arg device "$device_name" \
        --arg revision "$revision" \
        --arg subsys_vendor "$subsys_vendor" \
        --arg subsys_device "$subsys_device" \
        --arg driver "$driver" \
        --arg modalias "$modalias" \
        --argjson in_use "$(modules_to_json < "$in_use_mods")" \
        --argjson available "$(modules_to_json < "$available_mods")" \
        '{
            bus: "pci",
            slot: $slot,
            class_id: $class_id,
            class_name: $class_name,
            vendor_id: $vendor_id,
            device_id: $device_id,
            vendor: $vendor,
            device: $device,
            revision: $revision,
            subsystem: {vendor: $subsys_vendor, device: $subsys_device},
            driver: $driver,
            modalias: $modalias,
            modules_in_use: $in_use,
            modules_available: $available,
            modules_alternative: [
                $available[] | select(.name as $n | ($in_use | map(.name) | index($n)) == null)
            ]
        }' >> "$PCI_FILE"

    rm -f "$available_mods" "$in_use_mods"
done

# ---------------------------------------------------------------- USB devices

USB_FILE="$TMP_DIR/usb.json"
: > "$USB_FILE"

usb_paths=$(ls -1 /sys/bus/usb/devices 2>/dev/null | sort)

for usb_path in $usb_paths; do
    dev_path="/sys/bus/usb/devices/$usb_path"
    [ -r "$dev_path/idVendor" ] || continue   # skip interface-only entries

    vendor_id=$(cat "$dev_path/idVendor" 2>/dev/null)
    device_id=$(cat "$dev_path/idProduct" 2>/dev/null)
    manufacturer=$(cat "$dev_path/manufacturer" 2>/dev/null)
    product=$(cat "$dev_path/product" 2>/dev/null)
    version=$(cat "$dev_path/version" 2>/dev/null)
    dev_class=$(cat "$dev_path/bDeviceClass" 2>/dev/null)
    bus_num=$(cat "$dev_path/busnum" 2>/dev/null)
    dev_num=$(cat "$dev_path/devnum" 2>/dev/null)
    speed=$(cat "$dev_path/speed" 2>/dev/null)
    modalias=$(cat "$dev_path/modalias" 2>/dev/null)

    # Interfaces of this device (directories named "<path>:<config>.<intf>")
    ifaces_file="$TMP_DIR/ifaces.$$"
    avail_file="$TMP_DIR/uavail.$$"
    inuse_file="$TMP_DIR/uinuse.$$"
    : > "$ifaces_file"
    : > "$avail_file"
    : > "$inuse_file"

    for if_path in "$dev_path"/*:*; do
        [ -d "$if_path" ] || continue
        if_num=$(basename "$if_path")
        if_class=$(cat "$if_path/bInterfaceClass" 2>/dev/null)
        if_modalias=$(cat "$if_path/modalias" 2>/dev/null)
        if_driver=""
        if_module=""
        if [ -L "$if_path/driver" ]; then
            if_driver=$(basename "$(readlink -f "$if_path/driver")" 2>/dev/null)
            if_module_link=$(readlink -f "$if_path/driver/module" 2>/dev/null)
            [ -n "$if_module_link" ] && if_module=$(basename "$if_module_link")
        fi
        [ -z "$if_module" ] && [ -n "$if_driver" ] && if_module="$if_driver"

        [ -n "$if_module" ] && printf '%s\n' "$if_module" >> "$inuse_file"
        if_avail="$TMP_DIR/iavail.$$"
        : > "$if_avail"
        [ -n "$if_modalias" ] && modprobe -R "$if_modalias" 2>/dev/null >> "$if_avail"
        [ -n "$if_modalias" ] && modprobe -R "$if_modalias" 2>/dev/null >> "$avail_file"

        jq -n \
            --arg path "$if_num" \
            --arg class "$if_class" \
            --arg driver "$if_driver" \
            --arg modalias "$if_modalias" \
            --argjson in_use "$(printf '%s\n' "$if_module" | modules_to_json)" \
            --argjson available "$(modules_to_json < "$if_avail")" \
            '{
                path: $path,
                class: $class,
                driver: $driver,
                modalias: $modalias,
                modules_in_use: $in_use,
                modules_available: $available,
                modules_alternative: [
                    $available[] | select(.name as $n | ($in_use | map(.name) | index($n)) == null)
                ]
            }' >> "$ifaces_file"
        rm -f "$if_avail"
    done

    # Device level driver/modules
    dev_driver=""
    dev_module=""
    if [ -L "$dev_path/driver" ]; then
        dev_driver=$(basename "$(readlink -f "$dev_path/driver")" 2>/dev/null)
        dev_module_link=$(readlink -f "$dev_path/driver/module" 2>/dev/null)
        [ -n "$dev_module_link" ] && dev_module=$(basename "$dev_module_link")
    fi
    [ -n "$dev_module" ] && printf '%s\n' "$dev_module" >> "$inuse_file"
    [ -n "$modalias" ] && modprobe -R "$modalias" 2>/dev/null >> "$avail_file"

    jq -n \
        --arg port_path "$usb_path" \
        --arg id "$vendor_id:$device_id" \
        --arg vendor_id "$vendor_id" \
        --arg device_id "$device_id" \
        --arg vendor "$manufacturer" \
        --arg product "$product" \
        --arg version "$version" \
        --arg device_class "$dev_class" \
        --arg bus "$bus_num" \
        --arg device_number "$dev_num" \
        --arg speed "$speed" \
        --arg driver "$dev_driver" \
        --arg modalias "$modalias" \
        --argjson interfaces "$(jq -s '.' "$ifaces_file")" \
        --argjson in_use "$(modules_to_json < "$inuse_file")" \
        --argjson available "$(modules_to_json < "$avail_file")" \
        '{
            bus: "usb",
            port_path: $port_path,
            id: $id,
            vendor_id: $vendor_id,
            device_id: $device_id,
            vendor: $vendor,
            product: $product,
            version: $version,
            device_class: $device_class,
            bus_number: $bus,
            device_number: $device_number,
            speed: $speed,
            driver: $driver,
            modalias: $modalias,
            interfaces: $interfaces,
            modules_in_use: $in_use,
            modules_available: $available,
            modules_alternative: [
                $available[] | select(.name as $n | ($in_use | map(.name) | index($n)) == null)
            ]
        }' >> "$USB_FILE"

    rm -f "$ifaces_file" "$avail_file" "$inuse_file"
done

# ---------------------------------------------------------------- Write output

mkdir -p "$DATA_DIR"

jq -s '.' "$PCI_FILE" > "$TMP_DIR/pci-array.json"
jq -s '.' "$USB_FILE" > "$TMP_DIR/usb-array.json"

jq -n \
    --arg generated_at "$(date '+%Y-%m-%d %H:%M:%S')" \
    --arg hostname "$(hostname 2>/dev/null)" \
    --arg kernel "$(uname -r)" \
    --slurpfile pci "$TMP_DIR/pci-array.json" \
    --slurpfile usb "$TMP_DIR/usb-array.json" \
    '{
        generated_at: $generated_at,
        hostname: $hostname,
        kernel: $kernel,
        pci: $pci[0],
        usb: $usb[0]
    }' > "$DATA_FILE.tmp" && mv -f "$DATA_FILE.tmp" "$DATA_FILE"

pci_count=$(jq '.pci | length' "$DATA_FILE")
usb_count=$(jq '.usb | length' "$DATA_FILE")

log INFO "Wrote $DATA_FILE (pci: $pci_count, usb: $usb_count)"
printf 'Devices written to %s (pci: %s, usb: %s)\n' "$DATA_FILE" "$pci_count" "$usb_count"
