#!/usr/bin/env bash
#
# kayra-xbps-menu.sh - Kayra OS software repository menu (Void Linux / XBPS).
#
# Lists the source packages available in the local void-packages checkout
# (both real directories and symbolic links) and merges them with the
# packages currently installed on the system. Installed packages that are
# not present in the source list are added to the list so they can be
# managed (removed) from the same menu.
#
# Used commands: find, xbps-query, sort, awk, sed, printf, pkill, fuzzel,
#                notify-send
#
set -euo pipefail
export LC_ALL=C.UTF-8

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_XBPS_MANAGER

source "$(dirname "$0")/klog.sh"

PACKAGES_DIR="/var/spool/void-packages"
LOCK_FILE="/tmp/xbps.lock"

if [[ -f "$LOCK_FILE" ]]; then
    lock_content=$(cat "$LOCK_FILE" 2>/dev/null || true)
    notify-send "${MSG[APP_NAME]}" "${MSG[LOCK_MSG]}\n $lock_content"
    exit 0
fi

# Extract the package name from a XBPS package version string.
# "alsa-ucm-conf-1.2.16.1_1" -> "alsa-ucm-conf"
# The revision suffix ("_1") and the version part (last "-" segment) are removed.
pkg_name_from_pkgver() {
    local pkgver="$1"
    pkgver="${pkgver%_*}"      # strip revision
    printf '%s\n' "${pkgver%-*}" # strip version
}

# Source packages: directories and symbolic links inside srcpkgs.
mapfile -t source_list < <(
    find "$PACKAGES_DIR/srcpkgs" -maxdepth 1 -mindepth 1 \
        \( -type d -o -type l \) -printf '%f\n' 2>/dev/null || true
)

# Installed packages: read from the XBPS package database.
mapfile -t installed_list < <(
    xbps-query -l 2>/dev/null | awk '{print $2}' | while read -r pkgver; do
        [[ -z "$pkgver" ]] && continue
        pkg_name_from_pkgver "$pkgver"
    done
)

# Merge both lists and remove duplicates (installed packages already
# present in the source list are not added twice).
pkg_list=$(printf '%s\n' "${source_list[@]:-}" "${installed_list[@]:-}" \
    | sed '/^$/d' | sort -u)

if [[ -z "$pkg_list" ]]; then
    notify-send "${MSG[APP_NAME]}" "${MSG[NO_DATA]}"
    log "WARN" "No packages found in ${PACKAGES_DIR}/srcpkgs and no packages are installed"
    exit 0
fi

log "INFO" "Loaded ${#source_list[@]} source packages and ${#installed_list[@]} installed packages"

# Close any open menu before starting a new one.
pkill -x fuzzel 2>/dev/null || true

# fuzzel iptal edilirse (çıkış 1) set -e betiği erken öldürmesin
selected=$(printf '%s\n' "$pkg_list" | fuzzel --dmenu --anchor=top-left --hide-before-typing --log-no-syslog) || true
if [[ -n "$selected" ]]; then
    "$(dirname "$0")/kayra-xbps.sh" "$selected"
fi
exit 0
