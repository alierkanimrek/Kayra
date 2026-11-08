#!/usr/bin/env bash
#
# kayra-xbps-update.sh - Update the whole system, including source-built packages.
#
# This is the low cost update path: binary packages are updated in one single
# transaction, and only the packages that were installed from a local
# repository (built with xbps-src, e.g. discord, google-chrome) are rebuilt
# from source, and only when their template is outdated. The heavy
# "xbps-src update-sys" path, which would rebuild the whole system from source,
# is deliberately not used.
#
# How it works:
#   * Phase 1 (no lock): syncs the repositories, refreshes the void-packages
#     tree and computes the update size (download / installed) and the free
#     space. When the free space is not enough it first offers a package cache
#     cleanup (or the disk usage analyzer); only with enough room it asks for
#     confirmation showing what will be downloaded. The shared lock is NOT held
#     here, so an unanswered confirmation never blocks other package operations.
#   * Phase 2 (shared XBPS lock, kayra-xbps-lock.sh): updates all binary
#     packages in one transaction (xbps-install -Suy) and rebuilds/installs the
#     outdated source packages from the local repository.
#
# Commands used: flock, xbps-install, xbps-query, xbps-remove, xbps-checkvers,
#                xbps-src, git, find, sort, head, comm, awk, df, rm, sh,
#                baobab (setsid/nohup), notify-send, pkexec, cd.
#
# Usage: kayra-xbps-update.sh
#        kayra-xbps.sh -update

set -uo pipefail
export LC_ALL=C.UTF-8

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_XBPS_MANAGER

source "$(dirname "$0")/klog.sh"
source "$(dirname "$0")/notify.sh"
source "$(dirname "$0")/kayra-xbps-lock.sh"

PACKAGES_DIR="/var/spool/void-packages"

# local_source_pkgs comes from the shared updates library (PACKAGES_DIR is set
# above, so the library keeps it).
source "$(dirname "$0")/kayra-xbps-updates.sh"

# Acquire the shared XBPS lock before doing any work. When another operation
# (a Kayra script or a command the user started by hand) holds it, warn and
# stop instead of overlapping.
check_lock() {
    if ! xbps_lock_acquire; then
        notify_warn "${MSG[APP_NAME]}" "${MSG[LOCK_MSG]}"
        exit 0
    fi
    trap 'xbps_status_clear; xbps_lock_release' EXIT
}

cleanup_and_exit() {
    xbps_status_clear
    xbps_lock_release
    exit 0
}

# Bytes -> "N.N GB". Sizes are shown in GB so no number reaches four digits:
# swaync (the notification daemon) offers a 'COPY "<number>"' action whenever a
# notification body contains a 4 to 8 digit number, which we do not want here.
to_gb() {
    awk -v b="$1" 'BEGIN { printf "%.1f GB", b / 1073741824 }'
}

# Free space in bytes of the filesystem holding the given path.
free_bytes() {
    df -Pk "$1" 2>/dev/null | awk 'NR==2 { print $4 * 1024 }'
}

# Show the disk usage of the root filesystem with baobab, launched in the
# background and detached from this script so it survives its exit. The binary
# is looked up on PATH first, then in the usual locations.
open_disk_usage() {
    local bin
    bin=$(command -v baobab 2>/dev/null || true)
    [[ -z "$bin" && -x /usr/sbin/baobab ]] && bin=/usr/sbin/baobab
    [[ -z "$bin" && -x /usr/bin/baobab ]] && bin=/usr/bin/baobab
    if [[ -z "$bin" ]]; then
        log WARN "disk usage analyzer (baobab) not found"
        return 1
    fi
    if command -v setsid >/dev/null 2>&1; then
        setsid "$bin" / >/dev/null 2>&1 &
    else
        nohup "$bin" / >/dev/null 2>&1 &
    fi
    return 0
}

# Build a source package and install it from the local repository. The shared
# lock is already held by the caller. Returns non-zero on failure.
build_source_pkg() {
    local pkg="$1" pkgdir ret=0 build_out output

    xbps_status_set "$(i18n_template "${MSG[LOCK_BUILD]}" PACKAGE="$pkg")"
    if ! build_out=$(./xbps-src pkg "$pkg" 2>&1); then
        log ERROR "xbps-src pkg $pkg failed: $build_out"
        return 1
    fi
    # sort -u: uniq only removes adjacent duplicates.
    pkgdir=$(find "$PACKAGES_DIR/hostdir/binpkgs/" -type f -name "*$pkg*" -exec dirname {} \; | sort -u | head -n1)
    if [[ -z "$pkgdir" ]]; then
        log ERROR "built package not found for $pkg"
        return 1
    fi
    xbps_status_set "$(i18n_template "${MSG[LOCK_INSTALL]}" PACKAGE="$pkg")"
    xbps_run_native pkexec xbps-install -Sy -R "$pkgdir/" "$pkg" || ret=$?
    output="$XBPS_NATIVE_OUTPUT"
    if [[ $ret -ne 0 ]]; then
        log ERROR "xbps-install $pkg failed: $output"
        return 1
    fi
    return 0
}

# ---- main ------------------------------------------------------------------
#
# The work is split in two phases. The repository sync, the tree refresh, the
# size calculation and the confirmations run WITHOUT the shared lock, so that a
# confirmation left unanswered never blocks other package operations. The lock
# is taken only for the mutation phase, right before the actual update.

# Phase 1: sync the repositories so the size and the package list are current.
if ! sync_out=$(pkexec xbps-install -S 2>&1); then
    notify_error "${MSG[APP_NAME]}" "${MSG[INSTALL_FAIL]}"$'\n'"$sync_out"
    log ERROR "xbps-install -S failed: $sync_out"
    exit 0
