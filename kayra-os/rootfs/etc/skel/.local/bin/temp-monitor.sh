#!/usr/bin/env bash
#
# temp-monitor.sh - Waybar custom module for CPU temperature monitoring.
#
# Prints Waybar JSON ({text, tooltip, class}) on stdout. The module stays hidden
# (empty text) while the CPU is cool. Once the CPU temperature rises above
# WARN_TEMP (85 C) the emergency_heat glyph is shown in the warning colour and
# the tooltip reports the temperature and a warning message. When the
# temperature stays above CRIT_TEMP (90 C) for HOT_HOLD (15 s) in a row, a
# single warning notification asks the user to check the cooling system. The
# notification is sent once per overheating episode: it is re-armed only after
# the temperature drops back to or below CRIT_TEMP.
#
# How it works:
#   * The CPU temperature is read from sysfs only, no extra command is needed.
#     Two sources are tried in order, both in millidegree Celsius:
#       1. hwmon chips whose driver name is a known CPU sensor
#          (coretemp, k10temp, zenpower, x86_pkg_temp, cpu_thermal,
#          soc_thermal, exynos_tmu, arm_thermal). The highest valid temp*_input
#          of those chips is used, which follows the hottest core/package.
#       2. thermal zones whose type is a known CPU zone (x86_pkg_temp,
#          cpu-thermal, cpu_thermal, soc_thermal, exynos-tmu, acpitz).
#     Chip/zone indices (hwmonN, thermal_zoneN) are not stable across boots, so
#     the driver name/type is always matched, never a fixed index. Disk, GPU
#     and chipset sensors are ignored on purpose to avoid false alarms. When no
#     source is found the module stays healthy and a warning is logged once.
#   * A read value is accepted only in the 1..150 C range, so disabled sensors
#     (0) and garbage readings are ignored.
#   * The >CRIT_TEMP duration is measured with date +%s in whole seconds; a
#     drop back to or below CRIT_TEMP resets the timer and the notification flag.
#   * Emits the Waybar JSON with jq, and only when the output actually changed.
#   * Logs with klog.sh, redirected to stderr: log() also echoes to stdout,
#     which would corrupt the Waybar JSON stream.
#   * Runs continuously; single_instance prevents duplicate instances.
#
# Used libraries: single-instance.sh, klog.sh, i18n.sh, notify.sh.
# Commands used: awk, grep, sed, date, jq, printf, sleep.
#
# Usage: temp-monitor.sh   (invoked by Waybar's custom/temp-monitor module)

export LC_ALL=C.UTF-8
set -uo pipefail

source "$HOME/.local/bin/single-instance.sh"
single_instance

source "$(dirname "$0")/klog.sh"
source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_TEMP_MONITOR

# Material Symbols codepoint shown as the warning glyph.
ICON=$(printf '%b' '\U000F15D')   # emergency_heat

# Notifications reuse the same Material glyph (notify.sh renders it).
export NOTIFY_ICON="$ICON"
source "$(dirname "$0")/notify.sh"

command -v jq >/dev/null 2>&1 || { echo "jq not found" >&2; exit 1; }

WARN_TEMP=85        # show the icon and the warning tooltip above this Celsius
CRIT_TEMP=90        # overheating threshold for the notification
HOT_HOLD=15         # seconds the CPU must stay above CRIT_TEMP to notify
POLL_INTERVAL=3     # seconds between samples

# Known hwmon driver names and thermal zone types that expose CPU temperature.
# Excluding everything else (nvme, amdgpu, pch_*, ...) avoids false alarms.
CPU_HWMON_RE='coretemp|k10temp|zenpower|x86_pkg_temp|cpu_thermal|soc_thermal|exynos_tmu|arm_thermal'
CPU_ZONE_RE='x86_pkg_temp|cpu-thermal|cpu_thermal|soc_thermal|exynos-tmu|acpitz'

ALERT=0             # previous state: 0 healthy, 1 warning shown
hot_since=0         # start time of the current >CRIT_TEMP streak (0 = inactive)
notified=0          # notification sent for the current overheating streak
last_json=""        # last emitted Waybar JSON line

