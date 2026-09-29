#!/usr/bin/env bash
#
# Kayra OS — Waybar "System Info" module
# -----------------------------------------
# Generates data for a Waybar custom module expecting return-type=json.
# Output: {"text": "...", "tooltip": "...", "class": "...", "alt": "..."}
#
# Dependencies: jq, coreutils, util-linux, lsb-release

set -euo pipefail

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_SYSTEM_INFO

# Module icon (gear/settings symbol)
ICON_SYSTEM=$(LC_ALL=C.UTF-8 printf '%b' '\U000E8B8')

# Get system information
get_hostname() {
    hostname 2>/dev/null || echo "Unknown"
}

get_kernel_version() {
    uname -r 2>/dev/null || echo "Unknown"
}

get_cpu_info() {
    local cpu_name=$(grep -m1 "^model name" /proc/cpuinfo 2>/dev/null | sed 's/.*: //' || echo "Unknown")
    local cpu_count=$(nproc 2>/dev/null || echo "Unknown")
    echo "$cpu_name ($cpu_count cores)"
}

get_gpu_info() {
    local gpu_info=$(lspci 2>/dev/null | grep -E "VGA|Display" | sed 's/.*: //' | head -1)
    if [ -z "$gpu_info" ]; then
        # Fallback for systems without lspci
        gpu_info=$(grep -i "gpu\|graphics" /proc/cpuinfo 2>/dev/null | head -1 || echo "Unknown")
    fi
    echo "${gpu_info:-Unknown}"
}

get_ram_info() {
    local ram_total=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}')
    echo "${ram_total:-Unknown}"
}

get_disk_info() {
    df -h / 2>/dev/null | awk 'NR==2 {printf "%s / %s (%s used)", $3, $2, $5}' || echo "Unknown"
}

# Build tooltip with system information
HOSTNAME=$(get_hostname)
KERNEL=$(get_kernel_version)
CPU=$(get_cpu_info)
GPU=$(get_gpu_info)
RAM=$(get_ram_info)
DISK=$(get_disk_info)

TOOLTIP="<b>${MSG[LABEL_SYSTEM]}</b>
${HOSTNAME}

<b>${MSG[LABEL_KERNEL]}</b>
${KERNEL}

<b>${MSG[LABEL_CPU]}</b>
${CPU}

<b>${MSG[LABEL_GPU]}</b>
${GPU}

<b>${MSG[LABEL_RAM]}</b>
${RAM}

<b>${MSG[LABEL_DISK]}</b>
${DISK}"

# -c (compact) is required: waybar's return-type=json modules read output
# line by line. jq's default pretty-print produces multiline JSON (first line
# is just "{"), causing waybar to error "Missing '}' or object member name".
jq -nc \
  --arg text "$ICON_SYSTEM" \
  --arg tooltip "$TOOLTIP" \
  --arg class "system-info" \
  '{text: $text, tooltip: $tooltip, class: $class, alt: "system-info"}'