fi

# Refresh the void-packages tree so the source templates are current.
if ! cd "$PACKAGES_DIR"; then
    notify_error "${MSG[APP_NAME]}" "${MSG[CD_ERR]}"
    log ERROR "${MSG[CD_ERR]}"
    exit 0
fi
if git fetch 2>/dev/null; then
    if git status -uno 2>/dev/null | grep -q "behind"; then
        git pull 2>/dev/null || true
    fi
fi

# Binary update plan (dry run): number of packages and their sizes.
plan=$(xbps-install -un 2>/dev/null || true)
update_count=$(printf '%s\n' "$plan" | awk 'NF==6 { n++ } END { print n+0 }')
install_size=$(printf '%s\n' "$plan" | awk 'NF==6 { s += $5 } END { print s+0 }')
download_size=$(printf '%s\n' "$plan" | awk 'NF==6 { s += $6 } END { print s+0 }')

# Source packages that need a rebuild: installed from a local repo and outdated
# in the void-packages tree.
source_updates=$(
    comm -12 \
        <(local_source_pkgs | sort -u) \
        <(xbps-checkvers -f '%n' -I -D "$PACKAGES_DIR" 2>/dev/null | sort -u)
)
source_count=$(printf '%s\n' "$source_updates" | awk 'NF { n++ } END { print n+0 }')

if [[ "$update_count" -eq 0 && "$source_count" -eq 0 ]]; then
    notify_ok "${MSG[APP_NAME]}" "${MSG[UPDATE_NONE]}"
    cleanup_and_exit
fi

# Free space check first: when there is not enough room, offer the package cache
# cleanup (or the disk usage analyzer) before asking to update at all.
if [[ "$install_size" -gt "$(free_bytes /)" ]]; then
    action=$(notify_action "${MSG[APP_NAME]}" \
        "$(i18n_template "${MSG[UPDATE_CLEAN_CONFIRM]}" \
            INSTALL="$(to_gb "$install_size")" FREE="$(to_gb "$(free_bytes /)")")" \
        "clean=${MSG[ACTION_CLEAN]}" \
        "diskusage=${MSG[ACTION_DISK_USAGE]}" \
        "cancel=${MSG[ACTION_CANCEL]}") || true

    # Show the disk usage and stop: the user can free space and run again.
    if [[ "$action" == "diskusage" ]]; then
        open_disk_usage && log INFO "opened the disk usage analyzer"
        exit 0
    fi
    [[ "$action" == "clean" ]] || exit 0

    # Clear the package database cache and the whole download cache in a single
    # privileged call (one authentication prompt). xbps-remove -OO only drops
    # outdated and uninstalled packages, so the download cache is cleared too
    # (it usually holds the currently installed versions; re-downloaded on
    # demand). The download cache is cleared even when xbps-remove fails.
    xp_remove=$(command -v xbps-remove 2>/dev/null || echo xbps-remove)
    if ! clean_out=$(pkexec sh -c "$xp_remove -OO -y; rm -rf /var/cache/xbps/*" 2>&1); then
        log WARN "cache cleanup failed: $clean_out"
    fi
    if [[ "$install_size" -gt "$(free_bytes /)" ]]; then
        # Still not enough: offer the disk usage analyzer before giving up.
        action=$(notify_action "${MSG[APP_NAME]}" "${MSG[DISK_LOW]}" \
            "diskusage=${MSG[ACTION_DISK_USAGE]}" "ok=${MSG[ACTION_OK]}") || true
        [[ "$action" == "diskusage" ]] && open_disk_usage
        log ERROR "not enough free space after cache cleanup"
        exit 0
    fi
fi

# Confirmation showing the download size before downloading anything. It is only
# reached when enough free space is available (after a possible cleanup).
body=$(i18n_template "${MSG[UPDATE_CONFIRM]}" \
    COUNT="$update_count" DOWNLOAD="$(to_gb "$download_size")" \
    INSTALL="$(to_gb "$install_size")" FREE="$(to_gb "$(free_bytes /)")")
if [[ "$source_count" -gt 0 ]]; then
    body+=$'\n'"$(i18n_template "${MSG[UPDATE_SOURCE]}" PACKAGES="$(printf '%s ' $source_updates)")"
fi
action=$(notify_action "${MSG[APP_NAME]}" "$body" \
    "update=${MSG[ACTION_UPDATE]}" "cancel=${MSG[ACTION_CANCEL]}") || true
[[ "$action" == "update" ]] || exit 0

# Phase 2: take the shared lock for the whole mutation phase.
check_lock

# Update all binary packages in a single transaction.
if [[ "$update_count" -gt 0 ]]; then
    xbps_status_set "${MSG[UPDATE_DOWNLOAD]}"
    if ! xbps_run_native pkexec xbps-install -Suy; then
        notify_error "${MSG[APP_NAME]}" "${MSG[INSTALL_FAIL]}"$'\n'"$XBPS_NATIVE_OUTPUT"
        log ERROR "xbps-install -Suy failed: $XBPS_NATIVE_OUTPUT"
        cleanup_and_exit
    fi
fi

# Step 2: rebuild and reinstall the outdated source packages.
built=0
for pkg in $source_updates; do
    if build_source_pkg "$pkg"; then
        built=$((built + 1))
    else
        notify_error "${MSG[APP_NAME]}" "$pkg"$'\n'"${MSG[UPDATE_PKG_FAIL]}"
    fi
done

notify_ok "${MSG[APP_NAME]}" "${MSG[UPDATE_OK]}"
log INFO "update done: repo=$update_count source_built=$built source_total=$source_count"
cleanup_and_exit