# Prints the highest valid temperature (in millidegree Celsius) of the CPU
# hwmon chips, or nothing when no CPU chip is found.
read_hwmon_temp() {
    local dirs
    dirs=$(grep -lxE "$CPU_HWMON_RE" /sys/class/hwmon/hwmon*/name 2>/dev/null | sed 's|/name$||')
    [[ -n "$dirs" ]] || return 1
    # $dirs is a newline separated list of sysfs paths (no spaces), so it is
    # deliberately left unquoted to let the shell expand the temp*_input globs.
    # shellcheck disable=SC2086
    awk 'BEGIN { max = 0 }
         /^[0-9]+$/ { v = $1 + 0; if (v >= 1000 && v <= 150000 && v > max) max = v }
         END { if (max > 0) print max; else exit 1 }' $dirs/temp*_input 2>/dev/null
}

# Prints the highest valid temperature (in millidegree Celsius) of the CPU
# thermal zones, or nothing when no CPU zone is found.
read_zone_temp() {
    local files
    files=$(grep -lxE "$CPU_ZONE_RE" /sys/class/thermal/thermal_zone*/type 2>/dev/null \
        | sed 's|/type$|/temp|')
    [[ -n "$files" ]] || return 1
    # shellcheck disable=SC2086
    awk 'BEGIN { max = 0 }
         /^[0-9]+$/ { v = $1 + 0; if (v >= 1000 && v <= 150000 && v > max) max = v }
         END { if (max > 0) print max; else exit 1 }' $files 2>/dev/null
}

# Prints the CPU temperature in millidegree Celsius from the first source that
# has a valid reading, or nothing when the temperature is unavailable.
read_cpu_temp() {
    local mdeg
    mdeg=$(read_hwmon_temp) || mdeg=$(read_zone_temp) || return 1
    printf '%s\n' "$mdeg"
}

while true; do
    TEMP_C=""
    mdeg=$(read_cpu_temp || true)

    if [[ "$mdeg" =~ ^[0-9]+$ ]]; then
        TEMP_C=$(( mdeg / 1000 ))
        now=$(date +%s)

        # Timer for the "stayed above CRIT_TEMP for HOT_HOLD seconds" rule.
        if (( TEMP_C > CRIT_TEMP )); then
            (( hot_since == 0 )) && hot_since=$now
            if (( notified == 0 )) && (( now - hot_since >= HOT_HOLD )); then
                log WARN "CPU temperature stayed above ${CRIT_TEMP}C for ${HOT_HOLD}s: ${TEMP_C}C" >&2
                notify_warn "${MSG[NOTIFY_TITLE]}" \
                    "$(i18n_template "${MSG[NOTIFY_CRITICAL]}" TEMP="$TEMP_C" CRIT="$CRIT_TEMP" SECONDS="$HOT_HOLD")"
                notified=1
            fi
        else
            hot_since=0
            notified=0
        fi
    fi

    if [[ -n "$TEMP_C" ]] && (( TEMP_C > WARN_TEMP )); then
        TEXT="$ICON"
        CLASS="warning"
        TIP=$(i18n_template "${MSG[TEMP_ALERT]}" TEMP="$TEMP_C")
        TIP="$TIP"$'\n'"$(i18n_template "${MSG[WARNING]}" WARN_TEMP="$WARN_TEMP")"
        if (( ALERT == 0 )); then
            log WARN "CPU temperature high: ${TEMP_C}C" >&2
            ALERT=1
        fi
    else
        TEXT=""
        CLASS=""
        TIP=""
        if (( ALERT == 1 )); then
            log INFO "CPU temperature back to normal: ${TEMP_C:-unknown}C" >&2
            ALERT=0
        fi
    fi

    json=$(jq -c -n --arg text "$TEXT" --arg tip "$TIP" --arg class "$CLASS" \
        '{text: $text, tooltip: $tip, class: $class}')

    if [[ "$json" != "$last_json" ]]; then
        printf '%s\n' "$json"
        last_json="$json"
    fi

    sleep "$POLL_INTERVAL"
done
