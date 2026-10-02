#!/usr/bin/env bash
#
# Network Monitor Script - Waybar custom module for network device monitoring.
#
# Monitors Ethernet and other (virtual/docker/veth etc.) network interfaces.
# Wireless (wl*) and cellular (ww*, usb* etc.) interfaces are not handled by this script.
#
# Usage:
#   net-monitor.sh --ethernet "en*" --other "docker*,veth*,br-*,virbr*"
#
# Patterns can contain multiple shell globs separated by commas.

set -uo pipefail

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_NET_MONITOR

ETH_PATTERNS=""
OTHER_PATTERNS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --ethernet|-e)
            ETH_PATTERNS="${2:-}"
            shift 2
            ;;
        --other|-o)
            OTHER_PATTERNS="${2:-}"
            shift 2
            ;;
        *)
            echo "$(i18n_template "${MSG[UNKNOWN_PARAMETER]}" PARAM="$1")" >&2
            exit 1
            ;;
    esac
done

if [[ -z "$ETH_PATTERNS" && -z "$OTHER_PATTERNS" ]]; then
    echo "$(i18n_template "${MSG[USAGE_ERROR]}" SCRIPT="$0")" >&2
    exit 1
fi

# Nerd Font / icon font codepoints (U+EB2F, U+F56E)
# Note: Using direct UTF-8 byte sequences (\x..) instead of \u escapes
# for locale-independent operation.
ETH_ICON=$'\xee\xac\xaf'
OTHER_ICON=$'\xef\x95\xae'

# Convert comma-separated glob list (e.g. "docker*,veth*") to ERE alternation
# (e.g. "^docker.*$|^veth.*$"). jq's test() function (Oniguruma) supports this syntax.
glob_list_to_ere() {
    local list="$1"
    local IFS=','
    local -a arr
    read -r -a arr <<< "$list"
    local ere="" pat rex
    for pat in "${arr[@]}"; do
        [[ -z "$pat" ]] && continue
        rex=$(printf '%s' "$pat" | sed -e 's/[.[\^$(){}|+]/\\&/g' -e 's/\*/.*/g' -e 's/\?/./g')
        if [[ -n "$ere" ]]; then
            ere+="|"
        fi
        ere+="^${rex}\$"
    done
    printf '%s' "$ere"
}

ETH_ERE=$(glob_list_to_ere "$ETH_PATTERNS")
OTHER_ERE=$(glob_list_to_ere "$OTHER_PATTERNS")

# Compute state and emit waybar JSON in a single "ip -j addr show | jq" call
emit_state() {
    ip -j addr show 2>/dev/null | jq -c \
        --arg eth_re "$ETH_ERE" \
        --arg other_re "$OTHER_ERE" \
        --arg eth_icon "$ETH_ICON" \
        --arg other_icon "$OTHER_ICON" \
        --arg label_eth "$(i18n_template "${MSG[LABEL_ETHERNET]}")" \
        --arg label_other "$(i18n_template "${MSG[LABEL_OTHER]}")" '
        def classify(name):
            if ($eth_re != "" and (name | test($eth_re))) then "eth"
            elif ($other_re != "" and (name | test($other_re))) then "other"
            else null end;

        [ .[] | {
            name: .ifname,
            ip: ((.addr_info // []) | map(select(.family == "inet")) | (.[0].local // "")),
            cls: classify(.ifname)
          } ]
        | map(select(.cls != null))
        | (map(select(.cls == "eth")))   as $eth
        | (map(select(.cls == "other"))) as $other
        | ($eth   | any(.ip != ""))      as $has_eth
        | ($other | any(.ip != ""))      as $has_other
        | ($eth   | map(if .ip != "" then "\(.name) : \(.ip)" else .name end)) as $eth_lines
        | ($other | map(if .ip != "" then "\(.name) : \(.ip)" else .name end)) as $other_lines
        | ([ (if $has_eth   then $eth_icon   else empty end),
             (if $has_other then $other_icon else empty end) ] | join(" ")) as $text
        | ([ (if ($eth_lines   | length) > 0 then $label_eth + "\n" + ($eth_lines   | join("\n")) else empty end),
             (if ($other_lines | length) > 0 then $label_other + "\n"    + ($other_lines | join("\n")) else empty end) ]
           | join("\n\n")) as $tooltip
        | { text: $text,
            tooltip: $tooltip,
            class: (if $text == "" then "disconnected" else "connected" end),
            alt:   (if $text == "" then "disconnected" else "connected" end) }
        '
}

# Report current state once at startup
emit_state

# Persistent monitoring: use "ip monitor" only as a TRIGGER,
# no content parsing. Each event triggers a fresh emit_state call.
ip monitor address link 2>/dev/null | while read -r _; do
    # Dampen bursts of consecutive events
    sleep 0.3
    while read -r -t 0.1 _; do :; done
    emit_state
done
